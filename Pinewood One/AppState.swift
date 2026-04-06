import Foundation
import UIKit
import Combine

struct ExternalBrowserDestination: Identifiable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case loading
        case signedOut
        case onboarding(URL)
        case signedIn
    }

    enum AppTab: Hashable {
        case upcoming
        case schedule
        case grades
        case chat
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var user: MobileUser?
    @Published var selectedTab: AppTab = .upcoming
    @Published var isPerformingAuth = false
    @Published var transientError: String?
    @Published var externalBrowserDestination: ExternalBrowserDestination?

    let sessionManager: SessionManager
    private let oauthCoordinator: OAuthCoordinator
    private let convexManager: ConvexClientManager
    private let bannerLoader: BannerImageLoader

    init() {
        let sessionManager = SessionManager()
        self.sessionManager = sessionManager
        self.oauthCoordinator = OAuthCoordinator()
        self.convexManager = ConvexClientManager(sessionManager: sessionManager)
        self.bannerLoader = BannerImageLoader(sessionManager: sessionManager)

        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        phase = .loading
        authState = .loading

        guard sessionManager.isAuthenticated else {
            phase = .signedOut
            authState = .signedOut
            return
        }

        do {
            let restoredUser = try await sessionManager.restoreSession()
            user = restoredUser
            try await transitionForCurrentUser()
        } catch {
            sessionManager.clearLocalSession()
            user = nil
            phase = .signedOut
            authState = .signedOut
        }
    }

    func signInWithGoogle() async {
        isPerformingAuth = true
        defer { isPerformingAuth = false }

        do {
            let user = try await sessionManager.signInWithGoogle(oauthCoordinator: oauthCoordinator)
            self.user = user
            try await transitionForCurrentUser()
        } catch {
            handleUserFacingError(error, source: "google_sign_in")
            phase = .signedOut
            authState = .signedOut
        }
    }

    func logout() async {
        await sessionManager.logout()
        user = nil
        selectedTab = .upcoming
        phase = .signedOut
        authState = .signedOut
    }

    func handleForegroundRefresh() async {
        guard let user, user.schoologyConnected else {
            return
        }
        do {
            try await sessionManager.refreshSchoologyData()
        } catch {
            // Keep UI functional even if refresh fails.
        }
    }

    func handleBridgeSchoologyOAuth() {
        Task {
            do {
                try await sessionManager.startSchoologyOAuth(oauthCoordinator: oauthCoordinator)
                let updatedUser = try await sessionManager.fetchMe()
                user = updatedUser
                try await transitionForCurrentUser()
            } catch {
                handleUserFacingError(error, source: "schoology_oauth")
            }
        }
    }

    func handleBridgeOnboardingComplete() {
        Task {
            do {
                let updatedUser = try await sessionManager.fetchMe()
                user = updatedUser
                try await transitionForCurrentUser()
            } catch {
                handleUserFacingError(error, source: "onboarding_complete")
            }
        }
    }

    func openExternalURL(_ url: URL) {
        let resolvedURL = resolveExternalURL(url)

        guard let scheme = resolvedURL.scheme?.lowercased() else {
            transientError = "Blocked unsupported link."
            return
        }

        if scheme == AppConfig.callbackScheme {
            UIApplication.shared.open(resolvedURL)
            return
        }

        guard (scheme == "https" || scheme == "http"),
              let host = resolvedURL.host?.lowercased(),
              isAllowedExternalHost(host)
        else {
            transientError = "Blocked untrusted external link."
            return
        }

        externalBrowserDestination = ExternalBrowserDestination(url: resolvedURL)
    }

    func fetchUpcomingAssignments(refreshSchoology: Bool) async throws -> [UpcomingAssignment] {
        if refreshSchoology, user?.schoologyConnected == true {
            try await sessionManager.refreshSchoologyData()
        }
        return try await convexManager.fetchUpcomingAssignments()
    }

    func fetchBannerURL() async -> URL? {
        await bannerLoader.bannerURL()
    }

    private func transitionForCurrentUser() async throws {
        guard let user else {
            phase = .signedOut
            return
        }

        if user.onboardingStep == "completed" {
            phase = .signedIn
            authState = .signedIn
            return
        }

        let onboardingURL = try await sessionManager.createOnboardingBootstrapURL()
        phase = .onboarding(onboardingURL)
        authState = .onboarding
    }

    private func isAllowedExternalHost(_ host: String) -> Bool {
        let explicitHosts = [
            AppConfig.frontendURL.host?.lowercased(),
            AppConfig.backendURL.host?.lowercased(),
            AppConfig.convexURL.host?.lowercased(),
            "accounts.google.com",
            "app.schoology.com",
            "api.schoology.com",
            "schoology.com",
            "www.schoology.com",
        ].compactMap { $0 }

        for allowed in explicitHosts {
            if host == allowed || host.hasSuffix(".\(allowed)") {
                return true
            }
        }
        return false
    }

    private func resolveExternalURL(_ url: URL) -> URL {
        guard url.scheme == nil else {
            return url
        }

        if let absoluteURL = URL(string: url.relativeString, relativeTo: AppConfig.frontendURL)?.absoluteURL {
            return absoluteURL
        }

        return url
    }

    private func handleUserFacingError(_ error: Error, source: String) {
        if isCancellationError(error) {
            print("[AppState] Ignoring cancelled auth flow source=\(source)")
            return
        }
        let message = friendlyErrorMessage(for: error)
        transientError = message
        print("[AppState] source=\(source) error=\(error.localizedDescription) surfaced=\"\(message)\"")
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if let apiError = error as? APIClientError, case .userCancelled = apiError {
            return true
        }
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
    }

    private func friendlyErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIClientError {
            switch apiError {
            case .http(_, let message):
                switch message {
                case "invalid_domain":
                    return "Please sign in with your Pinewood Google account."
                case "rate_limited":
                    return "Too many attempts right now. Please try again in a minute."
                default:
                    return "Something went wrong while signing in. Please try again."
                }
            case .invalidURL, .unsupportedURLScheme, .invalidResponse, .encodingFailed:
                return "Something went wrong while signing in. Please try again."
            case .userCancelled:
                return ""
            }
        }

        return "Something went wrong. Please try again."
    }
}
