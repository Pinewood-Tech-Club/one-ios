import Foundation

enum APIClientError: Error, LocalizedError {
    case invalidURL
    case unsupportedURLScheme(String?)
    case invalidResponse
    case http(status: Int, message: String?)
    case encodingFailed
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case let .unsupportedURLScheme(scheme):
            if let scheme, !scheme.isEmpty {
                return "Unsupported URL scheme: \(scheme). Use http or https."
            }
            return "Unsupported URL scheme. Use http or https."
        case .invalidResponse:
            return "Invalid server response."
        case let .http(status, message):
            if let message {
                return "HTTP \(status): \(message)"
            }
            return "HTTP \(status)"
        case .encodingFailed:
            return "Failed to encode request body."
        case .userCancelled:
            return "Request cancelled."
        }
    }
}

final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func request(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        bearerToken: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            guard JSONSerialization.isValidJSONObject(body) else {
                throw APIClientError.encodingFailed
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = try? JSONDecoder().decode(APIErrorPayload.self, from: data).error
            throw APIClientError.http(status: http.statusCode, message: message)
        }

        return (data, http)
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    func decodeJSONObject(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }
}

private struct APIErrorPayload: Decodable {
    let error: String
}
