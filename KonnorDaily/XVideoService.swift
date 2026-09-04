import Foundation

/// Free curated X (Twitter) deep links for former Dawg video discovery.
///
/// No X API, no bearer token, no recent-search network calls. Builds static
/// HighlightVideo rows that open media-focused x.com search URLs in Safari /
/// the X app. YouTube highlights remain the live video source elsewhere.
struct XVideoService {

    /// Returns curated X highlight deep links for the player (fresh each call;
    /// static URLs do not need OfflineCache).
    func videos(for playerName: String) async -> [HighlightVideo] {
        curatedVideos(for: playerName)
    }

    /// Curated X search URL for the player (media tab). Always available
    /// without an API key.
    func searchURL(for playerName: String) -> URL {
        Self.mediaSearchURL(query: Self.playerSearchQuery(playerName))
    }

    // MARK: - Curated deep links (free only)

    private func curatedVideos(for playerName: String) -> [HighlightVideo] {
        var results: [HighlightVideo] = [
            HighlightVideo(
                title: "Videos on X",
                source: "X",
                publishedText: "Search clips and highlights",
                url: Self.mediaSearchURL(query: Self.playerSearchQuery(playerName))
            )
        ]

        if let lastName = playerName.split(separator: " ").last.map(String.init),
           let hailURL = Self.hailStateMediaURL(lastName: lastName) {
            results.append(
                HighlightVideo(
                    title: "Hail State BB on X",
                    source: "X",
                    publishedText: "from @HailStateBB",
                    url: hailURL
                )
            )
        }

        return results
    }

    private static func playerSearchQuery(_ playerName: String) -> String {
        "\"\(playerName)\" (baseball OR MLB OR \"Mississippi State\")"
    }

    private static func mediaSearchURL(query: String) -> URL {
        var components = URLComponents(string: "https://x.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "f", value: "media")
        ]
        return components.url ?? URL(string: "https://x.com/search")!
    }

    /// from:@HailStateBB + player last name, media tab when possible.
    private static func hailStateMediaURL(lastName: String) -> URL? {
        let query = "from:HailStateBB \(lastName)"
        var components = URLComponents(string: "https://x.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "f", value: "media")
        ]
        return components.url
    }
}
