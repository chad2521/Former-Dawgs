import Foundation

enum PlayerServiceError: LocalizedError {
    case missingProfile

    var errorDescription: String? {
        switch self {
        case .missingProfile:
            return "Could not load this player's MLB profile."
        }
    }
}

struct PlayerService {
    private let decoder = JSONDecoder()
    private let gameLogDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private let storyPublishedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()

    func fetchDashboard(for player: PlayerCatalogEntry) async throws -> PlayerDashboard {
        async let profile = fetchProfile(playerID: player.id)
        async let stats = fetchSeasonStats(player: player)
        async let stories = StoriesService().fetchStories(for: player)
        async let videos = StoriesService().fetchHighlights(for: player)
        async let gameLogs = fetchRecentGameLogs(player: player)

        guard let person = try await profile.people.first else {
            throw PlayerServiceError.missingProfile
        }

        return PlayerDashboard(
            catalogEntry: player,
            profile: person,
            seasonStat: try await stats.stats.first?.splits.first,
            stories: try await stories,
            gameLogs: try await gameLogs,
            videos: try await videos
        )
    }

    func fetchHomeSummary(players: [PlayerCatalogEntry]) async -> FormerDawgsHomeSummary {
        let dashboards = await loadDashboards(players: players)
        let sortedStories = dashboards
            .flatMap { dashboard in
                dashboard.stories.map { HomeStoryHighlight(player: dashboard.catalogEntry, story: $0) }
            }
            .sorted { lhs, rhs in
                storyPublishedDate(for: lhs.story) > storyPublishedDate(for: rhs.story)
            }

        return FormerDawgsHomeSummary(
            hottestHitter: dashboards
                .filter { $0.catalogEntry.kind == .hitter }
                .max(by: { hitterScore($0) < hitterScore($1) }),
            hottestPitcher: dashboards
                .filter { $0.catalogEntry.kind == .pitcher }
                .max(by: { pitcherScore($0) < pitcherScore($1) }),
            latestPromotion: sortedStories.first(where: isPromotionStory),
            latestHeadline: sortedStories.first,
            todaysActivePlayers: dashboards
                .filter(isActiveToday)
                .sorted {
                    $0.catalogEntry.displayName.localizedCaseInsensitiveCompare($1.catalogEntry.displayName) == .orderedAscending
                }
        )
    }

    private func fetchProfile(playerID: Int) async throws -> PlayerProfile {
        let url = URL(string: "https://statsapi.mlb.com/api/v1/people/\(playerID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(PlayerProfile.self, from: data)
    }

    private func loadDashboards(players: [PlayerCatalogEntry]) async -> [PlayerDashboard] {
        await withTaskGroup(of: PlayerDashboard?.self) { group in
            for player in players {
                group.addTask {
                    try? await fetchDashboard(for: player)
                }
            }

            var dashboards: [PlayerDashboard] = []
            for await dashboard in group {
                guard let dashboard else { continue }
                PlayerRuntimeStore.saveOverride(for: dashboard)
                dashboards.append(dashboard)
            }
            return dashboards
        }
    }

    private func fetchSeasonStats(player: PlayerCatalogEntry) async throws -> PlayerStatsResponse {
        let season = Calendar.current.component(.year, from: Date())
        let sportIDs = statSportIDs(for: player)

        for sportID in sportIDs {
            let response = try await fetchSeasonStats(player: player, season: season, sportID: sportID)
            if response.stats.first?.splits.isEmpty == false {
                return response
            }
        }

        return try await fetchSeasonStats(player: player, season: season, sportID: nil)
    }

    private func fetchSeasonStats(player: PlayerCatalogEntry, season: Int, sportID: Int?) async throws -> PlayerStatsResponse {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/people/\(player.id)/stats")!
        var queryItems = [
            URLQueryItem(name: "stats", value: "season"),
            URLQueryItem(name: "group", value: player.kind == .pitcher ? "pitching" : "hitting"),
            URLQueryItem(name: "season", value: String(season))
        ]
        if let sportID {
            queryItems.append(URLQueryItem(name: "sportId", value: String(sportID)))
        }
        components.queryItems = queryItems

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try decoder.decode(PlayerStatsResponse.self, from: data)
    }

    private func statSportIDs(for player: PlayerCatalogEntry) -> [Int?] {
        guard player.isMinorLeaguer else {
            return [nil]
        }

        let allMinorLevels = [11, 12, 13, 14, 16]
        let preferred = player.preferredSportID.map { [$0] } ?? []
        let fallbacks = allMinorLevels.filter { $0 != player.preferredSportID }
        return (preferred + fallbacks).map { Optional($0) }
    }

    private func fetchRecentGameLogs(player: PlayerCatalogEntry) async throws -> [GameLogEntry] {
        let season = Calendar.current.component(.year, from: Date())
        let sportIDs = statSportIDs(for: player)

        for sportID in sportIDs {
            let response = try await fetchRecentGameLogs(player: player, season: season, sportID: sportID)
            if response.stats.first?.splits.isEmpty == false {
                let sortedSplits = (response.stats.first?.splits ?? []).sorted { lhs, rhs in
                    gameLogDate(from: lhs.date) > gameLogDate(from: rhs.date)
                }
                return sortedSplits.prefix(8).map { split in
                    gameLogEntry(from: split, kind: player.kind)
                }
            }
        }

        let fallback = try await fetchRecentGameLogs(player: player, season: season, sportID: nil)
        let sortedSplits = (fallback.stats.first?.splits ?? []).sorted { lhs, rhs in
            gameLogDate(from: lhs.date) > gameLogDate(from: rhs.date)
        }
        return sortedSplits.prefix(8).map { split in
            gameLogEntry(from: split, kind: player.kind)
        }
    }

    private func fetchRecentGameLogs(player: PlayerCatalogEntry, season: Int, sportID: Int?) async throws -> GameLogResponse {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/people/\(player.id)/stats")!
        var queryItems = [
            URLQueryItem(name: "stats", value: "gameLog"),
            URLQueryItem(name: "group", value: player.kind == .pitcher ? "pitching" : "hitting"),
            URLQueryItem(name: "season", value: String(season))
        ]
        if let sportID {
            queryItems.append(URLQueryItem(name: "sportId", value: String(sportID)))
        }
        components.queryItems = queryItems

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try decoder.decode(GameLogResponse.self, from: data)
    }

    private func gameLogEntry(from split: GameLogResponse.Split, kind: PlayerKind) -> GameLogEntry {
        let dateText = split.date ?? "Recent Game"
        let opponent = split.opponent?.name ?? "Opponent"
        let opponentText = split.isHome == true ? "vs \(opponent)" : "@ \(opponent)"

        let line: String
        if let summary = split.stat.summary, !summary.isEmpty {
            line = summary
        } else if kind == .pitcher {
            line = [
                "\(split.stat.inningsPitched ?? "-") IP",
                "\(split.stat.era ?? "-") ERA",
                "\(display(split.stat.strikeOuts)) K",
                "\(display(split.stat.baseOnBalls)) BB"
            ].joined(separator: " • ")
        } else {
            line = [
                "\(display(split.stat.hits)) H",
                "\(display(split.stat.rbi)) RBI",
                "\(display(split.stat.homeRuns)) HR",
                "\(split.stat.avg ?? "-") AVG"
            ].joined(separator: " • ")
        }

        return GameLogEntry(dateText: dateText, opponentText: opponentText, line: line)
    }

    private func display(_ value: Int?) -> String {
        guard let value else { return "-" }
        return String(value)
    }

    private func gameLogDate(from value: String?) -> Date {
        guard let value else { return .distantPast }
        return gameLogDateFormatter.date(from: value) ?? .distantPast
    }

    private func storyPublishedDate(for story: Story) -> Date {
        storyPublishedDateFormatter.date(from: story.publishedText) ?? .distantPast
    }

    private func hitterScore(_ dashboard: PlayerDashboard) -> Double {
        guard let stat = dashboard.seasonStat?.stat else { return -.greatestFiniteMagnitude }
        return score(for: stat.ops) * 100
            + score(for: stat.avg) * 25
            + Double(stat.homeRuns ?? 0) * 4
            + Double(stat.rbi ?? 0) * 1.5
            + Double(stat.hits ?? 0) * 0.2
    }

    private func pitcherScore(_ dashboard: PlayerDashboard) -> Double {
        guard let stat = dashboard.seasonStat?.stat else { return -.greatestFiniteMagnitude }
        return Double(stat.strikeOuts ?? 0) * 2
            + Double(stat.wins ?? 0) * 3
            + Double(stat.saves ?? 0) * 2
            - score(for: stat.era) * 12
            - score(for: stat.whip) * 10
    }

    private func score(for value: String?) -> Double {
        Double(value ?? "") ?? 0
    }

    private func isPromotionStory(_ highlight: HomeStoryHighlight) -> Bool {
        let title = highlight.story.title.lowercased()
        return title.contains("promot")
            || title.contains("called up")
            || title.contains("call-up")
            || title.contains("selects the contract")
            || title.contains("selected the contract")
            || title.contains("joins ")
            || title.contains("assigned to")
    }

    private func isActiveToday(_ dashboard: PlayerDashboard) -> Bool {
        guard let firstLog = dashboard.gameLogs.first else {
            return false
        }

        return Calendar.current.isDateInToday(gameLogDate(from: firstLog.dateText))
    }
}
