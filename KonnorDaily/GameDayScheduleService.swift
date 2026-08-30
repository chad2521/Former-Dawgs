import Foundation

/// Shared MLB/MiLB game-day refresh used by widgets, Watch, Live Activities, and Home.
/// Hits statsapi.mlb.com directly (no Google News) and writes App Group snapshots so
/// complication/widget/Watch surfaces can show opponent/score/status without opening iPhone.
enum GameDayScheduleService {
    private static let lastRefreshKey = "gameDayScheduleLastRefreshAt"
    private static let minimumRefreshInterval: TimeInterval = 90

    /// Favorites + anyone already marked as playing today + MLB catalog (logo-code match).
    static func refreshSharedSnapshots(force: Bool = false) async {
        if !force,
           let last = SharedAppGroup.defaults.object(forKey: lastRefreshKey) as? Date,
           Date().timeIntervalSince(last) < minimumRefreshInterval {
            return
        }

        let today = dateString(from: Date())
        let gamesByTeam = await fetchGamesByTeamID(date: today)
        guard !gamesByTeam.isEmpty || force else { return }

        let favoriteIDs = FavoritePlayerStore.ids(
            from: SharedAppGroup.defaults.string(forKey: "favoritePlayerIDs") ?? ""
        )
        let knownToday = PlayerRuntimeStore.playersWithGameToday()
        let catalog = PlayerCatalog.players

        var resolvedTeams: [Int: ResolvedTeam] = [:]
        for player in catalog {
            if let resolved = resolveTeam(for: player) {
                resolvedTeams[player.id] = resolved
            }
        }

        let needsPeople = catalog.filter { player in
            resolvedTeams[player.id] == nil
                && (favoriteIDs.contains(player.id) || knownToday.contains(player.id))
        }
        if !needsPeople.isEmpty {
            await withTaskGroup(of: (Int, ResolvedTeam)?.self) { group in
                for player in needsPeople.prefix(12) {
                    group.addTask {
                        guard let team = await fetchCurrentTeam(playerID: player.id) else { return nil }
                        return (player.id, team)
                    }
                }
                for await item in group {
                    if let item {
                        resolvedTeams[item.0] = item.1
                    }
                }
            }
        }

        var snapshotPlayers: [TodaysDawgSnapshotPlayer] = []
        snapshotPlayers.reserveCapacity(8)
        var playingIDs = Set<Int>()

        for player in catalog {
            guard let team = resolvedTeams[player.id],
                  let game = gamesByTeam[team.teamID] else {
                continue
            }
            playingIDs.insert(player.id)
            snapshotPlayers.append(
                TodaysDawgSnapshotPlayer(
                    id: player.id,
                    name: player.displayName,
                    role: player.role,
                    teamName: team.teamName,
                    gameHeadline: game.headline,
                    statusText: game.statusText,
                    isLive: game.state == .live
                )
            )
        }

        snapshotPlayers.sort { lhs, rhs in
            if lhs.isLive != rhs.isLive { return lhs.isLive && !rhs.isLive }
            let lFav = favoriteIDs.contains(lhs.id)
            let rFav = favoriteIDs.contains(rhs.id)
            if lFav != rFav { return lFav && !rFav }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        PlayerRuntimeStore.saveTodaysDawgsSnapshot(players: snapshotPlayers)
        PlayerRuntimeStore.markPlayersWithGameToday(playingIDs)
        PlayerRuntimeStore.overlayFavoriteSnapshot(from: snapshotPlayers)
        CloudSyncStore.pushTodaysDawgsSnapshot()
        SharedAppGroup.defaults.set(Date(), forKey: lastRefreshKey)
    }

    private struct ResolvedTeam {
        let teamID: Int
        let teamName: String
    }

    private static func resolveTeam(for player: PlayerCatalogEntry) -> ResolvedTeam? {
        if let cached = OfflineCache.load(PlayerDashboard.self, forKey: "dashboard-\(player.id)") {
            if let team = cached.value.profile.currentTeam {
                return ResolvedTeam(teamID: team.id, teamName: team.name)
            }
            if let team = cached.value.seasonStat?.team {
                return ResolvedTeam(teamID: team.id, teamName: team.name)
            }
        }

        if !player.effectiveIsMinorLeaguerPublic,
           let code = PlayerRuntimeStore.teamLogoCode(for: player.id) ?? player.teamLogoCode,
           let teamID = TeamLogoCatalog.teamID(for: code) {
            return ResolvedTeam(teamID: teamID, teamName: TeamLogoCatalog.franchiseName(for: code))
        }
        return nil
    }

    private static func fetchCurrentTeam(playerID: Int) async -> ResolvedTeam? {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/people/\(playerID)")!
        components.queryItems = [URLQueryItem(name: "hydrate", value: "currentTeam")]
        guard let url = components.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let profile = try JSONDecoder().decode(PlayerProfile.self, from: data)
            guard let team = profile.people.first?.currentTeam else { return nil }
            return ResolvedTeam(teamID: team.id, teamName: team.name)
        } catch {
            return nil
        }
    }

    private static func fetchGamesByTeamID(date: String) async -> [Int: TodayGame] {
        let sportIDs = [1, 11, 12, 13, 14, 16]
        var result: [Int: TodayGame] = [:]
        await withTaskGroup(of: [Int: TodayGame].self) { group in
            for sportID in sportIDs {
                group.addTask {
                    (try? await fetchSchedule(sportID: sportID, date: date)) ?? [:]
                }
            }
            for await batch in group {
                for (teamID, game) in batch {
                    if let existing = result[teamID], existing.state == .live {
                        continue
                    }
                    result[teamID] = game
                }
            }
        }
        return result
    }

    private static func fetchSchedule(sportID: Int, date: String) async throws -> [Int: TodayGame] {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/schedule")!
        components.queryItems = [
            URLQueryItem(name: "sportId", value: String(sportID)),
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "hydrate", value: "linescore,venue")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(ScheduleResponse.self, from: data)
        var result: [Int: TodayGame] = [:]
        for dateBlock in response.dates {
            for game in dateBlock.games {
                let homeID = game.teams.home.team.id
                let awayID = game.teams.away.team.id
                if let homeGame = TodayGame.from(scheduleGame: game, teamID: homeID) {
                    result[homeID] = homeGame
                }
                if let awayGame = TodayGame.from(scheduleGame: game, teamID: awayID) {
                    result[awayID] = awayGame
                }
            }
        }
        return result
    }

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
