import Foundation
import Combine
import ConvexMobile

@MainActor
final class ConvexClientManager {
    private let sessionManager: SessionManager
    private let client: ConvexClientWithAuth<String>
    private let authProvider: BackendConvexAuthProvider

    init(sessionManager: SessionManager, session: URLSession = .shared) {
        self.sessionManager = sessionManager
        let provider = BackendConvexAuthProvider(sessionManager: sessionManager)
        self.authProvider = provider
        self.client = ConvexClientWithAuth(
            deploymentUrl: AppConfig.convexURL.absoluteString,
            authProvider: provider
        )
    }

    func fetchUpcomingAssignments() async throws -> [UpcomingAssignment] {
        let authResult = await client.loginFromCache()
        switch authResult {
        case .success:
            break
        case let .failure(error):
            throw error
        }

        let publisher = client
            .subscribe(
                to: "schoologyCache:getUpcoming",
                yielding: [UpcomingAssignment].self
            )
            .first()
            .timeout(
                .seconds(15),
                scheduler: DispatchQueue.main,
                customError: { ClientError.InternalError(msg: "Timed out waiting for Convex query response.") }
            )
            .eraseToAnyPublisher()

        return try await firstValue(from: publisher)
    }
}

private final class BackendConvexAuthProvider: AuthProvider {
    typealias T = String

    private let sessionManager: SessionManager

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
        try await issueToken(onIdToken: onIdToken)
    }

    func logout() async throws {}

    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
        try await issueToken(onIdToken: onIdToken)
    }

    func extractIdToken(from authResult: String) -> String {
        authResult
    }

    private func issueToken(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
        let token = try await sessionManager.fetchConvexToken()
        onIdToken(token)
        return token
    }
}

private func firstValue<T>(from publisher: AnyPublisher<T, ClientError>) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        var cancellable: AnyCancellable?
        var hasResumed = false

        cancellable = publisher.sink(
            receiveCompletion: { completion in
                guard !hasResumed else {
                    cancellable?.cancel()
                    return
                }
                if case let .failure(error) = completion {
                    hasResumed = true
                    continuation.resume(throwing: error)
                }
                cancellable?.cancel()
            },
            receiveValue: { value in
                guard !hasResumed else {
                    return
                }
                hasResumed = true
                continuation.resume(returning: value)
                cancellable?.cancel()
            }
        )
    }
}
