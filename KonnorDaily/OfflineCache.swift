import Foundation

/// A timestamped wrapper stored on disk so callers can tell how old cached data is.
struct CachedPayload<Value: Codable>: Codable {
    let value: Value
    let savedAt: Date
}

/// Lightweight disk-backed cache for `Codable` values.
///
/// Payloads are written into the shared App Group container so cached data
/// survives app relaunches (and is reachable by the widget/watch extensions).
/// This is the storage layer behind the app's stale-while-revalidate behaviour:
/// the last successful network response is persisted here, shown instantly on the
/// next launch, and served as a fallback when the network is unavailable.
enum OfflineCache {
    private static let folderName = "OfflineCache"

    private static var directory: URL? {
        let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedAppGroup.identifier)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

        guard let base else { return nil }

        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private static func fileURL(forKey key: String) -> URL? {
        directory?.appendingPathComponent("\(key).json", isDirectory: false)
    }

    /// Persist a value to disk, stamping it with the current time.
    static func save<Value: Codable>(_ value: Value, forKey key: String) {
        guard let url = fileURL(forKey: key) else { return }
        let payload = CachedPayload(value: value, savedAt: Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Load the most recently persisted value for a key, along with when it was saved.
    static func load<Value: Codable>(_ type: Value.Type, forKey key: String) -> CachedPayload<Value>? {
        guard let url = fileURL(forKey: key),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(CachedPayload<Value>.self, from: data)
    }
}
