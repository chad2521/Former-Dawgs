import Foundation

/// Finds and ranks X (Twitter) video posts for a former Dawg, or returns curated
/// search deep links when the API is unavailable.
///
/// Optional bearer token: paste `XBearerToken` into Info.plist locally (same
/// pattern as `YouTubeDataAPIKey`). Leave it empty / omit the key to skip the
/// recent-search API and always use the curated X search fallbacks. Do not
/// commit a real bearer token in Info.plist.
struct XVideoService {

    /// How long resolved X videos stay valid before we re-query (~8 hours).
    private static let cacheTTL: TimeInterval = 60 * 60 * 8

    /// Returns up to 3 curated X highlight videos for the player.
    /// Prefer live API results when a bearer is configured; otherwise (or on
    /// any failure) return search deep-link fallbacks so the UI always has
    /// something useful to open.
    func videos(for playerName: String) async -> [HighlightVideo] {
        let cacheKey = cacheKey(for: playerName)

        if let cached = OfflineCache.load([HighlightVideo].self, forKey: cacheKey),
           Date().timeIntervalSince(cached.savedAt) < Self.cacheTTL {
            return cached.value
        }

        if let bearer = Self.bearerToken {
            do {
                let live = try await searchRecent(playerName: playerName, bearer: bearer)
                if !live.isEmpty {
                    OfflineCache.save(live, forKey: cacheKey)
                    return live
                }
            } catch {
                // Fall through to curated search links.
            }
        }

        let fallback = fallbackVideos(for: playerName)
        OfflineCache.save(fallback, forKey: cacheKey)
        return fallback
    }

    /// Curated X search URL for the player (media tab). Safe to show even
    /// without an API key.
    func searchURL(for playerName: String) -> URL {
        Self.mediaSearchURL(query: Self.playerSearchQuery(playerName))
    }

    // MARK: - Live API

    private func searchRecent(playerName: String, bearer: String) async throws -> [HighlightVideo] {
        var components = URLComponents(string: "https://api.x.com/2/tweets/search/recent")!
        let query = """
        "\(playerName)" (baseball OR MLB OR "Mississippi State" OR HailState OR Dawgs) (has:videos OR has:media) -is:retweet lang:en
        """
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "expansions", value: "attachments.media_keys,author_id"),
            URLQueryItem(name: "media.fields", value: "type,preview_image_url,duration_ms"),
            URLQueryItem(name: "tweet.fields", value: "created_at,public_metrics,author_id,attachments"),
            URLQueryItem(name: "user.fields", value: "username,name"),
            URLQueryItem(name: "max_results", value: "25")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(RecentSearchResponse.self, from: data)
        let tweets = decoded.data ?? []
        guard !tweets.isEmpty else { return [] }

        let mediaByKey = Dictionary(uniqueKeysWithValues: (decoded.includes?.media ?? []).map { ($0.mediaKey, $0) })
        let usersByID = Dictionary(uniqueKeysWithValues: (decoded.includes?.users ?? []).map { ($0.id, $0) })

        let lastName = playerName
            .split(separator: " ")
            .last
            .map(String.init)?
            .lowercased() ?? playerName.lowercased()

        struct Ranked {
            let tweet: RecentSearchResponse.Tweet
            let engagement: Int
            let created: Date
            let username: String?
        }

        let ranked: [Ranked] = tweets.compactMap { tweet in
            let text = tweet.text.lowercased()
            guard text.contains(lastName) else { return nil }

            let keys = tweet.attachments?.mediaKeys ?? []
            let mediaTypes = keys.compactMap { mediaByKey[$0]?.type }
            let hasPreferredMedia = mediaTypes.contains(where: { $0 == "video" || $0 == "animated_gif" })
            // Prefer video/gif; still allow other media tweets only if nothing better later —
            // require at least some attached media when keys exist, else skip empty posts.
            if !keys.isEmpty && !hasPreferredMedia {
                // Soft-keep photo posts below video; still allow if they name the player.
                // Ranked lower via engagement bias below.
            }
            if keys.isEmpty {
                return nil
            }

            let metrics = tweet.publicMetrics
            let engagement = (metrics?.likeCount ?? 0) + (metrics?.retweetCount ?? 0)
            let created = Self.parseCreatedAt(tweet.createdAt) ?? .distantPast
            let username = tweet.authorID.flatMap { usersByID[$0]?.username }
            return Ranked(tweet: tweet, engagement: engagement, created: created, username: username)
        }
        .sorted { lhs, rhs in
            let lhsVideo = hasVideoOrGIF(lhs.tweet, mediaByKey: mediaByKey)
            let rhsVideo = hasVideoOrGIF(rhs.tweet, mediaByKey: mediaByKey)
            if lhsVideo != rhsVideo { return lhsVideo && !rhsVideo }
            if lhs.engagement != rhs.engagement { return lhs.engagement > rhs.engagement }
            return lhs.created > rhs.created
        }

        return Array(ranked.prefix(3)).map { item in
            let title = trimmedTitle(item.tweet.text)
            let published = publishedText(createdAt: item.tweet.createdAt, username: item.username)
            let url: URL
            if let username = item.username,
               let statusURL = URL(string: "https://x.com/\(username)/status/\(item.tweet.id)") {
                url = statusURL
            } else {
                url = URL(string: "https://x.com/i/status/\(item.tweet.id)")!
            }
            return HighlightVideo(
                title: title,
                source: "X",
                publishedText: published,
                url: url
            )
        }
    }

    private func hasVideoOrGIF(_ tweet: RecentSearchResponse.Tweet, mediaByKey: [String: RecentSearchResponse.Media]) -> Bool {
        let keys = tweet.attachments?.mediaKeys ?? []
        return keys.contains { key in
            guard let type = mediaByKey[key]?.type else { return false }
            return type == "video" || type == "animated_gif"
        }
    }

    // MARK: - Fallbacks

    private func fallbackVideos(for playerName: String) -> [HighlightVideo] {
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

    private static func hailStateMediaURL(lastName: String) -> URL? {
        let query = "from:HailStateBB \(lastName)"
        var components = URLComponents(string: "https://x.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "f", value: "media")
        ]
        return components.url
    }

    // MARK: - Helpers

    private func trimmedTitle(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count <= 100 { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 97)
        return String(collapsed[..<end]) + "…"
    }

    private func publishedText(createdAt: String?, username: String?) -> String {
        let handle = username.map { "@\($0)" } ?? "X"
        guard let createdAt, let date = Self.parseCreatedAt(createdAt) else {
            return handle
        }
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        return "\(handle) \u{2022} \(display.string(from: date))"
    }

    private func cacheKey(for playerName: String) -> String {
        let slug = playerName.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "x-videos-v1-\(slug)"
    }

    private static var bearerToken: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "XBearerToken") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return key
    }

    private static func parseCreatedAt(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = fractionalDateFormatter.date(from: value) { return date }
        return plainDateFormatter.date(from: value)
    }

    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - X API v2 response models

private struct RecentSearchResponse: Decodable {
    let data: [Tweet]?
    let includes: Includes?

    struct Tweet: Decodable {
        let id: String
        let text: String
        let createdAt: String?
        let authorID: String?
        let publicMetrics: PublicMetrics?
        let attachments: Attachments?

        enum CodingKeys: String, CodingKey {
            case id, text, attachments
            case createdAt = "created_at"
            case authorID = "author_id"
            case publicMetrics = "public_metrics"
        }
    }

    struct PublicMetrics: Decodable {
        let likeCount: Int?
        let retweetCount: Int?

        enum CodingKeys: String, CodingKey {
            case likeCount = "like_count"
            case retweetCount = "retweet_count"
        }
    }

    struct Attachments: Decodable {
        let mediaKeys: [String]?

        enum CodingKeys: String, CodingKey {
            case mediaKeys = "media_keys"
        }
    }

    struct Includes: Decodable {
        let media: [Media]?
        let users: [User]?
    }

    struct Media: Decodable {
        let mediaKey: String
        let type: String
        let previewImageURL: String?
        let durationMs: Int?

        enum CodingKeys: String, CodingKey {
            case type
            case mediaKey = "media_key"
            case previewImageURL = "preview_image_url"
            case durationMs = "duration_ms"
        }
    }

    struct User: Decodable {
        let id: String
        let username: String
        let name: String?
    }
}
