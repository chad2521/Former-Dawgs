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
            let title = (item.description?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? item.typeDesc
                ?? "Roster move"
            let published = item.effectiveDate ?? item.date ?? ""
            return Story(
                title: title,
                source: "MLB",
                publishedText: published,
                url: pageURL
            )
        }

        var seen = Set<String>()
        let unique = stories.filter { story in
            let key = story.title.lowercased()
            return seen.insert(key).inserted
        }
        return Array(unique.prefix(8))
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
            ?? URL(string: "https://www.mlb.com/player/\(player.id)")!
    }

    private func apiDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct TransactionsResponse: Decodable {
    let transactions: [Item]

    struct Item: Decodable {
        let date: String?
        let effectiveDate: String?
        let typeDesc: String?
        let description: String?
    }
}
