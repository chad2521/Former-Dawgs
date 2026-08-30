import SwiftUI

struct PlayerSelectorDropdown: View {
    @Environment(\.colorScheme) private var colorScheme
    let selectedPlayer: PlayerCatalogEntry?
    let favoritePlayerIDs: Set<Int>
    let onSelectPlayer: (PlayerCatalogEntry) -> Void
    let onToggleFavorite: (Int) -> Void
    @Binding var isExpanded: Bool
    @State private var searchText = ""
    @State private var sortOption = PlayerSortOption.name
    @State private var rosterFilter = PlayerRosterFilter.all
    @State private var kindFilter = PlayerKindFilter.all
    @State private var statusFilter = PlayerStatusFilter.all

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Players", systemImage: "baseball.fill")
                .font(.headline)

            Button {
                isExpanded = true
            } label: {
                headerContent
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
            }
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        if let player = selectedPlayer {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(player.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if favoritePlayerIDs.contains(player.id) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            }
            .selectorButtonStyle()
        } else {
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
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            }
            .selectorButtonStyle()
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search players", text: $searchText)
                .textFieldStyle(.roundedBorder)

            filterControls

            HStack {
                Label("Sort", systemImage: sortOption.iconName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Sort players", selection: $sortOption) {
                    ForEach(PlayerSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            if !filteredFavorites.isEmpty {
                playerListSection(title: "Favorites", players: filteredFavorites)
            }

            if !filteredNonFavorites.isEmpty {
                playerListSection(title: "All Players", players: filteredNonFavorites)
            }

            if filteredPlayers.isEmpty {
                Text("No players match these filters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if hasActiveFilters {
                    Button("Clear") {
                        rosterFilter = .all
                        kindFilter = .all
                        statusFilter = .all
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.msMaroonText)
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Roster")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Roster level", selection: $rosterFilter) {
                    ForEach(PlayerRosterFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 10) {
                Picker("Player type", selection: $kindFilter) {
                    ForEach(PlayerKindFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Status", selection: $statusFilter) {
                    ForEach(PlayerStatusFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.iconName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func playerListSection(title: String, players: [PlayerCatalogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                if let header = levelHeader(before: index, in: players) {
                    if index > 0 { levelSectionBreak }
                    Text(header)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(sectionHeaderColor)
                        .padding(.top, index == 0 ? 0 : 6)
                }

                if let header = stateYearHeader(before: index, in: players) {
                    Text(header)
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
            searchText = ""
            onSelectPlayer(player)
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
                    Text("\(player.levelLabel) \u{2022} State \(player.msuYears)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { onToggleFavorite(player.id) } label: {
                    Image(systemName: favoritePlayerIDs.contains(player.id) ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
                if let selected = selectedPlayer, player.id == selected.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.msMaroonText)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func levelHeader(before index: Int, in players: [PlayerCatalogEntry]) -> String? {
        guard sortOption == .level else { return nil }
        let current = players[index].levelLabel
        if index == 0 { return current }
        return players[index - 1].levelLabel == current ? nil : current
    }

    private func stateYearHeader(before index: Int, in players: [PlayerCatalogEntry]) -> String? {
        guard sortOption == .stateYear else { return nil }
        let current = players[index].stateYearLabel
        if index == 0 { return current }
        return players[index - 1].stateYearLabel == current ? nil : current
    }

    private var sectionHeaderColor: Color {
        .msMaroonText
    }

    private var levelSectionBreak: some View {
        Rectangle()
            .fill(Color.msMaroon.opacity(colorScheme == .dark ? 0.55 : 0.75))
            .frame(height: 2)
            .clipShape(Capsule())
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

private extension View {
    func selectorButtonStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

enum PlayerRosterFilter: String, CaseIterable, Identifiable {
    case all
    case mlb
    case minors
    case tripleA
    case doubleA
    case highA
    case singleA
    case rookie

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .mlb: "MLB"
        case .minors: "MiLB"
        case .tripleA: "AAA"
        case .doubleA: "AA"
        case .highA: "High-A"
        case .singleA: "A"
        case .rookie: "Rookie"
        }
    }

    func includes(_ player: PlayerCatalogEntry) -> Bool {
        switch self {
        case .all:
            true
        case .mlb:
            player.levelLabel == "MLB"
        case .minors:
            player.levelLabel != "MLB"
        case .tripleA:
            player.levelLabel == "Triple-A"
        case .doubleA:
            player.levelLabel == "Double-A"
        case .highA:
            player.levelLabel == "High-A"
        case .singleA:
            player.levelLabel == "Single-A"
        case .rookie:
            player.levelLabel == "Rookie"
        }
    }
}

enum PlayerKindFilter: String, CaseIterable, Identifiable {
    case all
    case hitters
    case pitchers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Roles"
        case .hitters: "Hitters"
        case .pitchers: "Pitchers"
        }
    }

    func includes(_ player: PlayerCatalogEntry) -> Bool {
        switch self {
        case .all: true
        case .hitters: player.kind == .hitter
        case .pitchers: player.kind == .pitcher
        }
    }
}

enum PlayerStatusFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case activeToday
    case recentDraftees

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Any Status"
        case .favorites: "Favorites"
        case .activeToday: "Active Today"
        case .recentDraftees: "Recent Draft"
        }
    }

    var iconName: String {
        switch self {
        case .all: "circle.grid.2x2"
        case .favorites: "star.fill"
        case .activeToday: "calendar.badge.clock"
        case .recentDraftees: "sparkles"
        }
    }

    func includes(_ player: PlayerCatalogEntry, favoritePlayerIDs: Set<Int>, activeTodayIDs: Set<Int>, recentDrafteeIDs: Set<Int>) -> Bool {
        switch self {
        case .all:
            true
        case .favorites:
            favoritePlayerIDs.contains(player.id)
        case .activeToday:
            activeTodayIDs.contains(player.id)
        case .recentDraftees:
            recentDrafteeIDs.contains(player.id)
        }
    }
}
