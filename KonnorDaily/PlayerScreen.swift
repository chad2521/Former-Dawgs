import SwiftUI

struct PlayerScreen: View {
    var viewModel: DashboardViewModel
    @AppStorage("selectedPlayerID", store: SharedAppGroup.defaults) private var selectedPlayerID = PlayerCatalog.fallback.id
    @AppStorage("favoritePlayerIDs", store: SharedAppGroup.defaults) private var favoritePlayerIDsStorage = ""
    @State private var isShowingPlayerSelector = false

    private var selectedPlayer: PlayerCatalogEntry {
        PlayerCatalog.player(for: selectedPlayerID)
    }

    private var favoritePlayerIDs: Set<Int> {
        FavoritePlayerStore.ids(from: favoritePlayerIDsStorage)
    }

    private var favoritePlayers: [PlayerCatalogEntry] {
        PlayerCatalog.players.filter { favoritePlayerIDs.contains($0.id) }
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isWide = geometry.size.width >= 900
            let isWidePortrait = !isLandscape && geometry.size.width >= 700
            let usesMultiColumn = geometry.size.width >= 760

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: isLandscape ? 18 : 22) {
                        topSection(isLandscape: isLandscape, isWidePortrait: isWidePortrait)
                        dashboardContent(usesMultiColumn: usesMultiColumn)
                    }
                    .frame(maxWidth: isWide ? 980 : .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .padding(isWidePortrait ? 24 : (isLandscape ? 16 : 20))
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Former Dawgs")
                .refreshable {
                    await viewModel.refresh(player: selectedPlayer, forceRefresh: true)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await viewModel.refresh(player: selectedPlayer) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
        }
        .task(id: selectedPlayerID) {
            if viewModel.dashboard?.catalogEntry.id != selectedPlayerID {
                await viewModel.refresh(player: selectedPlayer)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.dashboard?.catalogEntry.id)
    }

    @ViewBuilder
    private func topSection(isLandscape: Bool, isWidePortrait: Bool) -> some View {
        if isLandscape || isWidePortrait {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    BrandHeader(isLandscape: true, isWidePortrait: isWidePortrait)
                    playerSelector
                }
                .frame(maxWidth: isWidePortrait ? 340 : 320)

                playerHeader(isLandscape: true, isWidePortrait: isWidePortrait)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 22) {
                BrandHeader(isLandscape: false, isWidePortrait: false)
                playerSelector
                playerHeader(isLandscape: false, isWidePortrait: false)
            }
        }
    }

    private var playerSelector: some View {
        PlayerSelectorDropdown(
            selectedPlayer: selectedPlayer,
            favoritePlayerIDs: favoritePlayerIDs,
            onSelectPlayer: selectPlayer,
            onToggleFavorite: { id in
                FavoritePlayerStore.toggle(id, in: &favoritePlayerIDsStorage)
                CloudSyncStore.syncToCloud()
            },
            isExpanded: $isShowingPlayerSelector
        )
    }

    @ViewBuilder
    private func dashboardContent(usesMultiColumn: Bool) -> some View {
        if let dashboard = viewModel.dashboard {
            if let todayGame = dashboard.todayGame {
                TodayGameBanner(
                    game: todayGame,
                    isTracking: DawgLiveActivityManager.shared.activeActivity(for: dashboard.catalogEntry.id) != nil,
                    onTrack: { DawgLiveActivityManager.shared.startOrUpdate(for: dashboard) }
                )
            }

            if dashboard.catalogEntry.isMinorLeaguer {
                MinorLeagueBanner(dashboard: dashboard)
            }

            if !favoritePlayers.isEmpty {
                FavoritesStrip(players: favoritePlayers, selectedPlayerID: $selectedPlayerID, activeTodayIDs: PlayerRuntimeStore.playersWithGameToday())
            }

            if usesMultiColumn {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 18, alignment: .top),
                        GridItem(.flexible(), spacing: 18, alignment: .top)
                    ],
                    alignment: .leading,
                    spacing: 18
                ) {
                    StatsSection(dashboard: dashboard)
                    CareerTimelineSection(dashboard: dashboard)
                    RecentGameLogsSection(dashboard: dashboard)
                    HighlightsSection(player: dashboard.catalogEntry, videos: dashboard.videos)
                    StoriesSection(stories: dashboard.stories)
                }
            } else {
                StatsSection(dashboard: dashboard)
                CareerTimelineSection(dashboard: dashboard)
                RecentGameLogsSection(dashboard: dashboard)
                HighlightsSection(player: dashboard.catalogEntry, videos: dashboard.videos)
                StoriesSection(stories: dashboard.stories)
            }
        } else if viewModel.isLoading {
            if !favoritePlayers.isEmpty {
                FavoritesStrip(players: favoritePlayers, selectedPlayerID: $selectedPlayerID, activeTodayIDs: PlayerRuntimeStore.playersWithGameToday())
            }
            LoadingView()
        } else {
            if !favoritePlayers.isEmpty {
                FavoritesStrip(players: favoritePlayers, selectedPlayerID: $selectedPlayerID, activeTodayIDs: PlayerRuntimeStore.playersWithGameToday())
            }
            EmptyStateView(playerName: selectedPlayer.displayName)
        }

        if let error = viewModel.errorMessage {
            ErrorRetryView(message: error) {
                Task { await viewModel.refresh(player: selectedPlayer) }
            }
        }
    }

    private func playerHeader(isLandscape: Bool, isWidePortrait: Bool) -> some View {
        let headshotSize: CGFloat = isWidePortrait ? 96 : (isLandscape ? 84 : 92)

        return HStack(alignment: .top, spacing: 16) {
            PlayerHeadshotImage(
                url: selectedPlayer.headshotURL,
                initials: selectedPlayer.initials,
                accessibilityLabel: "\(selectedPlayer.displayName) headshot",
                size: headshotSize
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.dashboard?.name ?? selectedPlayer.displayName)
                    .font(.system(size: isWidePortrait ? 32 : (isLandscape ? 30 : 34), weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.75)
                Text(viewModel.dashboard?.teamLine ?? selectedPlayer.role)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                Text(viewModel.dashboard?.msuLine ?? selectedPlayer.fallbackLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))

                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer(minLength: 0)

            if let teamLogoURL = selectedPlayer.teamLogoURL {
                RemoteLogoImage(
                    url: teamLogoURL,
                    accessibilityLabel: "\(selectedPlayer.displayName) team logo",
                    height: 64
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isWidePortrait ? 20 : (isLandscape ? 18 : 22))
        .background(
            LinearGradient(
                colors: [Color.msMaroon, Color(red: 0.07, green: 0.07, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func selectPlayer(_ player: PlayerCatalogEntry) {
        selectedPlayerID = player.id
        isShowingPlayerSelector = false
    }
}
