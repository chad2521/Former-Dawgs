import SwiftUI

struct HomeScreen: View {
    var viewModel: HomeViewModel
    @AppStorage("appearanceMode", store: SharedAppGroup.defaults) private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("favoritePlayerIDs", store: SharedAppGroup.defaults) private var favoritePlayerIDsStorage = ""
    @State private var isShowingPlayerSelector = false
    @State private var comparePlayerAID = PlayerCatalog.fallback.id
    @State private var comparePlayerBID = PlayerCatalog.players.dropFirst().first?.id ?? PlayerCatalog.fallback.id
    let onSelectPlayer: (PlayerCatalogEntry) -> Void
    let onOpenTrivia: () -> Void

    private var favoritePlayerIDs: Set<Int> {
        FavoritePlayerStore.ids(from: favoritePlayerIDsStorage)
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 900
            let usesMultiColumn = geometry.size.width >= 760

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        BrandHeader(isLandscape: false, isWidePortrait: false)

                        dailyTriviaButton

                        PlayerSelectorDropdown(
                            selectedPlayer: nil,
                            favoritePlayerIDs: favoritePlayerIDs,
                            onSelectPlayer: { player in
                                isShowingPlayerSelector = false
                                onSelectPlayer(player)
                            },
                            onToggleFavorite: { id in
                                FavoritePlayerStore.toggle(id, in: &favoritePlayerIDsStorage)
                                CloudSyncStore.syncToCloud()
                            },
                            isExpanded: $isShowingPlayerSelector
                        )

                        if viewModel.isLoading, viewModel.summary == nil {
                            LoadingView()
                        } else if let summary = viewModel.summary {
                            homeContent(summary: summary, usesMultiColumn: usesMultiColumn)
                        } else {
                            EmptyStateView(playerName: "Former Dawgs")
                        }

                        if let error = viewModel.errorMessage {
                            ErrorRetryView(message: error) {
                                Task { await viewModel.refresh() }
                            }
                        }
                    }
                    .frame(maxWidth: isWide ? 980 : .infinity)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Former Dawgs")
                .refreshable { await viewModel.refresh(forceRefresh: true) }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        appearanceModeMenu
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
        }
        .task {
            if viewModel.summary == nil {
                await viewModel.refresh()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.summary != nil)
    }

    @ViewBuilder
    private func homeContent(summary: FormerDawgsHomeSummary, usesMultiColumn: Bool) -> some View {
        if usesMultiColumn {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 18, alignment: .top),
                    GridItem(.flexible(), spacing: 18, alignment: .top)
                ],
                alignment: .leading,
                spacing: 18
            ) {
                HomePlayerCard(title: "Hottest Hitter", systemImage: "flame.fill", dashboard: summary.hottestHitter, action: onSelectPlayer)
                HomePlayerCard(title: "Hottest Pitcher", systemImage: "flame.circle.fill", dashboard: summary.hottestPitcher, action: onSelectPlayer)
                HomeStoryCard(title: "Latest Promotion", systemImage: "arrow.up.circle.fill", highlight: summary.latestPromotion, action: onSelectPlayer)
                HomeStoryCard(title: "Latest Headline", systemImage: "newspaper.fill", highlight: summary.latestHeadline, action: onSelectPlayer)
            }
        } else {
            HomePlayerCard(title: "Hottest Hitter", systemImage: "flame.fill", dashboard: summary.hottestHitter, action: onSelectPlayer)
            HomePlayerCard(title: "Hottest Pitcher", systemImage: "flame.circle.fill", dashboard: summary.hottestPitcher, action: onSelectPlayer)
            HomeStoryCard(title: "Latest Promotion", systemImage: "arrow.up.circle.fill", highlight: summary.latestPromotion, action: onSelectPlayer)
            HomeStoryCard(title: "Latest Headline", systemImage: "newspaper.fill", highlight: summary.latestHeadline, action: onSelectPlayer)
        }

        TodaysActivePlayersSection(dashboards: summary.todaysActivePlayers, action: onSelectPlayer)
        TodaySummarySection(summary: summary.todaySummary, action: onSelectPlayer)
        WeeklyLeadersSection(title: "Weekly Hitter Leaders", entries: summary.weeklyHitterLeaders, action: onSelectPlayer)
        WeeklyLeadersSection(title: "Weekly Pitcher Leaders", entries: summary.weeklyPitcherLeaders, action: onSelectPlayer)
        TransactionTimelineSection(highlights: summary.transactionTimeline, action: onSelectPlayer)

        if !summary.favoritesWatchlist.isEmpty {
            FavoritesWatchlistSection(dashboards: summary.favoritesWatchlist, action: onSelectPlayer)
        }

        ComparePlayersSection(
            comparePlayerAID: $comparePlayerAID,
            comparePlayerBID: $comparePlayerBID,
            dashboards: summary.comparisonOptions
        )
    }

    private var dailyTriviaButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Trivia", systemImage: "questionmark.bubble.fill")
                .font(.headline)

            Button { onOpenTrivia() } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bulldog Daily Trivia")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("A fresh multiple-choice question for Mississippi State baseball fans")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(Color.appText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var appearanceModeMenu: some View {
        Menu {
            Picker("Appearance", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
        } label: {
            let mode = AppearanceMode(rawValue: appearanceMode) ?? .system
            Label(mode.title, systemImage: mode.iconName)
        }
    }
}
