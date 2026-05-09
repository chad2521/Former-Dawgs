import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedPlayerID") private var selectedPlayerID = PlayerCatalog.fallback.id
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("favoritePlayerIDs") private var favoritePlayerIDsStorage = ""
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var isShowingPlayerSelector = false
    @State private var playerSearchText = ""
    @State private var playerSortOption = PlayerSortOption.name
    @State private var currentScreen = AppScreen.home

    private var selectedPlayer: PlayerCatalogEntry {
        PlayerCatalog.player(for: selectedPlayerID)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            phoneBody
        }
        .onAppear {
            isShowingPlayerSelector = false
        }
        .task(id: currentScreen) {
            if currentScreen == .home {
                if homeViewModel.summary == nil {
                    await homeViewModel.refresh()
                }
            } else if viewModel.dashboard?.catalogEntry.id != selectedPlayerID {
                await viewModel.refresh(player: selectedPlayer)
            }
        }
        .task(id: selectedPlayerID) {
            guard currentScreen == .player else { return }
            await viewModel.refresh(player: selectedPlayer)
        }
    }

    private var phoneBody: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isWide = geometry.size.width >= 900
            let isWidePortrait = !isLandscape && geometry.size.width >= 700
            let usesMultiColumnSections = geometry.size.width >= 760

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: isLandscape ? 18 : 22) {
                        if currentScreen == .home {
                            homeSections(usesMultiColumnSections: usesMultiColumnSections)
                        } else {
                            topSection(isLandscape: isLandscape, isWidePortrait: isWidePortrait)
                            dashboardSections(usesMultiColumnSections: usesMultiColumnSections)
                        }
                    }
                    .frame(maxWidth: isWide ? 980 : .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .padding(isWidePortrait ? 24 : (isLandscape ? 16 : 20))
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Former Dawgs")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }

    private var currentAppearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    private var currentAppearanceTitle: String {
        currentAppearanceMode.title
    }

    private var currentAppearanceIcon: String {
        currentAppearanceMode.iconName
    }

    private var favoritePlayerIDs: Set<Int> {
        Set(
            favoritePlayerIDsStorage
                .split(separator: ",")
                .compactMap { Int($0) }
        )
    }

    private var favoritePlayers: [PlayerCatalogEntry] {
        PlayerCatalog.players.filter { favoritePlayerIDs.contains($0.id) }
    }

    private var filteredPlayers: [PlayerCatalogEntry] {
        let matchingPlayers: [PlayerCatalogEntry]
        if playerSearchText.isEmpty {
            matchingPlayers = PlayerCatalog.players
        } else {
            matchingPlayers = PlayerCatalog.players.filter {
                $0.displayName.localizedCaseInsensitiveContains(playerSearchText) ||
                $0.role.localizedCaseInsensitiveContains(playerSearchText) ||
                $0.levelLabel.localizedCaseInsensitiveContains(playerSearchText) ||
                $0.msuYears.localizedCaseInsensitiveContains(playerSearchText)
            }
        }

        return matchingPlayers.sorted(by: playerSortOption.sortComparator)
    }

    private var filteredFavoritePlayers: [PlayerCatalogEntry] {
        filteredPlayers.filter { favoritePlayerIDs.contains($0.id) }
    }

    private var filteredNonFavoritePlayers: [PlayerCatalogEntry] {
        filteredPlayers.filter { !favoritePlayerIDs.contains($0.id) }
    }

    @ToolbarContentBuilder
    private var commonToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            } label: {
                Label(currentAppearanceTitle, systemImage: currentAppearanceIcon)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task {
                    if currentScreen == .home {
                        await homeViewModel.refresh()
                    } else {
                        await viewModel.refresh(player: selectedPlayer)
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(currentScreen == .home ? homeViewModel.isLoading : viewModel.isLoading)
        }

        ToolbarItem(placement: .topBarTrailing) {
            if currentScreen == .player {
                Button {
                    currentScreen = .home
                } label: {
                    Image(systemName: "house.fill")
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardSections(usesMultiColumnSections: Bool) -> some View {
        if let dashboard = viewModel.dashboard {
            if dashboard.catalogEntry.isMinorLeaguer {
                MinorLeagueBanner(dashboard: dashboard)
            }

            if !favoritePlayers.isEmpty {
                FavoritesStrip(
                    players: favoritePlayers,
                    selectedPlayerID: $selectedPlayerID
                )
            }

            if usesMultiColumnSections {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 18, alignment: .top),
                        GridItem(.flexible(), spacing: 18, alignment: .top)
                    ],
                    alignment: .leading,
                    spacing: 18
                ) {
                    StatsSection(dashboard: dashboard)
                    RecentGameLogsSection(gameLogs: dashboard.gameLogs)
                    HighlightsSection(player: dashboard.catalogEntry, videos: dashboard.videos)
                    StoriesSection(stories: dashboard.stories)
                }
            } else {
                StatsSection(dashboard: dashboard)
                RecentGameLogsSection(gameLogs: dashboard.gameLogs)
                HighlightsSection(player: dashboard.catalogEntry, videos: dashboard.videos)
                StoriesSection(stories: dashboard.stories)
            }
        } else if viewModel.isLoading {
            if !favoritePlayers.isEmpty {
                FavoritesStrip(
                    players: favoritePlayers,
                    selectedPlayerID: $selectedPlayerID
                )
            }
            LoadingView()
        } else {
            if !favoritePlayers.isEmpty {
                FavoritesStrip(
                    players: favoritePlayers,
                    selectedPlayerID: $selectedPlayerID
                )
            }
            EmptyStateView(playerName: selectedPlayer.displayName)
        }

        if let error = viewModel.errorMessage {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func homeSections(usesMultiColumnSections: Bool) -> some View {
        brandHeader(isLandscape: false, isWidePortrait: false)

        homeBrowseButton

        if homeViewModel.isLoading, homeViewModel.summary == nil {
            LoadingView()
        } else if let summary = homeViewModel.summary {
            if usesMultiColumnSections {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 18, alignment: .top),
                        GridItem(.flexible(), spacing: 18, alignment: .top)
                    ],
                    alignment: .leading,
                    spacing: 18
                ) {
                    HomePlayerCard(
                        title: "Hottest Hitter",
                        systemImage: "flame.fill",
                        dashboard: summary.hottestHitter,
                        action: showPlayer
                    )
                    HomePlayerCard(
                        title: "Hottest Pitcher",
                        systemImage: "flame.circle.fill",
                        dashboard: summary.hottestPitcher,
                        action: showPlayer
                    )
                    HomeStoryCard(
                        title: "Latest Promotion",
                        systemImage: "arrow.up.circle.fill",
                        highlight: summary.latestPromotion,
                        action: showPlayer
                    )
                    HomeStoryCard(
                        title: "Latest Headline",
                        systemImage: "newspaper.fill",
                        highlight: summary.latestHeadline,
                        action: showPlayer
                    )
                }
            } else {
                HomePlayerCard(
                    title: "Hottest Hitter",
                    systemImage: "flame.fill",
                    dashboard: summary.hottestHitter,
                    action: showPlayer
                )
                HomePlayerCard(
                    title: "Hottest Pitcher",
                    systemImage: "flame.circle.fill",
                    dashboard: summary.hottestPitcher,
                    action: showPlayer
                )
                HomeStoryCard(
                    title: "Latest Promotion",
                    systemImage: "arrow.up.circle.fill",
                    highlight: summary.latestPromotion,
                    action: showPlayer
                )
                HomeStoryCard(
                    title: "Latest Headline",
                    systemImage: "newspaper.fill",
                    highlight: summary.latestHeadline,
                    action: showPlayer
                )
            }

            TodaysActivePlayersSection(
                dashboards: summary.todaysActivePlayers,
                action: showPlayer
            )
        } else {
            EmptyStateView(playerName: "Former Dawgs")
        }

        if let error = homeViewModel.errorMessage {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func topSection(isLandscape: Bool, isWidePortrait: Bool) -> some View {
        if isLandscape || isWidePortrait {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    brandHeader(isLandscape: true, isWidePortrait: isWidePortrait)
                    playerPicker
                }
                .frame(maxWidth: isWidePortrait ? 340 : 320)

                header(isLandscape: true, isWidePortrait: isWidePortrait)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 22) {
                brandHeader(isLandscape: false, isWidePortrait: false)
                playerPicker
                header(isLandscape: false, isWidePortrait: false)
            }
        }
    }

    private func brandHeader(isLandscape: Bool, isWidePortrait: Bool) -> some View {
        HStack {
            Spacer()
            HeaderLogoView(
                url: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Mississippi_State_Bulldogs_script_logo.svg/960px-Mississippi_State_Bulldogs_script_logo.svg.png"),
                height: isWidePortrait ? 96 : (isLandscape ? 88 : 124)
            )
            Spacer()
        }
        .padding(.vertical, isWidePortrait ? 10 : (isLandscape ? 8 : 12))
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.44, green: 0.04, blue: 0.12).opacity(0.12),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var playerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Players", systemImage: "baseball.fill")
                .font(.headline)

                Button {
                    isShowingPlayerSelector = true
                } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPlayer.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(selectedPlayer.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if favoritePlayerIDs.contains(selectedPlayer.id) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }

                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if isShowingPlayerSelector {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Search players", text: $playerSearchText)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Label("Sort", systemImage: playerSortOption.iconName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Picker("Sort players", selection: $playerSortOption) {
                            ForEach(PlayerSortOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if !filteredFavoritePlayers.isEmpty {
                        playerListSection(title: "Favorites", players: filteredFavoritePlayers)
                    }

                    playerListSection(title: "All Players", players: filteredNonFavoritePlayers)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var homeBrowseButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Players", systemImage: "baseball.fill")
                .font(.headline)

            Button {
                isShowingPlayerSelector = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browse Players")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Search, sort, and open any Former Dawgs profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if isShowingPlayerSelector {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Search players", text: $playerSearchText)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Label("Sort", systemImage: playerSortOption.iconName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Picker("Sort players", selection: $playerSortOption) {
                            ForEach(PlayerSortOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if !filteredFavoritePlayers.isEmpty {
                        playerListSection(title: "Favorites", players: filteredFavoritePlayers)
                    }

                    playerListSection(title: "All Players", players: filteredNonFavoritePlayers)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func playerListSection(title: String, players: [PlayerCatalogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                if let levelHeader = levelHeader(before: index, in: players) {
                    if index > 0 {
                        levelSectionBreak
                    }

                    Text(levelHeader)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(sectionHeaderColor)
                        .padding(.top, index == 0 ? 0 : 6)
                }

                if let yearHeader = stateYearHeader(before: index, in: players) {
                    Text(yearHeader)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(sectionHeaderColor)
                        .padding(.top, index == 0 ? 0 : 6)
                }

                playerRow(player)
            }
        }
    }

    private func playerRow(_ player: PlayerCatalogEntry) -> some View {
        Button {
            showPlayer(player)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(player.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(player.levelLabel) • State \(player.msuYears)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    toggleFavorite(player.id)
                } label: {
                    Image(systemName: favoritePlayerIDs.contains(player.id) ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)

                if player.id == selectedPlayerID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.44, green: 0.04, blue: 0.12))
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func levelHeader(before index: Int, in players: [PlayerCatalogEntry]) -> String? {
        guard playerSortOption == .level else {
            return nil
        }

        let currentLabel = players[index].levelLabel
        if index == 0 {
            return currentLabel
        }

        return players[index - 1].levelLabel == currentLabel ? nil : currentLabel
    }

    private func stateYearHeader(before index: Int, in players: [PlayerCatalogEntry]) -> String? {
        guard playerSortOption == .stateYear else {
            return nil
        }

        let currentLabel = players[index].stateYearLabel
        if index == 0 {
            return currentLabel
        }

        return players[index - 1].stateYearLabel == currentLabel ? nil : currentLabel
    }

    private var sectionHeaderColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.44, green: 0.04, blue: 0.12)
    }

    private var levelSectionBreak: some View {
        Rectangle()
            .fill(Color(red: 0.44, green: 0.04, blue: 0.12).opacity(colorScheme == .dark ? 0.55 : 0.75))
            .frame(height: 2)
            .clipShape(Capsule())
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private func showPlayer(_ player: PlayerCatalogEntry) {
        selectedPlayerID = player.id
        isShowingPlayerSelector = false
        playerSearchText = ""
        currentScreen = .player
    }

    private func toggleFavorite(_ playerID: Int) {
        var updatedFavorites = favoritePlayerIDs
        if updatedFavorites.contains(playerID) {
            updatedFavorites.remove(playerID)
        } else {
            updatedFavorites.insert(playerID)
        }
        favoritePlayerIDsStorage = updatedFavorites.sorted().map(String.init).joined(separator: ",")
    }

    private func header(isLandscape: Bool, isWidePortrait: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
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
                colors: [Color(red: 0.44, green: 0.04, blue: 0.12), Color(red: 0.07, green: 0.07, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum PlayerSortOption: String, CaseIterable, Identifiable {
    case name
    case level
    case stateYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            return "A-Z"
        case .level:
            return "Level"
        case .stateYear:
            return "State Year"
        }
    }

    var iconName: String {
        switch self {
        case .name:
            return "textformat.abc"
        case .level:
            return "line.3.horizontal.decrease.circle"
        case .stateYear:
            return "calendar"
        }
    }

    var sortComparator: (PlayerCatalogEntry, PlayerCatalogEntry) -> Bool {
        switch self {
        case .name:
            return { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        case .level:
            return { lhs, rhs in
                if lhs.levelSortRank != rhs.levelSortRank {
                    return lhs.levelSortRank < rhs.levelSortRank
                }

                if lhs.isMinorLeaguer != rhs.isMinorLeaguer {
                    return lhs.isMinorLeaguer == false
                }

                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        case .stateYear:
            return { lhs, rhs in
                if lhs.latestStateSeason != rhs.latestStateSeason {
                    return lhs.latestStateSeason > rhs.latestStateSeason
                }

                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
    }
}

private struct HeaderLogoView: View {
    let url: URL?
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Text("State")
                    .font(.system(size: 64, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.44, green: 0.04, blue: 0.12))
                    .minimumScaleFactor(0.7)
            case .empty:
                ProgressView()
                    .controlSize(.large)
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: 320)
        .frame(height: height)
        .accessibilityLabel("Mississippi State script logo")
    }
}

private struct RemoteLogoImage: View {
    let url: URL?
    let accessibilityLabel: String
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .foregroundStyle(.secondary)
            case .empty:
                ProgressView()
                    .tint(.white.opacity(0.8))
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: height, height: height)
        .accessibilityLabel(accessibilityLabel)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private enum AppScreen {
    case home
    case player
}

private struct HomePlayerCard: View {
    let title: String
    let systemImage: String
    let dashboard: PlayerDashboard?
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: systemImage)

            if let dashboard {
                Button {
                    action(dashboard.catalogEntry)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dashboard.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(dashboard.teamLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(summaryLine(for: dashboard))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("No player summary available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryLine(for dashboard: PlayerDashboard) -> String {
        guard let stat = dashboard.seasonStat?.stat else {
            return "No current season stat line returned yet."
        }

        if dashboard.catalogEntry.kind == .pitcher {
            return "\(stat.era ?? "-") ERA • \(stat.whip ?? "-") WHIP • \(stat.strikeOuts.display) K"
        }

        return "\(stat.avg ?? "-") AVG • \(stat.ops ?? "-") OPS • \(stat.homeRuns.display) HR"
    }
}

private struct HomeStoryCard: View {
    let title: String
    let systemImage: String
    let highlight: HomeStoryHighlight?
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: systemImage)

            if let highlight {
                VStack(alignment: .leading, spacing: 10) {
                    Link(destination: highlight.story.url) {
                        RowLink(
                            title: highlight.story.title,
                            subtitle: [highlight.player.displayName, highlight.story.source, highlight.story.publishedText]
                                .filter { !$0.isEmpty }
                                .joined(separator: " • "),
                            systemImage: "arrow.up.right.square"
                        )
                    }

                    Button {
                        action(highlight.player)
                    } label: {
                        Text("Open \(highlight.player.displayName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.44, green: 0.04, blue: 0.12))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No story available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TodaysActivePlayersSection: View {
    let dashboards: [PlayerDashboard]
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today’s Active Players", systemImage: "calendar.badge.clock")

            if dashboards.isEmpty {
                Text("No active game logs have posted for today yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dashboards, id: \.catalogEntry.id) { dashboard in
                    Button {
                        action(dashboard.catalogEntry)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(dashboard.catalogEntry.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(dashboard.gameLogs.first?.dateText ?? "Today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(dashboard.gameLogs.first?.line ?? dashboard.teamLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StatsSection: View {
    let dashboard: PlayerDashboard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: statsTitle, systemImage: "chart.bar.fill")

            if let stat = dashboard.seasonStat?.stat {
                if dashboard.catalogEntry.kind == .pitcher {
                    PitchingStats(stat: stat)
                } else {
                    HittingStats(stat: stat)
                }
            } else {
                Text("No current season stat line returned yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsTitle: String {
        guard dashboard.catalogEntry.isMinorLeaguer else {
            return "Season Stats"
        }

        if let sport = dashboard.seasonStat?.sport?.abbreviation {
            return "\(sport) Season Stats"
        }

        return "MiLB Season Stats"
    }
}

private struct MinorLeagueBanner: View {
    let dashboard: PlayerDashboard

    var body: some View {
        Label("He is in the minors", systemImage: "exclamationmark.triangle.fill")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HittingStats: View {
    let stat: BaseballStat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                StatTile(label: "AVG", value: stat.avg ?? "-")
                StatTile(label: "OPS", value: stat.ops ?? "-")
                StatTile(label: "HR", value: stat.homeRuns.display)
                StatTile(label: "RBI", value: stat.rbi.display)
                StatTile(label: "SB", value: stat.stolenBases.display)
                StatTile(label: "H", value: stat.hits.display)
            }

            Text("\(stat.gamesPlayed.display) G, \(stat.atBats.display) AB, \(stat.runs.display) R, \(stat.doubles.display) 2B, \(stat.triples.display) 3B")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PitchingStats: View {
    let stat: BaseballStat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                StatTile(label: "ERA", value: stat.era ?? "-")
                StatTile(label: "WHIP", value: stat.whip ?? "-")
                StatTile(label: "IP", value: stat.inningsPitched ?? "-")
                StatTile(label: "K", value: stat.strikeOuts.display)
                StatTile(label: "W-L", value: "\(stat.wins.display)-\(stat.losses.display)")
                StatTile(label: "SV", value: stat.saves.display)
            }

            Text("\(stat.gamesPlayed.display) G, \(stat.gamesStarted.display) GS, \(stat.baseOnBalls.display) BB")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RecentGameLogsSection: View {
    let gameLogs: [GameLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Game Logs", systemImage: "list.bullet.rectangle.portrait.fill")

            if gameLogs.isEmpty {
                Text("No recent game logs available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(gameLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.dateText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(log.opponentText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(log.line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

private struct HighlightsSection: View {
    let player: PlayerCatalogEntry
    let videos: [HighlightVideo]

    private var links: [(String, String, URL)] {
        let query = player.displayName.replacingOccurrences(of: " ", with: "+")
        return [
            ("MLB Player Page", "Stats, video, and transactions", URL(string: "https://www.mlb.com/player/\(player.id)")!),
            ("YouTube Search", "More highlights and clips", URL(string: "https://www.youtube.com/results?search_query=\(query)+Mississippi+State+highlights")!)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Highlights & Video", systemImage: "play.rectangle.fill")

            if videos.isEmpty {
                Text("No recent direct highlight links found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(videos) { video in
                    Link(destination: video.url) {
                        RowLink(
                            title: video.title,
                            subtitle: [video.source, video.publishedText].filter { !$0.isEmpty }.joined(separator: " • "),
                            systemImage: "play.circle.fill"
                        )
                    }
                }
            }

            ForEach(links, id: \.0) { title, subtitle, url in
                Link(destination: url) {
                    RowLink(title: title, subtitle: subtitle, systemImage: "arrow.up.right.square")
                }
            }
        }
    }
}

private struct FavoritesStrip: View {
    let players: [PlayerCatalogEntry]
    @Binding var selectedPlayerID: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Favorites", systemImage: "star.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(players) { player in
                        Button {
                            selectedPlayerID = player.id
                        } label: {
                            Text(player.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(player.id == selectedPlayerID ? Color(red: 0.44, green: 0.04, blue: 0.12) : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(player.id == selectedPlayerID ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct PlayerSelectionView: View {
    @Binding var selectedPlayerID: Int
    @Binding var favoritePlayerIDsStorage: String
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var favoritePlayerIDs: Set<Int> {
        Set(
            favoritePlayerIDsStorage
                .split(separator: ",")
                .compactMap { Int($0) }
        )
    }

    private var filteredPlayers: [PlayerCatalogEntry] {
        let players = PlayerCatalog.players
        guard !searchText.isEmpty else { return players }

        return players.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var favoritePlayers: [PlayerCatalogEntry] {
        filteredPlayers.filter { favoritePlayerIDs.contains($0.id) }
    }

    private var nonFavoritePlayers: [PlayerCatalogEntry] {
        filteredPlayers.filter { !favoritePlayerIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !favoritePlayers.isEmpty {
                    Section("Favorites") {
                        ForEach(favoritePlayers) { player in
                            playerRow(for: player)
                        }
                    }
                }

                Section("All Players") {
                    ForEach(nonFavoritePlayers) { player in
                        playerRow(for: player)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search players")
            .navigationTitle("Select Player")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func playerRow(for player: PlayerCatalogEntry) -> some View {
        Button {
            selectedPlayerID = player.id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(player.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    toggleFavorite(player.id)
                } label: {
                    Image(systemName: favoritePlayerIDs.contains(player.id) ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)

                if player.id == selectedPlayerID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.44, green: 0.04, blue: 0.12))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleFavorite(_ playerID: Int) {
        var updatedFavorites = favoritePlayerIDs
        if updatedFavorites.contains(playerID) {
            updatedFavorites.remove(playerID)
        } else {
            updatedFavorites.insert(playerID)
        }
        favoritePlayerIDsStorage = updatedFavorites.sorted().map(String.init).joined(separator: ",")
    }
}

private struct StoriesSection: View {
    let stories: [Story]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Stories", systemImage: "newspaper.fill")

            if stories.isEmpty {
                Text("No recent stories found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stories) { story in
                    Link(destination: story.url) {
                        RowLink(
                            title: story.title,
                            subtitle: [story.source, story.publishedText].filter { !$0.isEmpty }.joined(separator: " • "),
                            systemImage: "doc.text"
                        )
                    }
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }
}

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RowLink: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(Color(red: 0.56, green: 0.08, blue: 0.18))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LoadingView: View {
    var body: some View {
        HStack {
            ProgressView()
            Text("Loading today's update...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

private struct EmptyStateView: View {
    let playerName: String

    var body: some View {
        Text("Tap refresh to load \(playerName)'s latest dashboard.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
    }
}

private extension Optional where Wrapped == Int {
    var display: String {
        guard let self else { return "-" }
        return String(self)
    }
}

private extension PlayerCatalogEntry {
    var fallbackLine: String {
        id == 804606 || id == 828098 ? msuYears : "Mississippi State \(msuYears)"
    }
}

private extension PlayerCatalogEntry {
    var teamLogoURL: URL? {
        let resolvedLogoCode = PlayerRuntimeStore.teamLogoCode(for: id) ?? teamLogoCode
        guard let resolvedLogoCode else {
            return nil
        }

        return URL(string: "https://a.espncdn.com/i/teamlogos/mlb/500/\(resolvedLogoCode).png")
    }
}

private extension PlayerCatalogEntry {
    var levelLabel: String {
        guard effectiveIsMinorLeaguer else {
            return "MLB"
        }

        switch effectiveSportID {
        case 11:
            return "Triple-A"
        case 12:
            return "Double-A"
        case 13:
            return "High-A"
        case 14:
            return "Single-A"
        case 16:
            return "Rookie"
        default:
            return "MiLB"
        }
    }

    var levelSortRank: Int {
        guard effectiveIsMinorLeaguer else {
            return 0
        }

        switch effectiveSportID {
        case 11:
            return 1
        case 12:
            return 2
        case 13:
            return 3
        case 14:
            return 4
        case 16:
            return 5
        default:
            return 6
        }
    }

    var latestStateSeason: Int {
        let years = msuYears.matches(of: /20\d{2}/).compactMap { Int($0.output) }
        return years.max() ?? 0
    }

    var stateYearLabel: String {
        latestStateSeason > 0 ? String(latestStateSeason) : "State Years"
    }

    private var effectiveSportID: Int? {
        if let override = PlayerRuntimeStore.sportID(for: id) {
            return override
        }

        return preferredSportID
    }

    private var effectiveIsMinorLeaguer: Bool {
        PlayerRuntimeStore.isMinorLeaguer(for: id) ?? isMinorLeaguer
    }
}

#Preview {
    ContentView()
}
