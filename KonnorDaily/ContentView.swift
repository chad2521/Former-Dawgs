import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode", store: SharedAppGroup.defaults) private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("selectedPlayerID", store: SharedAppGroup.defaults) private var selectedPlayerID = PlayerCatalog.fallback.id
    @State private var viewModel = DashboardViewModel()
    @State private var homeViewModel = HomeViewModel()
    @State private var selectedTab = AppTab.home
    @State private var isShowingPlayerDetail = false
    @State private var router = IntentRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen(
                viewModel: homeViewModel,
                onSelectPlayer: navigateToPlayer,
                onOpenTrivia: { selectedTab = .trivia },
                onOpenTonightMap: {
                    IntentRouter.shared.requestTonightMap()
                }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            TonightScreen(
                viewModel: homeViewModel,
                onSelectPlayer: navigateToPlayer
            )
            .tabItem { Label("Tonight", systemImage: "sportscourt.fill") }
            .tag(AppTab.tonight)

            Group {
                if isShowingPlayerDetail {
                    PlayerScreen(viewModel: viewModel) {
                        isShowingPlayerDetail = false
                    }
                } else {
                    BrowseScreen(
                        dashboards: homeViewModel.summary?.comparisonOptions ?? [],
                        onSelectPlayer: navigateToPlayer
                    )
                }
            }
                .tabItem { Label("Players", systemImage: "person.3.fill") }
                .tag(AppTab.browse)

            CowbellScreen()
                .tabItem { Label("Cowbell", systemImage: "bell.fill") }
                .tag(AppTab.cowbell)

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
        selectedTab = .browse
        isShowingPlayerDetail = true
    }

    private func applyIntentRequest() {
        let request = router.consume()
        if let playerID = request.playerID {
            selectedPlayerID = playerID
            selectedTab = .browse
            isShowingPlayerDetail = true
        }
        if let tab = request.tab {
            if tab == .player {
                selectedTab = .browse
                isShowingPlayerDetail = true
            } else {
                selectedTab = tab
            }
        }
        // Tonight map flag is consumed by TonightScreen; re-set if we consumed it here
        // only when routing from Siri/deep link through the same path.
        if request.openTonightMap {
            IntentRouter.shared.pendingTonightMap = true
        }
    }
}

enum AppTab {
    case home, tonight, browse, player, cowbell, trivia
}

#Preview {
    ContentView()
}
