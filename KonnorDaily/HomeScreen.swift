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
    var onOpenTonightMap: () -> Void = {}

    private var favoritePlayerIDs: Set<Int> {
        FavoritePlayerStore.ids(from: favoritePlayerIDsStorage)
    }

    private var liveCount: Int {
        viewModel.summary?.tonightScoreboard.filter { $0.todayGame?.state == .live }.count ?? 0
    }

    private var activeTodayCount: Int {
        viewModel.summary?.todaysActivePlayers.count
            ?? viewModel.summary?.tonightScoreboard.count
            ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 900
            let usesMultiColumn = geometry.size.width >= 760
            let heroHeight = min(max(geometry.size.height * 0.52, 380), 560)

            NavigationStack {
                ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Cinematic Dudy Noble flyover landing
                            StadiumFlyoverHero(
                                height: heroHeight,
                                tonightLiveCount: liveCount,
                                activeTodayCount: activeTodayCount
                            )

                            VStack(alignment: .leading, spacing: 22) {
                                landingIntroStrip

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

                                if viewModel.isShowingCachedData, viewModel.summary != nil {
                                    Label("Offline — showing saved data", systemImage: "wifi.slash")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                }

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
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .background(Color(.systemGroupedBackground))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
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
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
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

    /// Quick emotional beats under the flyover — pure MSU fan energy, not share cards.
    private var landingIntroStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("From the left-field lounge to The Show")
                .font(.title3.weight(.bold))
            Text("Track every former Bulldog in pro ball — box scores, call-ups, and the nights that start at Dudy Noble.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                Button(action: onOpenTonightMap) {
                    landingStatTile(
                        title: "Tonight",
                        value: "\(viewModel.summary?.tonightScoreboard.count ?? 0)",
                        detail: liveCount > 0 ? "\(liveCount) live now · open map" : "tap for ballpark map",
                        systemImage: "sportscourt.fill",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the map of former Dawgs playing tonight")

                landingStatTile(
                    title: "Active today",
                    value: "\(activeTodayCount)",
                    detail: "box scores rolling in",
                    systemImage: "flame.fill"
                )
            }
        }
        .padding(.top, 4)
    }

    private func landingStatTile(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        showsChevron: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.msMaroonText)
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.msMaroonText.opacity(0.7))
                }
            }
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

        let recentDraftees = DynamicDrafteeStore.recentDraftees()
        if !recentDraftees.isEmpty {
            FreshDrafteesSection(draftees: recentDraftees, action: onSelectPlayer)
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
            Image(systemName: mode.iconName)
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
    }
}
