import Foundation

@MainActor
final class BannerImageLoader {
    private let sessionManager: SessionManager
    private let storageKey = "pinewood.banner.upcoming"

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    func bannerURL() async -> URL? {
        if let cached = loadCached(), cached.expiresAt > Date(), let url = cached.versionedURL {
            return url
        }

        do {
            let metadata = try await sessionManager.fetchBannerMetadata()
            guard let imageURL = metadata.imageUrl,
                  !imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                clearCached()
                return nil
            }

            let entry = BannerCacheEntry(
                imageURL: imageURL,
                version: metadata.version,
                expiresAt: Date().addingTimeInterval(TimeInterval(max(1, metadata.cacheTtlSeconds)))
            )
            save(entry)
            return entry.versionedURL
        } catch {
            return loadCached()?.versionedURL
        }
    }

    private func loadCached() -> BannerCacheEntry? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(BannerCacheEntry.self, from: data)
    }

    private func save(_ entry: BannerCacheEntry) {
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func clearCached() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

private struct BannerCacheEntry: Codable {
    let imageURL: String
    let version: String
    let expiresAt: Date

    var versionedURL: URL? {
        guard var components = URLComponents(string: imageURL) else {
            return URL(string: imageURL)
        }
        var query = components.queryItems ?? []
        query.removeAll(where: { $0.name == "v" })
        query.append(URLQueryItem(name: "v", value: version))
        components.queryItems = query
        return components.url
    }
}
