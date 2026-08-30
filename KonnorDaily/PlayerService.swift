import Foundation

/// Where a returned dashboard came from, so callers can surface freshness/offline state.
enum DashboardOrigin {
    case network        // Fetched fresh from the API on this call.
    case freshCache     // Recent cache hit; the network was intentionally skipped.
    case staleFallback  // Network failed; served an older cached copy so the app still works offline.
}

actor DashboardCache {
    static let shared = DashboardCache()

    struct Entry {
        let dashboard: PlayerDashboard
        let timestamp: Date
    }

    private var entries: [Int: Entry] = [:]
    private let ttl: TimeInterval = 300

    private func cacheKey(_ playerID: Int) -> String { "dashboard-\(playerID)" }

    /// In-memory entry, falling back to the on-disk copy (which survives relaunches).
    private func entry(for playerID: Int) -> Entry? {
        if let entry = entries[playerID] {
            return entry
        }
        guard let payload = OfflineCache.load(PlayerDashboard.self, forKey: cacheKey(playerID)) else {
            return nil
        }
        let entry = Entry(dashboard: payload.value, timestamp: payload.savedAt)
        entries[playerID] = entry
        return entry
    }

    /// A hit only when the stored copy is still within the freshness window.
    func fresh(_ playerID: Int) -> PlayerDashboard? {
        guard let entry = entry(for: playerID),
              Date().timeIntervalSince(entry.timestamp) < ttl else {
            return nil
        }
        return entry.dashboard
    }

    /// The most recent cached copy regardless of age (for offline fallback / instant display).
    func stale(_ playerID: Int) -> Entry? {
        entry(for: playerID)
    }

    func set(_ dashboard: PlayerDashboard) {
        entries[dashboard.catalogEntry.id] = Entry(dashboard: dashboard, timestamp: Date())
        OfflineCache.save(dashboard, forKey: cacheKey(dashboard.catalogEntry.id))
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

/// Controls which extras are pulled when building a player dashboard.
struct DashboardFetchOptions: Sendable {
    var includeStories: Bool
    var includeVideos: Bool

    /// Full player page: stories + highlight links.
    static let full = DashboardFetchOptions(includeStories: true, includeVideos: true)
    /// Home / scoreboard bulk load: stats + games only (much faster).
    static let core = DashboardFetchOptions(includeStories: false, includeVideos: false)
}

struct PlayerService {
    /// Caps concurrent player fetches so we don't stampede MLB / News endpoints.
    private static let maxConcurrentPlayerFetches = 8

    func fetchDashboard(for player: PlayerCatalogEntry, forceRefresh: Bool = false) async throws -> PlayerDashboard {
        try await fetchDashboardWithOrigin(for: player, forceRefresh: forceRefresh).dashboard
    }

    /// The most recent cached dashboard for a player, if any, for instant display
    /// while a fresh copy loads. Returns `nil` when nothing has been cached yet.
    func cachedDashboard(for player: PlayerCatalogEntry) async -> (dashboard: PlayerDashboard, timestamp: Date)? {
        guard let entry = await DashboardCache.shared.stale(player.id) else { return nil }
        return (entry.dashboard, entry.timestamp)
    }

    /// Instant home paint from on-disk dashboards (no network).
    func cachedHomeSummary(players: [PlayerCatalogEntry]) async -> FormerDawgsHomeSummary? {
        var dashboards: [PlayerDashboard] = []
        dashboards.reserveCapacity(players.count)
        for player in players {
            if let entry = await DashboardCache.shared.stale(player.id) {
                dashboards.append(entry.dashboard)
            }
        }
        guard !dashboards.isEmpty else { return nil }
        return makeHomeSummary(from: dashboards)
    }

    func fetchDashboardWithOrigin(
        for player: PlayerCatalogEntry,
        forceRefresh: Bool = false,
        options: DashboardFetchOptions = .full
    ) async throws -> (dashboard: PlayerDashboard, origin: DashboardOrigin) {
        if !forceRefresh, let cached = await DashboardCache.shared.fresh(player.id) {
            return (cached, .freshCache)
        }

        do {
            // Core MLB calls in parallel — biggest per-player win after concurrency.
            async let profileTask = fetchProfile(playerID: player.id)
            async let statsTask = fetchSeasonStats(player: player)
            async let logsTask = fetchRecentGameLogs(player: player)

            let profile = try await profileTask
            guard let person = profile.people.first else {
                throw PlayerServiceError.missingProfile
            }

            let stats = try await statsTask
            let seasonStat = stats.stats.first?.splits.first
            let gameLogs = try await logsTask
            let teamID = resolveTeamID(person: person, seasonStat: seasonStat, player: player)
            var todayGame = await fetchTodayGame(teamID: teamID, player: player)

            // If schedule lookup failed (missing team id, API quirk) but the player
            // already has a game log for today, still surface them on Tonight.
            if todayGame == nil {
                todayGame = syntheticTodayGame(from: gameLogs.first)
            }

            let stories: [Story]
            let videos: [HighlightVideo]
            if options.includeStories && options.includeVideos {
                async let storyTask = StoriesService().fetchStories(for: player)
                async let videoTask = StoriesService().fetchHighlights(for: player)
                stories = await storyTask
                videos = await videoTask
            } else if options.includeStories {
                async let storyTask = StoriesService().fetchStories(for: player)
                let prior = await DashboardCache.shared.stale(player.id)?.dashboard
                stories = await storyTask
                videos = prior?.videos ?? []
            } else if options.includeVideos {
                async let videoTask = StoriesService().fetchHighlights(for: player)
                let prior = await DashboardCache.shared.stale(player.id)?.dashboard
                stories = prior?.stories ?? []
                videos = await videoTask
            } else if let prior = await DashboardCache.shared.stale(player.id)?.dashboard {
                // Keep prior media so core refreshes don't blank home headlines.
                stories = prior.stories
                videos = prior.videos
            } else {
                stories = []
                videos = []
            }

            let dashboard = PlayerDashboard(
                catalogEntry: player,
                profile: person,
                seasonStat: seasonStat,
                stories: stories,
                gameLogs: gameLogs,
                videos: videos,
                todayGame: todayGame
            )

            await DashboardCache.shared.set(dashboard)
            return (dashboard, .network)
        } catch {
            // Offline / API failure: fall back to the last cached copy so the app stays usable.
            if let stale = await DashboardCache.shared.stale(player.id) {
                return (stale.dashboard, .staleFallback)
            }
            throw error
        }
    }

    private func fetchTodayGame(teamID: Int?, player: PlayerCatalogEntry) async -> TodayGame? {
        guard let teamID else { return nil }

        let today = scheduleDateFormatter.string(from: Date())
        for sportID in sportCandidates(for: player) {
            if let game = try? await fetchScheduledGame(
                teamID: teamID,
                sportID: sportID,
                date: today,
                resolveVenueCoordinates: true
            ) {
                return game
            }
        }
        return nil
    }

    /// 7-day "when do the Dawgs play?" schedule, favorites first within each day.
    func fetchThisWeekSchedule(
        from dashboards: [PlayerDashboard],
        favoriteIDs: Set<Int>
    ) async -> [WeekDayGroup] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else { return [] }
        let startKey = scheduleDateFormatter.string(from: start)
        let endKey = scheduleDateFormatter.string(from: end)

        // Cache schedule fetches by team+sport so 5 Rays farmhands only hit the API once.
        var scheduleCache: [String: [String: TodayGame]] = [:]
        var entries: [WeekScheduleEntry] = []

        for dashboard in dashboards {
            let player = dashboard.catalogEntry
            let teamID = resolveTeamID(
                person: dashboard.profile,
                seasonStat: dashboard.seasonStat,
                player: player
            )
            guard let teamID else { continue }

            var gamesByDate: [String: TodayGame] = [:]
            for sportID in sportCandidates(for: player) {
                let cacheKey = "\(teamID)-\(sportID)-\(startKey)-\(endKey)"
                if let cached = scheduleCache[cacheKey] {
                    for (dateKey, game) in cached where gamesByDate[dateKey] == nil {
                        gamesByDate[dateKey] = game
                    }
                    continue
                }
                let fetched = (try? await fetchScheduledGamesInRange(
                    teamID: teamID,
                    sportID: sportID,
                    startDate: startKey,
                    endDate: endKey
                )) ?? [:]
                scheduleCache[cacheKey] = fetched
                for (dateKey, game) in fetched where gamesByDate[dateKey] == nil {
                    gamesByDate[dateKey] = game
                }
            }

            // Prefer live todayGame for today when the range hydrate is thin.
            if let todayGame = dashboard.todayGame {
                gamesByDate[startKey] = todayGame
            }

            for (dateKey, game) in gamesByDate {
                entries.append(
                    WeekScheduleEntry(
                        player: player,
                        dateKey: dateKey,
                        game: game,
                        isFavorite: favoriteIDs.contains(player.id)
                    )
                )
            }
        }

        let dayFormatter = scheduleDateFormatter
        var groups: [WeekDayGroup] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let key = dayFormatter.string(from: day)
            let dayEntries = entries
                .filter { $0.dateKey == key }
                .sorted { lhs, rhs in
                    if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
                    let lhsTime = lhs.game.startTime ?? .distantFuture
                    let rhsTime = rhs.game.startTime ?? .distantFuture
                    if lhsTime != rhsTime { return lhsTime < rhsTime }
                    return lhs.player.displayName.localizedCaseInsensitiveCompare(rhs.player.displayName) == .orderedAscending
                }
            groups.append(WeekDayGroup(dateKey: key, date: day, entries: dayEntries))
        }
        return groups
    }

    private func sportCandidates(for player: PlayerCatalogEntry) -> [Int] {
        if player.effectiveIsMinorLeaguerPublic || player.isMinorLeaguer {
            var base: [Int] = []
            if let nested = PlayerRuntimeStore.sportID(for: player.id), let runtimeSport = nested {
                base.append(runtimeSport)
            }
            if let preferred = player.preferredSportID {
                base.append(preferred)
            }
            base.append(contentsOf: [11, 12, 13, 14, 16, 1])
            var seen = Set<Int>()
            return base.filter { seen.insert($0).inserted }
        }
        return [1]
    }

    private func fetchScheduledGame(
        teamID: Int,
        sportID: Int,
        date: String,
        resolveVenueCoordinates: Bool
    ) async throws -> TodayGame? {
        let games = try await fetchScheduledGamesInRange(
            teamID: teamID,
            sportID: sportID,
            startDate: date,
            endDate: date,
            resolveVenueCoordinates: resolveVenueCoordinates
        )
        return games[date]
    }

    private func fetchScheduledGamesInRange(
        teamID: Int,
        sportID: Int,
        startDate: String,
        endDate: String,
        resolveVenueCoordinates: Bool = false
    ) async throws -> [String: TodayGame] {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/schedule")!
        components.queryItems = [
            URLQueryItem(name: "sportId", value: String(sportID)),
            URLQueryItem(name: "teamId", value: String(teamID)),
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate),
            URLQueryItem(name: "hydrate", value: "linescore,venue")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(ScheduleResponse.self, from: data)
        var result: [String: TodayGame] = [:]

        for dateBlock in response.dates {
            guard let dateKey = dateBlock.date, let game = dateBlock.games.first else { continue }
            let isHome = game.teams.home.team.id == teamID
            let opponentName = isHome ? game.teams.away.team.name : game.teams.home.team.name
            let homeTeamID = game.teams.home.team.id

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

            let venue: (name: String?, city: String?, latitude: Double?, longitude: Double?)
            if resolveVenueCoordinates {
                venue = await resolveVenue(game: game, homeTeamID: homeTeamID)
            } else {
                venue = (game.venue?.name, nil, nil, nil)
            }

            result[dateKey] = TodayGame(
                state: state,
                opponentName: opponentName,
                isHome: isHome,
                startTime: startTime,
                homeScore: game.teams.home.score,
                awayScore: game.teams.away.score,
                inningText: inningText,
                venueName: venue.name,
                venueCity: venue.city,
                latitude: venue.latitude,
                longitude: venue.longitude,
                homeTeamID: homeTeamID
            )
        }

        return result
    }

    private func resolveVenue(
        game: ScheduleResponse.Game,
        homeTeamID: Int
    ) async -> (name: String?, city: String?, latitude: Double?, longitude: Double?) {
        if let venueID = game.venue?.id {
            if let cached = VenueCoordinateCache.entry(for: venueID) {
                return (cached.name ?? game.venue?.name, cached.city, cached.latitude, cached.longitude)
            }
            if let remote = await fetchVenueLocation(venueID: venueID) {
                VenueCoordinateCache.store(
                    .init(
                        latitude: remote.latitude,
                        longitude: remote.longitude,
                        city: remote.city,
                        name: remote.name ?? game.venue?.name
                    ),
                    for: venueID
                )
                return (remote.name ?? game.venue?.name, remote.city, remote.latitude, remote.longitude)
            }
        }

        if let park = BallparkCatalog.park(forTeamID: homeTeamID) {
            return (game.venue?.name ?? park.name, park.city, park.latitude, park.longitude)
        }

        return (game.venue?.name, nil, nil, nil)
    }

    private func fetchVenueLocation(venueID: Int) async -> (name: String?, city: String?, latitude: Double, longitude: Double)? {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/venues/\(venueID)")!
        components.queryItems = [URLQueryItem(name: "hydrate", value: "location")]
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(VenueDetailsResponse.self, from: data)
            guard let venue = response.venues.first,
                  let coords = venue.location?.defaultCoordinates else {
                return nil
            }
            let cityParts = [venue.location?.city, venue.location?.stateAbbrev].compactMap { $0 }
            let city = cityParts.isEmpty ? nil : cityParts.joined(separator: ", ")
            return (venue.name, city, coords.latitude, coords.longitude)
        } catch {
            return nil
        }
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
        await fetchHomeSummaryDetailed(players: players, forceRefresh: forceRefresh).summary
    }

    /// Same as `fetchHomeSummary`, but also reports whether the result was served
    /// entirely from cache because the network was unavailable (offline state).
    /// Favorites, known game-day players, and MLB catalog — small enough for a first Home paint.
    func firstPaintPlayers() -> [PlayerCatalogEntry] {
        let favoriteIDs = FavoritePlayerStore.ids(
            from: SharedAppGroup.defaults.string(forKey: "favoritePlayerIDs") ?? ""
        )
        let gameToday = PlayerRuntimeStore.playersWithGameToday()
        let players = PlayerCatalog.players
        let priority = players.filter { player in
            favoriteIDs.contains(player.id)
                || gameToday.contains(player.id)
                || !player.isMinorLeaguer
        }
        return priority.isEmpty ? players : priority
    }

    func fetchHomeSummaryDetailed(
        players: [PlayerCatalogEntry],
        forceRefresh: Bool = false,
        options: DashboardFetchOptions = .core,
        includeHomeStories: Bool = true,
        persistSnapshots: Bool = true
    ) async -> (summary: FormerDawgsHomeSummary, isStale: Bool) {
        let loaded = await loadDashboards(
            players: players,
            forceRefresh: forceRefresh,
            options: options,
            persistSnapshots: persistSnapshots
        )
        let dashboards: [PlayerDashboard]
        if includeHomeStories {
            dashboards = await enrichHomeStories(loaded.dashboards)
        } else {
            dashboards = loaded.dashboards
        }
        let summary = makeHomeSummary(from: dashboards)
        if persistSnapshots {
            PlayerRuntimeStore.saveHomeWidgetSnapshots(from: summary)
        }
        return (summary, loaded.servedStale)
    }

    private func makeHomeSummary(from dashboards: [PlayerDashboard]) -> FormerDawgsHomeSummary {
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
            todaysActivePlayers: activePlayers,
            tonightScoreboard: Self.sortedTonightScoreboard(from: dashboards)
        )
    }

    /// Pull MLB transactions/headlines only for favorites / active / top performers (not the full roster).
    private func enrichHomeStories(_ dashboards: [PlayerDashboard]) async -> [PlayerDashboard] {
        let favoriteIDs = Set(
            (SharedAppGroup.defaults.string(forKey: "favoritePlayerIDs") ?? "")
                .split(separator: ",")
                .compactMap { Int($0) }
        )

        let priority = dashboards.sorted { lhs, rhs in
            let lScore = homeStoryPriorityScore(lhs, favoriteIDs: favoriteIDs)
            let rScore = homeStoryPriorityScore(rhs, favoriteIDs: favoriteIDs)
            if lScore != rScore { return lScore > rScore }
            return lhs.catalogEntry.displayName < rhs.catalogEntry.displayName
        }
        let targets = Array(priority.prefix(10))

        var storyMap: [Int: [Story]] = [:]
        await withTaskGroup(of: (Int, [Story]).self) { group in
            for dashboard in targets {
                // Skip network if we already have recent stories on the dashboard.
                if !dashboard.stories.isEmpty { continue }
                let player = dashboard.catalogEntry
                group.addTask {
                    let stories = await StoriesService().fetchStories(for: player)
                    return (player.id, stories)
                }
            }
            for await (id, stories) in group {
                if !stories.isEmpty {
                    storyMap[id] = stories
                }
            }
        }

        guard !storyMap.isEmpty else { return dashboards }

        var updatedDashboards: [PlayerDashboard] = []
        updatedDashboards.reserveCapacity(dashboards.count)
        for dashboard in dashboards {
            guard let stories = storyMap[dashboard.catalogEntry.id] else {
                updatedDashboards.append(dashboard)
                continue
            }
            let updated = PlayerDashboard(
                catalogEntry: dashboard.catalogEntry,
                profile: dashboard.profile,
                seasonStat: dashboard.seasonStat,
                stories: stories,
                gameLogs: dashboard.gameLogs,
                videos: dashboard.videos,
                todayGame: dashboard.todayGame
            )
            await DashboardCache.shared.set(updated)
            updatedDashboards.append(updated)
        }
        return updatedDashboards
    }

    private func homeStoryPriorityScore(_ dashboard: PlayerDashboard, favoriteIDs: Set<Int>) -> Double {
        var score = 0.0
        if favoriteIDs.contains(dashboard.catalogEntry.id) { score += 100 }
        if isActiveToday(dashboard) { score += 50 }
        if dashboard.todayGame != nil { score += 25 }
        score += weeklyPerformanceScore(dashboard)
        return score
    }

    private func fetchProfile(playerID: Int) async throws -> PlayerProfile {
        // `currentTeam` is often omitted unless hydrated — without it, Tonight
        // can't resolve the club schedule (e.g. Jake Mangum / Pirates).
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/people/\(playerID)")!
        components.queryItems = [URLQueryItem(name: "hydrate", value: "currentTeam")]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(PlayerProfile.self, from: data)
    }

    /// Prefer live `currentTeam`, then season-stat club, then catalog logo → franchise id.
    private func resolveTeamID(
        person: PlayerProfile.Person,
        seasonStat: PlayerStatsResponse.Split?,
        player: PlayerCatalogEntry
    ) -> Int? {
        if let id = person.currentTeam?.id { return id }
        if let id = seasonStat?.team?.id { return id }
        if let code = player.teamLogoCode, let id = TeamLogoCatalog.teamID(for: code) {
            return id
        }
        return nil
    }

    /// Build a minimal TodayGame from today's box-score line when schedule hydrate fails.
    private func syntheticTodayGame(from log: GameLogEntry?) -> TodayGame? {
        guard let log else { return nil }
        guard Calendar.current.isDateInToday(gameLogDate(from: log.dateText)) else { return nil }

        let isHome = log.opponentText.hasPrefix("vs")
        let opponent = log.opponentText
            .replacingOccurrences(of: "vs ", with: "")
            .replacingOccurrences(of: "@ ", with: "")

        return TodayGame(
            state: .final,
            opponentName: opponent.isEmpty ? "Opponent" : opponent,
            isHome: isHome,
            startTime: nil,
            homeScore: nil,
            awayScore: nil,
            inningText: nil,
            venueName: nil,
            venueCity: nil,
            latitude: nil,
            longitude: nil,
            homeTeamID: nil
        )
    }

    private func loadDashboards(
        players: [PlayerCatalogEntry],
        forceRefresh: Bool,
        options: DashboardFetchOptions = .full,
        persistSnapshots: Bool = true
    ) async -> (dashboards: [PlayerDashboard], servedStale: Bool) {
        var allDashboards: [PlayerDashboard] = []
        allDashboards.reserveCapacity(players.count)
        var loadedNetworkDashboard = false
        var loadedStaleDashboard = false

        // Bounded parallelism: was strictly sequential (~40 players × many HTTP calls).
        await withTaskGroup(of: (PlayerDashboard, DashboardOrigin)?.self) { group in
            // Seed up to maxConcurrent tasks, then refill as each completes.
            let limit = Self.maxConcurrentPlayerFetches
            var inFlight = 0
            var nextIndex = 0

            func addTask() {
                guard nextIndex < players.count else { return }
                let player = players[nextIndex]
                nextIndex += 1
                inFlight += 1
                group.addTask {
                    guard let result = try? await self.fetchDashboardWithOrigin(
                        for: player,
                        forceRefresh: forceRefresh,
                        options: options
                    ) else {
                        return nil
                    }
                    return (result.dashboard, result.origin)
                }
            }

            for _ in 0..<min(limit, players.count) {
                addTask()
            }

            while inFlight > 0 {
                if let result = await group.next() {
                    inFlight -= 1
                    if let result {
                        PlayerRuntimeStore.saveOverride(for: result.0)
                        allDashboards.append(result.0)
                        switch result.1 {
                        case .network, .freshCache:
                            loadedNetworkDashboard = true
                        case .staleFallback:
                            loadedStaleDashboard = true
                        }
                    }
                    addTask()
                } else {
                    break
                }
            }
        }

        if persistSnapshots {
            PlayerRuntimeStore.saveTodaysDawgsSnapshot(from: allDashboards)
        }
        return (allDashboards, loadedStaleDashboard && !loadedNetworkDashboard)
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
        return try JSONDecoder().decode(PlayerStatsResponse.self, from: data)
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
        return try JSONDecoder().decode(GameLogResponse.self, from: data)
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
        return Self.gameLogDateFormatter().date(from: value) ?? .distantPast
    }

    private func storyPublishedDate(for story: Story) -> Date {
        if let rss = Self.storyPublishedDateFormatter().date(from: story.publishedText) {
            return rss
        }
        if let iso = Self.gameLogDateFormatter().date(from: story.publishedText) {
            return iso
        }
        return .distantPast
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

    /// Live games first, then scheduled by first pitch, then finals. Within each group, A–Z.
    private static func sortedTonightScoreboard(from dashboards: [PlayerDashboard]) -> [PlayerDashboard] {
        func stateRank(_ state: TodayGame.State) -> Int {
            switch state {
            case .live: return 0
            case .scheduled: return 1
            case .final: return 2
            }
        }

        return dashboards
            .filter { $0.todayGame != nil }
            .sorted { lhs, rhs in
                let lGame = lhs.todayGame!
                let rGame = rhs.todayGame!
                let lRank = stateRank(lGame.state)
                let rRank = stateRank(rGame.state)
                if lRank != rRank { return lRank < rRank }
                let lTime = lGame.startTime ?? .distantFuture
                let rTime = rGame.startTime ?? .distantFuture
                if lTime != rTime { return lTime < rTime }
                return lhs.catalogEntry.displayName.localizedCaseInsensitiveCompare(rhs.catalogEntry.displayName) == .orderedAscending
            }
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
        Self.gameLogDateFormatter().date(from: value)
    }

    private static func gameLogDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func storyPublishedDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
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
