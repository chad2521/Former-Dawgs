import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode", store: SharedAppGroup.defaults) private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("selectedPlayerID", store: SharedAppGroup.defaults) private var selectedPlayerID = PlayerCatalog.fallback.id
    @State private var viewModel = DashboardViewModel()
    @State private var homeViewModel = HomeViewModel()
    @State private var selectedTab = AppTab.home
    @State private var router = IntentRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen(
                viewModel: homeViewModel,
                onSelectPlayer: navigateToPlayer,
                onOpenTrivia: { selectedTab = .trivia }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            PlayerScreen(viewModel: viewModel)
                .tabItem { Label("Player", systemImage: "person.fill") }
                .tag(AppTab.player)

            TriviaScreen()
                .tabItem { Label("Trivia", systemImage: "questionmark.bubble.fill") }
                .tag(AppTab.trivia)
        }
        .tint(Color.msMaroon)
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        .onChange(of: router.pendingTab) { _, _ in applyIntentRequest() }
        .onChange(of: router.pendingPlayerID) { _, _ in applyIntentRequest() }
        .task { applyIntentRequest() }
    }

    private func navigateToPlayer(_ player: PlayerCatalogEntry) {
        selectedPlayerID = player.id
        selectedTab = .player
    }

    private func applyIntentRequest() {
        let request = router.consume()
        if let playerID = request.playerID {
            selectedPlayerID = playerID
        }
        if let tab = request.tab {
            selectedTab = tab
        }
    }
}

enum AppTab {
    case home, player, trivia
}

#Preview {
    ContentView()
}
