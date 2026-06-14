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

    private let service = PlayerService()
    private var refreshSequence = 0

    func refresh(player: PlayerCatalogEntry, forceRefresh: Bool = false) async {
        refreshSequence += 1
        let requestID = refreshSequence

        if dashboard?.catalogEntry.id != player.id {
            dashboard = nil
            lastUpdated = nil
        }

        isLoading = true
        errorMessage = nil

        do {
            let loadedDashboard = try await service.fetchDashboard(for: player, forceRefresh: forceRefresh)
            guard requestID == refreshSequence else { return }

            PlayerRuntimeStore.saveOverride(for: loadedDashboard)
            dashboard = loadedDashboard
            lastUpdated = Date()
            if DawgLiveActivityManager.shared.activeActivity(for: loadedDashboard.catalogEntry.id) != nil {
                if loadedDashboard.todayGame?.state == .final {
                    DawgLiveActivityManager.shared.end(for: loadedDashboard)
                } else {
                    DawgLiveActivityManager.shared.startOrUpdate(for: loadedDashboard)
                }
            }
        } catch {
            guard requestID == refreshSequence else { return }
            errorMessage = error.localizedDescription
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

    private let service = PlayerService()

    func refresh(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        let loadedSummary = await service.fetchHomeSummary(players: PlayerCatalog.players, forceRefresh: forceRefresh)
        summary = loadedSummary
        lastUpdated = Date()
        isLoading = false
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "KonnorDailyTodaysDawgsWidget")
#endif
    }
}
