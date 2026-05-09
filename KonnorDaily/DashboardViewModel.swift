import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var dashboard: PlayerDashboard?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let service = PlayerService()
    private var refreshSequence = 0

    func refresh(player: PlayerCatalogEntry) async {
        refreshSequence += 1
        let requestID = refreshSequence

        if dashboard?.catalogEntry.id != player.id {
            dashboard = nil
            lastUpdated = nil
        }

        isLoading = true
        errorMessage = nil

        do {
            let loadedDashboard = try await service.fetchDashboard(for: player)
            guard requestID == refreshSequence else { return }

            PlayerRuntimeStore.saveOverride(for: loadedDashboard)
            dashboard = loadedDashboard
            lastUpdated = Date()
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
final class HomeViewModel: ObservableObject {
    @Published var summary: FormerDawgsHomeSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let service = PlayerService()

    func refresh() async {
        isLoading = true
        errorMessage = nil

        let loadedSummary = await service.fetchHomeSummary(players: PlayerCatalog.players)
        summary = loadedSummary
        lastUpdated = Date()
        isLoading = false
    }
}
