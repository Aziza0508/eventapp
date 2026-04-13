import Foundation

/// EventCache provides simple file-based offline caching for the event feed.
/// Stores the last successful event list response as JSON in the app's caches directory.
actor EventCache {
    static let shared = EventCache()

    private let fileName = "cached_events.json"

    private var fileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    /// Save the event list response to disk.
    func save(_ response: EventListResponse) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(response)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[cache] failed to save events: \(error)")
        }
    }

    /// Load the cached event list response from disk. Returns nil if no cache exists.
    func load() -> EventListResponse? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(EventListResponse.self, from: data)
        } catch {
            print("[cache] failed to load events: \(error)")
            return nil
        }
    }

    /// Clear the cache.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
