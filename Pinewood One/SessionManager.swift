import CryptoKit
import Foundation

@MainActor
final class SessionManager {
    private let apiClient: APIClient
    private let refreshTokenKey = "pinewood.mobile.refreshToken"
    private let deviceIdKey = "pinewood.mobile.deviceId"

    private(set) var accessToken: String?
    private(set) var accessTokenExpiresAt: Date?
    private(set) var refreshToken: String?
    private(set) var currentUser: MobileUser?
    let deviceId: String

    init(apiClient: APIClient? = nil) {
        AppConfig.debugLogResolvedEndpoints()
        self.apiClient = apiClient ?? APIClient(baseURL: AppConfig.backendURL)

        if let persistedDevice = KeychainStore.load(key: deviceIdKey), !persistedDevice.isEmpty {
            self.deviceId = persistedDevice
        } else {
            let generated = UUID().uuidString
            self.deviceId = generated
            KeychainStore.save(key: deviceIdKey, value: generated)
        }

        self.refreshToken = KeychainStore.load(key: refreshTokenKey)
    }

    var isAuthenticated: Bool {
        refreshToken != nil || (accessToken != nil && accessTokenExpiresAt?.timeIntervalSinceNow ?? 0 > 0)
    }

    func restoreSession() async throws -> MobileUser {
        try await refreshTokens()
        try await registerDevice()
        return try await fetchMe()
    }

    func signInWithGoogle(oauthCoordinator: OAuthCoordinator) async throws -> MobileUser {
        let verifier = Self.generatePKCEVerifier()
        let challenge = Self.pkceChallenge(for: verifier)

        guard let startURLBase = URL(
            string: "/api/mobile/v1/auth/google/start",
            relativeTo: AppConfig.backendURL
        )?.absoluteURL else {
            throw APIClientError.invalidURL
        }
        var components = URLComponents(url: startURLBase, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "redirect_uri", value: AppConfig.callbackURL),
            URLQueryItem(name: "device_id", value: deviceId),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let startURL = components?.url?.absoluteURL else {
            throw APIClientError.invalidURL
        }
        print("[Auth][Google] startURL=\(startURL.absoluteString)")

        let callbackURL = try await oauthCoordinator.start(url: startURL, callbackScheme: AppConfig.callbackScheme)
        print("[Auth][Google] callbackURL=\(callbackURL.absoluteString)")
        let callbackQuery = Self.queryItems(from: callbackURL)

        if let error = callbackQuery["error"] {
            throw APIClientError.http(status: 400, message: error)
        }

        guard let code = callbackQuery["code"] else {
            throw APIClientError.http(status: 400, message: "Missing auth code")
        }

        let context = MobileContext.current(deviceId: deviceId)
        let body: [String: Any] = [
            "code": code,
            "code_verifier": verifier,
            "device_id": context.deviceId,
            "platform": context.platform,
            "app_version": context.appVersion,
            "locale": context.locale,
            "timezone": context.timezone,
        ]

        let (data, _) = try await apiClient.request(path: "/api/mobile/v1/auth/exchange", method: "POST", body: body)
        let exchange = try apiClient.decode(AuthExchangeResponse.self, from: data)
        setTokens(from: exchange)

        try await registerDevice()
        return try await fetchMe()
    }

    func startSchoologyOAuth(oauthCoordinator: OAuthCoordinator) async throws {
        let verifier = Self.generatePKCEVerifier()
        let challenge = Self.pkceChallenge(for: verifier)

        let startBody: [String: Any] = [
            "redirect_uri": AppConfig.callbackURL,
            "device_id": deviceId,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        ]

        let (startData, _) = try await authorizedRequest(
            path: "/api/mobile/v1/auth/schoology/start",
            method: "POST",
            body: startBody
        )
        let startResponse = try apiClient.decode(SchoologyStartResponse.self, from: startData)
        print("[Auth][Schoology] authUrl(raw)=\(startResponse.authUrl)")

        guard let authURL = URL(string: startResponse.authUrl) else {
            throw APIClientError.invalidURL
        }
        print("[Auth][Schoology] authURL(parsed)=\(authURL.absoluteString) scheme=\(authURL.scheme ?? "nil") host=\(authURL.host ?? "nil")")

        let callbackURL = try await oauthCoordinator.start(url: authURL, callbackScheme: AppConfig.callbackScheme)
        print("[Auth][Schoology] callbackURL=\(callbackURL.absoluteString)")
        let callbackQuery = Self.queryItems(from: callbackURL)

        if let error = callbackQuery["error"] {
            throw APIClientError.http(status: 400, message: error)
        }

        guard let code = callbackQuery["code"] else {
            throw APIClientError.http(status: 400, message: "Missing Schoology auth code")
        }

        let exchangeBody: [String: Any] = [
            "code": code,
            "code_verifier": verifier,
            "device_id": deviceId,
        ]

        _ = try await authorizedRequest(
            path: "/api/mobile/v1/auth/schoology/exchange",
            method: "POST",
            body: exchangeBody
        )
    }

    func fetchMe() async throws -> MobileUser {
        let (data, _) = try await authorizedRequest(path: "/api/mobile/v1/me")
        let user = try apiClient.decode(MobileUser.self, from: data)
        currentUser = user
        return user
    }

    func fetchConvexToken() async throws -> String {
        let (data, _) = try await authorizedRequest(path: "/api/mobile/v1/convex/token")
        let payload = try apiClient.decode(ConvexTokenResponse.self, from: data)
        return payload.token
    }

    func createOnboardingBootstrapURL() async throws -> URL {
        let body: [String: Any] = ["device_id": deviceId]
        let (data, _) = try await authorizedRequest(
            path: "/api/mobile/v1/web/session-ticket",
            method: "POST",
            body: body
        )
        let ticket = try apiClient.decode(WebSessionTicketResponse.self, from: data)

        let redirect = AppConfig.frontendURL
            .appending(path: "mobile")
            .appending(path: "onboarding")
            .absoluteString

        guard let bootstrapURLBase = URL(
            string: "/api/mobile/v1/web/session/bootstrap",
            relativeTo: AppConfig.backendURL
        )?.absoluteURL else {
            throw APIClientError.invalidURL
        }
        var components = URLComponents(url: bootstrapURLBase, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "ticket", value: ticket.ticket),
            URLQueryItem(name: "redirect", value: redirect),
        ]

        guard let url = components?.url?.absoluteURL else {
            throw APIClientError.invalidURL
        }
        return url
    }

    func fetchBannerMetadata() async throws -> BannerMetadataResponse {
        let (data, _) = try await apiClient.request(path: "/api/mobile/v1/banner/upcoming")
        return try apiClient.decode(BannerMetadataResponse.self, from: data)
    }

    func refreshSchoologyData() async throws {
        _ = try await authorizedRequest(path: "/api/mobile/v1/schoology/refresh", method: "POST")
    }

    func logout() async {
        do {
            try await unregisterDevice()
        } catch {
            // Continue logout; local state should still be cleared.
        }

        if let token = accessToken {
            let body: [String: Any] = [
                "refresh_token": refreshToken ?? "",
                "all_devices": false,
            ]
            _ = try? await apiClient.request(
                path: "/api/mobile/v1/auth/logout",
                method: "POST",
                body: body,
                bearerToken: token
            )
        }

        clearLocalSession()
    }

    func clearLocalSession() {
        accessToken = nil
        accessTokenExpiresAt = nil
        refreshToken = nil
        currentUser = nil
        KeychainStore.delete(key: refreshTokenKey)
    }

    private func setTokens(from response: AuthExchangeResponse) {
        accessToken = response.accessToken
        accessTokenExpiresAt = Date().addingTimeInterval(TimeInterval(max(0, response.expiresIn - 10)))

        refreshToken = response.refreshToken
        KeychainStore.save(key: refreshTokenKey, value: response.refreshToken)
    }

    private func registerDevice() async throws {
        let context = MobileContext.current(deviceId: deviceId)
        let body: [String: Any] = [
            "device_id": context.deviceId,
            "platform": context.platform,
            "app_version": context.appVersion,
            "locale": context.locale,
            "timezone": context.timezone,
        ]
        _ = try await authorizedRequest(path: "/api/mobile/v1/devices/register", method: "POST", body: body)
    }

    private func unregisterDevice() async throws {
        _ = try await authorizedRequest(
            path: "/api/mobile/v1/devices/register",
            method: "DELETE",
            body: ["device_id": deviceId]
        )
    }

    private func refreshTokens() async throws {
        guard let refreshToken else {
            throw APIClientError.http(status: 401, message: "No refresh token")
        }

        let body: [String: Any] = [
            "refresh_token": refreshToken,
            "device_id": deviceId,
        ]

        do {
            let (data, _) = try await apiClient.request(path: "/api/mobile/v1/auth/refresh", method: "POST", body: body)
            let payload = try apiClient.decode(AuthExchangeResponse.self, from: data)
            setTokens(from: payload)
        } catch {
            clearLocalSession()
            throw error
        }
    }

    private func authorizedRequest(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        let token = try await validAccessToken()

        do {
            return try await apiClient.request(path: path, method: method, body: body, bearerToken: token)
        } catch let APIClientError.http(status, _) where status == 401 && retryOnUnauthorized {
            try await refreshTokens()
            let refreshedToken = try await validAccessToken(skipRefresh: true)
            return try await apiClient.request(path: path, method: method, body: body, bearerToken: refreshedToken)
        }
    }

    private func validAccessToken(skipRefresh: Bool = false) async throws -> String {
        if let accessToken,
           let accessTokenExpiresAt,
           accessTokenExpiresAt.timeIntervalSinceNow > 30 {
            return accessToken
        }

        if !skipRefresh {
            try await refreshTokens()
        }

        if let accessToken {
            return accessToken
        }

        throw APIClientError.http(status: 401, message: "Not authenticated")
    }

    private static func generatePKCEVerifier() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0 ..< 64).map { _ in chars.randomElement()! })
    }

    private static func pkceChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func queryItems(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}
