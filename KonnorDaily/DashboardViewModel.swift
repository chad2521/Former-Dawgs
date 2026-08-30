import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class DashboardViewModel {
    var dashboard: PlayerDashboard?
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    /// True when the displayed data came from the offline cache rather than a live fetch.
    var isShowingCachedData = false

    private let service = PlayerService()
    private var refreshSequence = 0

    func refresh(player: PlayerCatalogEntry, forceRefresh: Bool = false) async {
        refreshSequence += 1
        let requestID = refreshSequence

        if dashboard?.catalogEntry.id != player.id {
            dashboard = nil
            lastUpdated = nil
            isShowingCachedData = false

            // Show the last cached copy instantly (if any) while fresh data loads.
            if let cached = await service.cachedDashboard(for: player) {
                guard requestID == refreshSequence else { return }
                dashboard = cached.dashboard
                lastUpdated = cached.timestamp
                isShowingCachedData = true
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.fetchDashboardWithOrigin(for: player, forceRefresh: forceRefresh)
            guard requestID == refreshSequence else { return }

            let loadedDashboard = result.dashboard
            PlayerRuntimeStore.saveOverride(for: loadedDashboard)
            dashboard = loadedDashboard
            isShowingCachedData = result.origin == .staleFallback

            switch result.origin {
            case .network:
                lastUpdated = Date()
            case .freshCache, .staleFallback:
                lastUpdated = await service.cachedDashboard(for: player)?.timestamp ?? Date()
            }

            if DawgLiveActivityManager.shared.activeActivity(for: loadedDashboard.catalogEntry.id) != nil {
                if loadedDashboard.todayGame?.state == .final {
                    DawgLiveActivityManager.shared.end(for: loadedDashboard)
                } else {
                    DawgLiveActivityManager.shared.startOrUpdate(for: loadedDashboard)
                }
            }
        } catch {
            guard requestID == refreshSequence else { return }
            // Keep any cached data already on screen; only block with an error when we have nothing.
            if dashboard == nil {
                errorMessage = error.localizedDescription
            }
        }

        if requestID == refreshSequence {
            isLoading = false
        }
    }
}

@MainActor
@Observable
final class HomeViewModel {
    var summary: FormerDawgsHomeSummary?
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    /// True when the summary was rebuilt entirely from cached data because the network was unavailable.
    var isShowingCachedData = false

    private let service = PlayerService()
    private var refreshSequence = 0

    func refresh(forceRefresh: Bool = false) async {
        refreshSequence += 1
        let requestID = refreshSequence
        errorMessage = nil

        // Stale-while-revalidate: paint last launch's data immediately, then refresh.
        if summary == nil {
            if let cached = await service.cachedHomeSummary(players: PlayerCatalog.players) {
                guard requestID == refreshSequence else { return }
                summary = cached
                isShowingCachedData = true
                lastUpdated = nil
            }
        }

        // Only block the UI spinner when we have nothing on screen yet.
        if summary == nil {
            isLoading = true
        }

        let allPlayers = PlayerCatalog.players
        let firstPlayers = service.firstPaintPlayers()
        Task { await GameDayScheduleService.refreshSharedSnapshots() }

        // First paint: favorites + tonight + MLB, skipping stories/highlights.
        if firstPlayers.count < allPlayers.count {
            let first = await service.fetchHomeSummaryDetailed(
                players: firstPlayers,
                forceRefresh: forceRefresh,
                options: .core,
                includeHomeStories: false,
                persistSnapshots: false
            )
            guard requestID == refreshSequence else { return }
            summary = mergeFirstPaint(first.summary, onto: summary)
            isShowingCachedData = first.isStale
            lastUpdated = Date()
            isLoading = false
            syncLiveActivities(from: first.summary)
        }

        let loaded = await service.fetchHomeSummaryDetailed(
            players: allPlayers,
            forceRefresh: forceRefresh
        )
        guard requestID == refreshSequence else { return }

        summary = loaded.summary
        isShowingCachedData = loaded.isStale
        lastUpdated = Date()
        isLoading = false
        syncLiveActivities(from: loaded.summary)

#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "FormerDawgsTodaysDawgsWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FormerDawgsFavoritePlayerWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FormerDawgsNewsWidget")
#endif
    }

    private func syncLiveActivities(from summary: FormerDawgsHomeSummary) {
        let favoriteIDs = FavoritePlayerStore.ids(
            from: SharedAppGroup.defaults.string(forKey: "favoritePlayerIDs") ?? ""
        )
        var seen = Set<Int>()
        let boards = summary.tonightScoreboard + summary.favoritesWatchlist + summary.comparisonOptions
        for dashboard in boards {
            let id = dashboard.catalogEntry.id
            guard seen.insert(id).inserted else { continue }
            DawgLiveActivityManager.shared.syncFollowedGame(
                dashboard,
                isFollowed: favoriteIDs.contains(id)
            )
        }
    }

    /// Keep cached hottest/headlines/leaders on screen while the first paint only has tonight + favorites.
    private func mergeFirstPaint(
        _ incoming: FormerDawgsHomeSummary,
        onto existing: FormerDawgsHomeSummary?
    ) -> FormerDawgsHomeSummary {
        guard let existing else { return incoming }
        return FormerDawgsHomeSummary(
            hottestHitter: incoming.hottestHitter ?? existing.hottestHitter,
            hottestPitcher: incoming.hottestPitcher ?? existing.hottestPitcher,
            latestPromotion: incoming.latestPromotion ?? existing.latestPromotion,
            latestHeadline: incoming.latestHeadline ?? existing.latestHeadline,
            weeklyHitterLeaders: incoming.weeklyHitterLeaders.isEmpty ? existing.weeklyHitterLeaders : incoming.weeklyHitterLeaders,
            weeklyPitcherLeaders: incoming.weeklyPitcherLeaders.isEmpty ? existing.weeklyPitcherLeaders : incoming.weeklyPitcherLeaders,
            transactionTimeline: incoming.transactionTimeline.isEmpty ? existing.transactionTimeline : incoming.transactionTimeline,
            favoritesWatchlist: incoming.favoritesWatchlist.isEmpty ? existing.favoritesWatchlist : incoming.favoritesWatchlist,
            comparisonOptions: incoming.comparisonOptions.isEmpty ? existing.comparisonOptions : incoming.comparisonOptions,
            todaySummary: incoming.todaySummary.activePlayers.isEmpty ? existing.todaySummary : incoming.todaySummary,
            todaysActivePlayers: incoming.todaysActivePlayers.isEmpty ? existing.todaysActivePlayers : incoming.todaysActivePlayers,
            tonightScoreboard: incoming.tonightScoreboard.isEmpty ? existing.tonightScoreboard : incoming.tonightScoreboard
        )
    }
}
