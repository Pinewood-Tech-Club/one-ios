import Foundation

enum AppConfig {
    static let callbackScheme = "pinewoodone"
    static let callbackURL = "pinewoodone://auth/callback"

    static var backendURL: URL {
        resolvedHTTPURL(envKey: "PINEWOOD_BACKEND_URL", defaultURL: "https://one-backend.axu.dev")
    }

    static var frontendURL: URL {
        resolvedHTTPURL(envKey: "PINEWOOD_FRONTEND_URL", defaultURL: "https://one-frontend.axu.dev")
    }

    static var convexURL: URL {
        resolvedHTTPURL(envKey: "PINEWOOD_CONVEX_URL", defaultURL: "https://grand-cod-855.convex.cloud")
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static func debugLogResolvedEndpoints() {
        #if DEBUG
        print("[Config] backendURL=\(backendURL.absoluteString)")
        print("[Config] frontendURL=\(frontendURL.absoluteString)")
        print("[Config] convexURL=\(convexURL.absoluteString)")
        #endif
    }

    private static func normalizeRawURLValue(_ value: String?) -> String? {
        guard var raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }

        if (raw.hasPrefix("\"") && raw.hasSuffix("\"")) || (raw.hasPrefix("'") && raw.hasSuffix("'")) {
            raw = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lowercasedRaw = raw.lowercased()
        if lowercasedRaw == "none" || lowercasedRaw == "null" || lowercasedRaw == "(null)" {
            return nil
        }

        return raw.isEmpty ? nil : raw
    }

    private static func resolvedHTTPURL(envKey: String, defaultURL: String) -> URL {
        let env = ProcessInfo.processInfo.environment
        let infoDictValue = Bundle.main.infoDictionary?[envKey] as? String

        guard var raw = normalizeRawURLValue(infoDictValue) ?? normalizeRawURLValue(env[envKey]) else {
            return URL(string: defaultURL)!
        }

        if !raw.contains("://") {
            raw = "http://\(raw)"
        }

        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return URL(string: defaultURL)!
        }

        return url
    }
}
