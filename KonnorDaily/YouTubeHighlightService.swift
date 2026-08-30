import Foundation

/// Finds and validates the single best YouTube highlight video for a player.
///
/// Rather than deep-linking to a blind search, this service queries the
/// YouTube Data API v3, filters out results that can't actually be watched
/// (private, non-embeddable, live streams, Shorts), and ranks the survivors by
/// relevance, view count, and recency so the card links to a real, playable clip.
///
/// The API key is read from the app's Info.plist (`YouTubeDataAPIKey`). If no
/// key is configured, or the network request fails, the service returns `nil`
/// and callers fall back to a plain YouTube search link.
struct YouTubeHighlightService {

    /// How long a resolved "best video" stays valid before we re-query.
    /// Keeps us comfortably inside the free tier's ~100 searches/day quota.
    private static let cacheTTL: TimeInterval = 60 * 60 * 24

    /// Shortest clip we'll link to. Anything briefer is almost certainly a Short.
    private static let minimumDurationSeconds = 31

    /// How far back a clip can be published and still count as a "recent" highlight.
    /// The hottest hitter/pitcher is a this-week concept, so we bias hard to the
    /// current stretch and only widen if nothing recent from a credible source exists.
    private static let recentWindowDays = 30

    /// Returns the best validated highlight video, or `nil` if none can be found.
    func bestHighlight(for playerName: String, preferPitching: Bool) async -> HighlightVideo? {
        let cacheKey = cacheKey(for: playerName, preferPitching: preferPitching)

        // Serve a fresh cached result to conserve quota.
        if let cached = OfflineCache.load(HighlightVideo.self, forKey: cacheKey),
           Date().timeIntervalSince(cached.savedAt) < Self.cacheTTL {
            return cached.value
        }

        guard let apiKey = Self.apiKey else { return nil }

        do {
            // First look only at the last few weeks so the card reflects why the
            // player is hot *right now*. If nothing credible is that fresh, widen
            // to any date rather than showing nothing.
            let recentCutoff = Self.dateFormatter.string(from: Date().addingTimeInterval(-Double(Self.recentWindowDays) * 86_400))

            var best = try await resolveBest(playerName: playerName, apiKey: apiKey, publishedAfter: recentCutoff)
            if best == nil {
                best = try await resolveBest(playerName: playerName, apiKey: apiKey, publishedAfter: nil)
            }

            guard let best else { return nil }

            let video = HighlightVideo(
                title: best.title,
                source: "YouTube",
                publishedText: publishedText(channel: best.channelTitle, publishedAt: best.publishedAt),
                url: URL(string: "https://www.youtube.com/watch?v=\(best.id)")!
            )
            OfflineCache.save(video, forKey: cacheKey)
            return video
        } catch {
            // Any failure (offline, quota, decode) degrades gracefully to the
            // search-link fallback handled by the caller.
            return nil
        }
    }

    /// Runs the search/validate/rank pipeline for a given recency window.
    private func resolveBest(playerName: String, apiKey: String, publishedAfter: String?) async throws -> VideoDetail? {
        // Query by date AND relevance, then merge. The date-ordered pass
        // guarantees the freshest clips are in the pool (relevance alone can
        // bury a brand-new video below older, more-viewed ones).
        async let dateResults = search(playerName: playerName, order: "date", publishedAfter: publishedAfter, apiKey: apiKey)
        async let relevanceResults = search(playerName: playerName, order: "relevance", publishedAfter: publishedAfter, apiKey: apiKey)

        let mergedIDs = Array(Set(try await dateResults + relevanceResults))
        guard !mergedIDs.isEmpty else { return nil }

        let details = try await videoDetails(ids: mergedIDs, apiKey: apiKey)

        // Keep clips that actually play and come from a credible/official source.
        // We do NOT require the player's name in the title: the search query is
        // already the player's name, so a recent official "Team vs Team Highlights"
        // recap is a legitimate, current clip featuring them. Then prefer the
        // higher source tier (pro over college) and, within a tier, the newest.
        let candidates = details
            .filter(isPlayable)
            .filter { sourceTier($0.channelTitle) > 0 }

        return candidates.max { lhs, rhs in
            let lhsTier = sourceTier(lhs.channelTitle)
            let rhsTier = sourceTier(rhs.channelTitle)
            if lhsTier != rhsTier { return lhsTier < rhsTier }
            let lhsDate = publishedDate(lhs)
            let rhsDate = publishedDate(rhs)
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            // Tie-break: prefer a clip that actually names the player.
            let lhsNamed = namesPlayer(lhs, playerName: playerName)
            let rhsNamed = namesPlayer(rhs, playerName: playerName)
            return !lhsNamed && rhsNamed
        }
    }

    // MARK: - Networking

    private func search(playerName: String, order: String, publishedAfter: String?, apiKey: String) async throws -> [String] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        var items = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: "\(playerName) baseball highlights"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "safeSearch", value: "moderate"),
            URLQueryItem(name: "order", value: order),
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        if let publishedAfter {
            items.append(URLQueryItem(name: "publishedAfter", value: publishedAfter))
        }
        components.queryItems = items

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return response.items.compactMap { $0.id.videoId }
    }

    private func videoDetails(ids: [String], apiKey: String) async throws -> [VideoDetail] {
        guard !ids.isEmpty else { return [] }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,statistics,status,contentDetails"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(VideoListResponse.self, from: data)
        return response.items.map { item in
            VideoDetail(
                id: item.id,
                title: item.snippet.title,
                channelTitle: item.snippet.channelTitle,
                publishedAt: item.snippet.publishedAt,
                liveBroadcastContent: item.snippet.liveBroadcastContent ?? "none",
                viewCount: Int(item.statistics?.viewCount ?? "0") ?? 0,
                isEmbeddable: item.status?.embeddable ?? false,
                privacyStatus: item.status?.privacyStatus ?? "public",
                durationSeconds: Self.parseISO8601Duration(item.contentDetails?.duration)
            )
        }
    }

    // MARK: - Validation & ranking

    /// A video is only worth linking to if it actually plays for our users.
    private func isPlayable(_ video: VideoDetail) -> Bool {
        video.isEmbeddable
            && video.privacyStatus == "public"
            && video.liveBroadcastContent == "none"
            && video.durationSeconds >= Self.minimumDurationSeconds
    }

    /// Whether the video title names the player (last name, or full name).
    /// Keeps us on player-specific clips instead of generic team reels.
    private func namesPlayer(_ video: VideoDetail, playerName: String) -> Bool {
        let title = video.title.lowercased()
        let name = playerName.lowercased()
        if title.contains(name) { return true }
        if let lastName = name.split(separator: " ").last.map(String.init) {
            return title.contains(lastName)
        }
        return false
    }

    /// Ranks a channel's credibility as a highlight source:
    /// `2` = pro/league/network/official team, `1` = college/amateur, `0` = untrusted.
    /// Pro outranks college so a former Dawg's actual MLB/MiLB highlight always
    /// beats a recently-uploaded college or alumni clip.
    private func sourceTier(_ channelTitle: String) -> Int {
        let name = channelTitle.lowercased()
        if Self.proSourceKeywords.contains(where: { name.contains($0) }) { return 2 }
        if Self.amateurSourceKeywords.contains(where: { name.contains($0) }) { return 1 }
        return 0
    }

    private func publishedDate(_ video: VideoDetail) -> Date {
        Self.dateFormatter.date(from: video.publishedAt) ?? .distantPast
    }

    /// Professional-level sources: leagues, national/regional networks, reputable
    /// independent baseball outlets, and the official MLB club channels.
    private static let proSourceKeywords: Set<String> = [
        // Leagues & official networks
        "mlb", "milb", "minor league baseball", "mlb network",
        // National broadcasters
        "espn", "fox sports", "nbc sports", "cbs sports", "tbs", "apple tv",
        // Regional sports networks
        "bally sports", "sportsnet", "marquee sports", "nesn", "yes network",
        "spectrum sportsnet", "masn", "att sportsnet", "space city",
        "monumental sports", "padres.tv", "sny",
        // Reputable independent baseball outlets
        "jomboy", "baseball america", "d1baseball", "perfect game",
        // MLB clubs (official team channels)
        "diamondbacks", "braves", "orioles", "red sox", "cubs", "white sox",
        "reds", "guardians", "rockies", "tigers", "astros", "royals",
        "angels", "dodgers", "marlins", "brewers", "twins", "yankees",
        "mets", "athletics", "phillies", "pirates", "padres", "giants",
        "mariners", "cardinals", "rays", "rangers", "blue jays", "nationals"
    ]

    /// Amateur/college authorities — trusted, but only used when no pro-level
    /// highlight naming the player exists.
    private static let amateurSourceKeywords: Set<String> = [
        "mississippi state", "hail state", "sec network", "espn college",
        "ncaa", "usa baseball", "cape cod baseball", "collegiate baseball"
    ]

    // MARK: - Helpers

    private func publishedText(channel: String, publishedAt: String) -> String {
        guard let date = Self.dateFormatter.date(from: publishedAt) else { return channel }
        let display = DateFormatter()
        display.dateFormat = "MMM yyyy"
        return "\(channel) \u{2022} \(display.string(from: date))"
    }

    private func cacheKey(for playerName: String, preferPitching: Bool) -> String {
        let slug = playerName.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        // Version suffix busts stale entries when the selection logic changes.
        return "youtube-highlight-v4-\(slug)-\(preferPitching ? "p" : "h")"
    }

    private static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "YouTubeDataAPIKey") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return key
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parses an ISO 8601 duration (e.g. "PT4M13S") into seconds.
    static func parseISO8601Duration(_ duration: String?) -> Int {
        guard let duration, duration.hasPrefix("PT") else { return 0 }
        let value = duration.dropFirst(2)
        var seconds = 0
        var number = ""
        for character in value {
            if character.isNumber {
                number.append(character)
            } else {
                let amount = Int(number) ?? 0
                switch character {
                case "H": seconds += amount * 3600
                case "M": seconds += amount * 60
                case "S": seconds += amount
                default: break
                }
                number = ""
            }
        }
        return seconds
    }
}

// MARK: - YouTube Data API response models

private struct VideoDetail {
    let id: String
    let title: String
    let channelTitle: String
    let publishedAt: String
    let liveBroadcastContent: String
    let viewCount: Int
    let isEmbeddable: Bool
    let privacyStatus: String
    let durationSeconds: Int
}

private struct SearchResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: ID
        struct ID: Decodable {
            let videoId: String?
        }
    }
}

private struct VideoListResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: String
        let snippet: Snippet
        let statistics: Statistics?
        let status: Status?
        let contentDetails: ContentDetails?

        struct Snippet: Decodable {
            let title: String
            let channelTitle: String
            let publishedAt: String
            let liveBroadcastContent: String?
        }

        struct Statistics: Decodable {
            let viewCount: String?
        }

        struct Status: Decodable {
            let privacyStatus: String?
            let embeddable: Bool?
        }

        struct ContentDetails: Decodable {
            let duration: String?
        }
    }
}
