import Foundation

actor DashboardCache {
    static let shared = DashboardCache()

    private var entries: [Int: CacheEntry] = [:]
    private let ttl: TimeInterval = 300

    private struct CacheEntry {
        let dashboard: PlayerDashboard
        let timestamp: Date
    }

    func get(_ playerID: Int) -> PlayerDashboard? {
        guard let entry = entries[playerID],
              Date().timeIntervalSince(entry.timestamp) < ttl else {
            return nil
        }
        return entry.dashboard
    }

    func set(_ dashboard: PlayerDashboard) {
        entries[dashboard.catalogEntry.id] = CacheEntry(dashboard: dashboard, timestamp: Date())
    }

    func clear() {
        entries.removeAll()
    }
}

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

    func fetchDashboard(for player: PlayerCatalogEntry, forceRefresh: Bool = false) async throws -> PlayerDashboard {
        if !forceRefresh, let cached = await DashboardCache.shared.get(player.id) {
            return cached
        }

        async let profile = fetchProfile(playerID: player.id)
        async let stats = fetchSeasonStats(player: player)
        async let stories = StoriesService().fetchStories(for: player)
        async let videos = StoriesService().fetchHighlights(for: player)
        async let gameLogs = fetchRecentGameLogs(player: player)

        guard let person = try await profile.people.first else {
            throw PlayerServiceError.missingProfile
        }

        let todayGame = await fetchTodayGame(teamID: person.currentTeam?.id, player: player)

        let dashboard = PlayerDashboard(
            catalogEntry: player,
            profile: person,
            seasonStat: try await stats.stats.first?.splits.first,
            stories: await stories,
            gameLogs: try await gameLogs,
            videos: await videos,
            todayGame: todayGame
        )

        await DashboardCache.shared.set(dashboard)
        return dashboard
    }

    private func fetchTodayGame(teamID: Int?, player: PlayerCatalogEntry) async -> TodayGame? {
        guard let teamID else { return nil }

        let today = scheduleDateFormatter.string(from: Date())
        let sportCandidates: [Int]
        if player.isMinorLeaguer {
            let preferred = player.preferredSportID.map { [$0] } ?? []
            sportCandidates = preferred + [11, 12, 13, 14, 16].filter { $0 != player.preferredSportID }
        } else {
            sportCandidates = [1]
        }

        for sportID in sportCandidates {
            if let game = try? await fetchScheduledGame(teamID: teamID, sportID: sportID, date: today) {
                return game
            }
        }
        return nil
    }

    private func fetchScheduledGame(teamID: Int, sportID: Int, date: String) async throws -> TodayGame? {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/schedule")!
        components.queryItems = [
            URLQueryItem(name: "sportId", value: String(sportID)),
            URLQueryItem(name: "teamId", value: String(teamID)),
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "hydrate", value: "linescore")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try decoder.decode(ScheduleResponse.self, from: data)
        guard let game = response.dates.first?.games.first else { return nil }

        let isHome = game.teams.home.team.id == teamID
        let opponentName = isHome ? game.teams.away.team.name : game.teams.home.team.name

        let state: TodayGame.State
        switch game.status?.abstractGameState?.lowercased() {
        case "live":
            state = .live
        case "final":
            state = .final
        default:
            state = .scheduled
        }

        let startTime = game.gameDate.flatMap { scheduleISOFormatter.date(from: $0) }

        let inningText: String?
        if state == .live, let inning = game.linescore?.currentInning {
            let half = game.linescore?.inningHalf?.prefix(1) ?? ""
            inningText = "\(half)\(inning)".trimmingCharacters(in: .whitespaces)
        } else {
            inningText = nil
        }

        return TodayGame(
            state: state,
            opponentName: opponentName,
            isHome: isHome,
            startTime: startTime,
            homeScore: game.teams.home.score,
            awayScore: game.teams.away.score,
            inningText: inningText
        )
    }

    private var scheduleDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var scheduleISOFormatter: ISO8601DateFormatter {
        ISO8601DateFormatter()
    }

    func fetchHomeSummary(players: [PlayerCatalogEntry], forceRefresh: Bool = false) async -> FormerDawgsHomeSummary {
        let dashboards = await loadDashboards(players: players, forceRefresh: forceRefresh)
        let favoriteIDs = Set(
            (SharedAppGroup.defaults.string(forKey: "favoritePlayerIDs") ?? "")
                .split(separator: ",")
                .compactMap { Int($0) }
        )
        let sortedStories = dashboards
            .flatMap { dashboard in
                dashboard.stories.map { HomeStoryHighlight(player: dashboard.catalogEntry, story: $0) }
            }
            .sorted { lhs, rhs in
                storyPublishedDate(for: lhs.story) > storyPublishedDate(for: rhs.story)
            }
        let activePlayers = dashboards
            .filter(isActiveToday)
            .sorted {
                $0.catalogEntry.displayName.localizedCaseInsensitiveCompare($1.catalogEntry.displayName) == .orderedAscending
            }

        return FormerDawgsHomeSummary(
            hottestHitter: dashboards
                .filter { $0.catalogEntry.kind == .hitter }
                .max(by: { weeklyPerformanceScore($0) < weeklyPerformanceScore($1) }),
            hottestPitcher: dashboards
                .filter { $0.catalogEntry.kind == .pitcher }
                .max(by: { weeklyPerformanceScore($0) < weeklyPerformanceScore($1) }),
            latestPromotion: sortedStories.first(where: isPromotionStory),
            latestHeadline: sortedStories.first,
            weeklyHitterLeaders: weeklyLeaders(from: dashboards, kind: .hitter),
            weeklyPitcherLeaders: weeklyLeaders(from: dashboards, kind: .pitcher),
            transactionTimeline: Array(sortedStories.filter(isTransactionStory).prefix(6)),
            favoritesWatchlist: dashboards
                .filter { favoriteIDs.contains($0.catalogEntry.id) }
                .sorted { lhs, rhs in
                    favoriteWatchScore(lhs) > favoriteWatchScore(rhs)
                },
            comparisonOptions: dashboards
                .sorted { lhs, rhs in
                    comparisonScore(lhs) > comparisonScore(rhs)
                },
            todaySummary: TodayPerformanceSummary(
                activePlayers: activePlayers,
                homeredToday: activePlayers.filter {
                    $0.catalogEntry.kind == .hitter && ($0.gameLogs.first?.homeRuns ?? 0) > 0
                },
                pitchedToday: activePlayers.filter {
                    $0.catalogEntry.kind == .pitcher && ($0.gameLogs.first?.inningsPitched ?? 0) > 0
                },
                multiHitToday: activePlayers.filter {
                    $0.catalogEntry.kind == .hitter && ($0.gameLogs.first?.hits ?? 0) >= 2
                }
            ),
            todaysActivePlayers: activePlayers
        )
    }

    private func fetchProfile(playerID: Int) async throws -> PlayerProfile {
        let url = URL(string: "https://statsapi.mlb.com/api/v1/people/\(playerID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(PlayerProfile.self, from: data)
    }

    private func loadDashboards(players: [PlayerCatalogEntry], forceRefresh: Bool) async -> [PlayerDashboard] {
        let batchSize = 8
        var allDashboards: [PlayerDashboard] = []

        var index = 0
        while index < players.count {
            let end = min(index + batchSize, players.count)
            let batch = Array(players[index..<end])

            let batchResults = await withTaskGroup(of: PlayerDashboard?.self) { group in
                for player in batch {
                    group.addTask {
                        try? await self.fetchDashboard(for: player, forceRefresh: forceRefresh)
                    }
                }

                var results: [PlayerDashboard] = []
                for await dashboard in group {
                    if let dashboard {
                        PlayerRuntimeStore.saveOverride(for: dashboard)
                        results.append(dashboard)
                    }
                }
                return results
            }

            allDashboards.append(contentsOf: batchResults)
            index = end
        }

        PlayerRuntimeStore.saveTodaysDawgsSnapshot(from: allDashboards)
        return allDashboards
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

        return GameLogEntry(
            dateText: dateText,
            opponentText: opponentText,
            line: line,
            homeRuns: split.stat.homeRuns,
            hits: split.stat.hits,
            rbi: split.stat.rbi,
            inningsPitched: Double(split.stat.inningsPitched ?? ""),
            strikeOuts: split.stat.strikeOuts,
            walks: split.stat.baseOnBalls
        )
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

    private func isTransactionStory(_ highlight: HomeStoryHighlight) -> Bool {
        let title = highlight.story.title.lowercased()
        return isPromotionStory(highlight)
            || title.contains("optioned")
            || title.contains("recalled")
            || title.contains("activated")
            || title.contains("injured list")
            || title.contains("traded")
            || title.contains("signs")
            || title.contains("signed")
    }

    private func isActiveToday(_ dashboard: PlayerDashboard) -> Bool {
        guard let firstLog = dashboard.gameLogs.first else {
            return false
        }

        return Calendar.current.isDateInToday(gameLogDate(from: firstLog.dateText))
    }

    private func weeklyLeaders(from dashboards: [PlayerDashboard], kind: PlayerKind) -> [HomeLeaderboardEntry] {
        dashboards
            .filter { $0.catalogEntry.kind == kind }
            .compactMap { dashboard in
                guard let entry = weeklyLeaderboardEntry(for: dashboard) else {
                    return nil
                }
                return entry
            }
            .sorted { lhs, rhs in
                lhs.score > rhs.score
            }
            .prefix(3)
            .map { $0 }
    }

    private func weeklyPerformanceScore(_ dashboard: PlayerDashboard) -> Double {
        weeklyLeaderboardEntry(for: dashboard)?.score ?? -.greatestFiniteMagnitude
    }

    private func weeklyLeaderboardEntry(for dashboard: PlayerDashboard) -> HomeLeaderboardEntry? {
        let recentLogs = dashboard.gameLogs.filter {
            guard let date = recentDate(from: $0.dateText) else { return false }
            return date >= Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        }

        guard !recentLogs.isEmpty else { return nil }

        if dashboard.catalogEntry.kind == .pitcher {
            let innings = recentLogs.reduce(0) { $0 + ($1.inningsPitched ?? 0) }
            let strikeouts = recentLogs.reduce(0) { $0 + ($1.strikeOuts ?? 0) }
            let walks = recentLogs.reduce(0) { $0 + ($1.walks ?? 0) }
            let score = (Double(strikeouts) * 2.5) + innings - Double(walks)
            return HomeLeaderboardEntry(
                dashboard: dashboard,
                score: score,
                scoreText: String(format: "%.1f", score),
                detailText: "\(String(format: "%.1f", innings)) IP • \(strikeouts) K • \(walks) BB this week"
            )
        }

        let hits = recentLogs.reduce(0) { $0 + ($1.hits ?? 0) }
        let homeRuns = recentLogs.reduce(0) { $0 + ($1.homeRuns ?? 0) }
        let rbi = recentLogs.reduce(0) { $0 + ($1.rbi ?? 0) }
        let score = (Double(hits) * 1.5) + (Double(homeRuns) * 4) + (Double(rbi) * 1.5)
        return HomeLeaderboardEntry(
            dashboard: dashboard,
            score: score,
            scoreText: String(format: "%.1f", score),
            detailText: "\(hits) H • \(homeRuns) HR • \(rbi) RBI this week"
        )
    }

    private func recentDate(from value: String) -> Date? {
        gameLogDateFormatter.date(from: value)
    }

    private func favoriteWatchScore(_ dashboard: PlayerDashboard) -> Double {
        if let firstLog = dashboard.gameLogs.first, Calendar.current.isDateInToday(gameLogDate(from: firstLog.dateText)) {
            return 1000 + comparisonScore(dashboard)
        }
        return comparisonScore(dashboard)
    }

    private func comparisonScore(_ dashboard: PlayerDashboard) -> Double {
        dashboard.catalogEntry.kind == .pitcher ? pitcherScore(dashboard) : hitterScore(dashboard)
    }
}
