import SwiftUI

/// A dedicated, full-screen browsing tab for the whole Former Dawgs catalog.
///
/// Reuses the same search, filter, and sort logic as the inline
/// `PlayerSelectorDropdown`, but presents it as a scrollable `List` with a
/// native search bar and toolbar filter/sort menus. Selecting a player hands
/// off to the caller, which presents the detail dashboard.
///
/// Also hosts the org depth chart — every Dawg grouped under their MLB system
/// for call-up races.
private enum BrowseViewMode: String, CaseIterable, Identifiable {
    case list
    case orgs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "List"
        case .orgs: return "Orgs"
        }
    }
}

struct BrowseScreen: View {
    @AppStorage("favoritePlayerIDs", store: SharedAppGroup.defaults) private var favoritePlayerIDsStorage = ""

    /// Optional live dashboards from Home so org clubs reflect currentTeam when available.
    var dashboards: [PlayerDashboard] = []
    let onSelectPlayer: (PlayerCatalogEntry) -> Void

    @State private var searchText = ""
    @State private var sortOption = PlayerSortOption.name
    @State private var rosterFilter = PlayerRosterFilter.all
    @State private var kindFilter = PlayerKindFilter.all
    @State private var statusFilter = PlayerStatusFilter.all
    @State private var viewMode: BrowseViewMode = .list
    @State private var expandedOrgIDs: Set<String> = []

    private var favoritePlayerIDs: Set<Int> {
        FavoritePlayerStore.ids(from: favoritePlayerIDsStorage)
    }

    private var hasActiveFilters: Bool {
        rosterFilter != .all || kindFilter != .all || statusFilter != .all
    }

    private var filteredPlayers: [PlayerCatalogEntry] {
        let searched: [PlayerCatalogEntry]
        if searchText.isEmpty {
            searched = PlayerCatalog.players
        } else {
            searched = PlayerCatalog.players.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.role.localizedCaseInsensitiveContains(searchText) ||
                $0.levelLabel.localizedCaseInsensitiveContains(searchText) ||
                $0.msuYears.localizedCaseInsensitiveContains(searchText)
            }
        }

        let activeTodayIDs = PlayerRuntimeStore.playersWithGameToday()
        let recentDrafteeIDs = Set(DynamicDrafteeStore.recentDraftees().map(\.id))
        let matching = searched.filter { player in
            rosterFilter.includes(player) &&
            kindFilter.includes(player) &&
            statusFilter.includes(player, favoritePlayerIDs: favoritePlayerIDs, activeTodayIDs: activeTodayIDs, recentDrafteeIDs: recentDrafteeIDs)
        }
        return matching.sorted(by: sortOption.sortComparator)
    }

    private var filteredFavorites: [PlayerCatalogEntry] {
        filteredPlayers.filter { favoritePlayerIDs.contains($0.id) }
    }

    private var filteredNonFavorites: [PlayerCatalogEntry] {
        filteredPlayers.filter { !favoritePlayerIDs.contains($0.id) }
    }

    private var orgDepthOrgs: [OrgDepthOrg] {
        let orgs = OrgDepthChart.build(
            players: filteredPlayers,
            dashboards: dashboards,
            favoriteIDs: favoritePlayerIDs
        )
        if searchText.isEmpty { return orgs }
        let needle = searchText
        return orgs.compactMap { org in
            if org.name.localizedCaseInsensitiveContains(needle) {
                return org
            }
            let matchingPlayers = org.players.filter {
                $0.player.displayName.localizedCaseInsensitiveContains(needle)
                    || $0.clubName.localizedCaseInsensitiveContains(needle)
                    || $0.levelLabel.localizedCaseInsensitiveContains(needle)
            }
            guard !matchingPlayers.isEmpty else { return nil }
            return OrgDepthOrg(
                franchiseID: org.franchiseID,
                logoCode: org.logoCode,
                name: org.name,
                players: matchingPlayers
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewMode {
                case .list:
                    if filteredPlayers.isEmpty {
                        emptyState
                    } else {
                        playerList
                    }
                case .orgs:
                    if orgDepthOrgs.isEmpty {
                        emptyState
                    } else {
                        orgDepthList
                    }
                }
            }
            .navigationTitle(viewMode == .orgs ? "Org Depth" : "Players")
            .searchable(text: $searchText, prompt: viewMode == .orgs ? "Search orgs or players" : "Search players")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $viewMode) {
                        ForEach(BrowseViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if viewMode == .list { sortMenu }
                }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
        }
    }

    private var orgDepthList: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Call-up races by MLB system")
                        .font(.subheadline.weight(.semibold))
                    Text("Every former Dawg under their parent club — MLB on top, then Triple-A down to Rookie. Favorites rise first within each level.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }

            ForEach(orgDepthOrgs) { org in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedOrgIDs.contains(org.id) || orgDepthOrgs.count <= 6 },
                            set: { expanded in
                                if expanded {
                                    expandedOrgIDs.insert(org.id)
                                } else {
                                    expandedOrgIDs.remove(org.id)
                                }
                            }
                        )
                    ) {
                        ForEach(org.players) { entry in
                            orgPlayerRow(entry)
                        }
                    } label: {
                        orgHeader(org)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func orgHeader(_ org: OrgDepthOrg) -> some View {
        HStack(spacing: 12) {
            if let code = org.logoCode,
               let url = URL(string: "https://a.espncdn.com/i/teamlogos/mlb/500/\(code).png") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Image(systemName: "shield.fill")
                            .foregroundStyle(Color.msMaroon)
                    }
                }
                .frame(width: 34, height: 34)
            } else {
                Image(systemName: "shield.fill")
                    .foregroundStyle(Color.msMaroon)
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(org.name)
                    .font(.subheadline.weight(.bold))
                Text("\(org.players.count) Dawg\(org.players.count == 1 ? "" : "s") · \(org.mlbCount) MLB · \(org.farmCount) farm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func orgPlayerRow(_ entry: OrgDepthPlayer) -> some View {
        HStack(spacing: 12) {
            PlayerHeadshotImage(
                url: entry.player.headshotURL,
                initials: entry.player.initials,
                accessibilityLabel: "\(entry.player.displayName) headshot",
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.player.displayName)
                        .font(.subheadline.weight(.semibold))
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text("\(entry.player.role) · \(entry.clubName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.levelLabel)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(levelTint(entry.levelRank).opacity(0.15))
                .foregroundStyle(levelTint(entry.levelRank))
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelectPlayer(entry.player) }
    }

    private func levelTint(_ rank: Int) -> Color {
        switch rank {
        case 0: return Color.msMaroon
        case 1: return .orange
        case 2: return .blue
        case 3: return .teal
        case 4: return .indigo
        default: return .secondary
        }
    }

    private var playerList: some View {
        List {
            if !filteredFavorites.isEmpty {
                Section("Favorites") {
                    ForEach(filteredFavorites, content: playerRow)
                }
            }

            if !filteredNonFavorites.isEmpty {
                Section(nonFavoritesHeader) {
                    ForEach(filteredNonFavorites, content: playerRow)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var nonFavoritesHeader: String {
        filteredFavorites.isEmpty ? "\(filteredPlayers.count) Players" : "All Players"
    }

    private func playerRow(_ player: PlayerCatalogEntry) -> some View {
        HStack(spacing: 12) {
            PlayerHeadshotImage(
                url: player.headshotURL,
                initials: player.initials,
                accessibilityLabel: "\(player.displayName) headshot",
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(player.role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(player.levelLabel) \u{2022} State \(player.msuYears)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                FavoritePlayerStore.toggle(player.id, in: &favoritePlayerIDsStorage)
                CloudSyncStore.syncToCloud()
            } label: {
                Image(systemName: favoritePlayerIDs.contains(player.id) ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(favoritePlayerIDs.contains(player.id) ? "Remove \(player.displayName) from favorites" : "Add \(player.displayName) to favorites")
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelectPlayer(player) }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOption) {
                ForEach(PlayerSortOption.allCases) { option in
                    Label(option.title, systemImage: option.iconName).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort players")
    }

    private var filterMenu: some View {
        Menu {
            Picker("Roster", selection: $rosterFilter) {
                ForEach(PlayerRosterFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            Picker("Type", selection: $kindFilter) {
                ForEach(PlayerKindFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            Picker("Status", selection: $statusFilter) {
                ForEach(PlayerStatusFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.iconName).tag(filter)
                }
            }

            if hasActiveFilters {
                Divider()
                Button(role: .destructive, action: clearFilters) {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter players")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Dawgs Found", systemImage: "baseball")
        } description: {
            Text(searchText.isEmpty ? "No players match these filters." : "No players match \u{201C}\(searchText)\u{201D}.")
        } actions: {
            if hasActiveFilters {
                Button("Clear Filters", action: clearFilters)
            }
        }
    }

    private func clearFilters() {
        rosterFilter = .all
        kindFilter = .all
        statusFilter = .all
    }
}
