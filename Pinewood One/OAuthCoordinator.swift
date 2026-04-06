import AuthenticationServices
import UIKit

@MainActor
final class OAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var currentSession: ASWebAuthenticationSession?

    func start(url: URL, callbackScheme: String) async throws -> URL {
        print("[OAuth] start url=\(url.absoluteString) callbackScheme=\(callbackScheme)")
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            print("[OAuth] rejected unsupported scheme=\(url.scheme ?? "nil") url=\(url.absoluteString)")
            throw APIClientError.unsupportedURLScheme(url.scheme)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) {
                [weak self] callbackURL, error in
                self?.currentSession = nil

                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                    return
                }

                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain &&
                        nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: APIClientError.userCancelled)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(throwing: APIClientError.invalidResponse)
            }

            // Use the shared browser session so auth can reuse Safari sign-in state.
            // This enables the native consent prompt like:
            // "<App> wants to use <domain> to sign in."
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            currentSession = session

            if !session.start() {
                currentSession = nil
                continuation.resume(throwing: APIClientError.invalidResponse)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
