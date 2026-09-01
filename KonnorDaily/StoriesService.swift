import Foundation

/// Headlines, promotions, and transactions for a Dawg.
/// Default source is the MLB Stats API (transactions). Fallback is the official
/// MLB.com / MiLB.com player page. Google News RSS is not used.
final class StoriesService {
    func fetchStories(for player: PlayerCatalogEntry) async -> [Story] {
        let transactions = await fetchTransactions(for: player)
        if !transactions.isEmpty {
            return transactions
        }
        return fallbackPlayerPageStories(for: player)
    }

    func fetchHighlights(for player: PlayerCatalogEntry) async -> [HighlightVideo] {
        if let best = await YouTubeHighlightService().bestHighlight(
            for: player.displayName,
            preferPitching: player.kind == .pitcher
        ) {
            return [best]
        }
        return []
    }

    /// League-wide MLB/MiLB transactions for the whole roster (a few HTTP calls).
    /// Used by Home so a call-up is not missed just because the player was not
    /// in the previous top-10 story fetch.
    func fetchRecentRosterStories(playerIDs: Set<Int>) async -> [Int: [Story]] {
        guard !playerIDs.isEmpty else { return [:] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -21, to: end) ?? end
        let startText = apiDateString(from: start)
        let endText = apiDateString(from: end)
        let sportIDs = [1, 11, 12, 13, 14]

        var grouped: [Int: [Story]] = [:]
        await withTaskGroup(of: [Int: [Story]].self) { group in
            for sportID in sportIDs {
                group.addTask {
                    (try? await StoriesService().fetchLeagueTransactions(
                        playerIDs: playerIDs,
                        sportID: sportID,
                        startDate: startText,
                        endDate: endText
                    )) ?? [:]
                }
            }
            for await batch in group {
                for (playerID, stories) in batch {
                    grouped[playerID, default: []].append(contentsOf: stories)
                }
            }
        }

        var result: [Int: [Story]] = [:]
        result.reserveCapacity(grouped.count)
        for (playerID, stories) in grouped {
            var seen = Set<String>()
            let unique = stories
                .sorted { publishedSortKey($0.publishedText) > publishedSortKey($1.publishedText) }
                .filter { story in
                    seen.insert(story.title.lowercased()).inserted
                }
            if !unique.isEmpty {
                result[playerID] = Array(unique.prefix(8))
            }
        }
        return result
    }

    private func fetchTransactions(for player: PlayerCatalogEntry) async -> [Story] {
        var sportIDs: [Int] = [1]
        if let preferred = player.preferredSportID, preferred != 1 {
            sportIDs.insert(preferred, at: 0)
        }

        let calendar = Calendar(identifier: .gregorian)
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -180, to: end) ?? end
        let startText = apiDateString(from: start)
        let endText = apiDateString(from: end)

        for sportID in sportIDs {
            if let stories = try? await fetchTransactions(
                playerID: player.id,
                sportID: sportID,
                startDate: startText,
                endDate: endText,
                player: player
            ), !stories.isEmpty {
                return stories
            }
        }

        if let stories = try? await fetchTransactions(
            playerID: player.id,
            sportID: nil,
            startDate: startText,
            endDate: endText,
            player: player
        ), !stories.isEmpty {
            return stories
        }
        return []
    }

    private func fetchTransactions(
        playerID: Int,
        sportID: Int?,
        startDate: String,
        endDate: String,
        player: PlayerCatalogEntry
    ) async throws -> [Story] {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/transactions")!
        var items = [
            URLQueryItem(name: "playerId", value: String(playerID)),
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate)
        ]
        if let sportID {
            items.append(URLQueryItem(name: "sportId", value: String(sportID)))
        }
        components.queryItems = items

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(TransactionsResponse.self, from: data)
        let pageURL = playerPageURL(for: player)

        let stories: [Story] = response.transactions.compactMap { item in
            story(from: item, url: pageURL)
        }

        var seen = Set<String>()
        let unique = stories.filter { story in
            let key = story.title.lowercased()
            return seen.insert(key).inserted
        }
        return Array(unique.prefix(8))
    }

    private func fetchLeagueTransactions(
        playerIDs: Set<Int>,
        sportID: Int,
        startDate: String,
        endDate: String
    ) async throws -> [Int: [Story]] {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/transactions")!
        components.queryItems = [
            URLQueryItem(name: "sportId", value: String(sportID)),
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(TransactionsResponse.self, from: data)
        let isMinor = sportID != 1

        var grouped: [Int: [Story]] = [:]
        for item in response.transactions {
            guard let playerID = item.person?.id, playerIDs.contains(playerID) else { continue }
            guard let mapped = story(from: item, url: playerPageURL(playerID: playerID, isMinor: isMinor)) else {
                continue
            }
            grouped[playerID, default: []].append(mapped)
        }
        return grouped
    }

    private func story(from item: TransactionsResponse.Item, url: URL) -> Story? {
        let title = (item.description?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? item.typeDesc
            ?? "Roster move"
        let published = item.effectiveDate ?? item.date ?? ""
        return Story(
            title: title,
            source: "MLB",
            publishedText: published,
            url: url
        )
    }

    private func fallbackPlayerPageStories(for player: PlayerCatalogEntry) -> [Story] {
        let isMinor = player.effectiveIsMinorLeaguerPublic
        return [
            Story(
                title: "\(player.displayName) — official \(isMinor ? "MiLB" : "MLB") player page",
                source: isMinor ? "MiLB.com" : "MLB.com",
                publishedText: apiDateString(from: Date()),
                url: playerPageURL(for: player)
            )
        ]
    }

    private func playerPageURL(for player: PlayerCatalogEntry) -> URL {
        let slug = player.displayName
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "-")
        let host = player.effectiveIsMinorLeaguerPublic ? "www.milb.com" : "www.mlb.com"
        return URL(string: "https://\(host)/player/\(slug)-\(player.id)")
            ?? playerPageURL(playerID: player.id, isMinor: player.effectiveIsMinorLeaguerPublic)
    }

    private func playerPageURL(playerID: Int, isMinor: Bool) -> URL {
        let host = isMinor ? "www.milb.com" : "www.mlb.com"
        return URL(string: "https://\(host)/player/\(playerID)")
            ?? URL(string: "https://www.mlb.com/player/\(playerID)")!
    }

    private func apiDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func publishedSortKey(_ value: String) -> String {
        if value.count >= 10 {
            return String(value.prefix(10))
        }
        return value
    }
}

private struct TransactionsResponse: Decodable {
    let transactions: [Item]

    struct Item: Decodable {
        let date: String?
        let effectiveDate: String?
        let typeDesc: String?
        let description: String?
        let person: Person?

        struct Person: Decodable {
            let id: Int?
        }
    }
}
