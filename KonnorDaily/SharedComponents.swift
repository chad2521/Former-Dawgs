import SwiftUI

struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }
}

struct StatTile: View {
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

struct RowLink: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(Color.appText)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appText)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct LoadingView: View {
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

struct EmptyStateView: View {
    let playerName: String

    var body: some View {
        Text("Tap refresh to load \(playerName)'s latest dashboard.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
    }
}

struct HeaderLogoView: View {
    let url: URL?
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            logoContent
                .frame(maxWidth: 320)
                .frame(height: height)
        }
        .frame(maxWidth: 320)
        .frame(height: height)
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (isAnimating ? 16 : -16)),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.45
        )
        .compositingGroup()
        .shadow(color: Color.msMaroon.opacity(isAnimating && !reduceMotion ? 0.24 : 0.12), radius: 12, x: 0, y: 6)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .accessibilityLabel("Mississippi State script logo")
    }

    @ViewBuilder
    private var logoContent: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Text("State")
                    .font(.system(size: 64, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.msMaroonText)
                    .minimumScaleFactor(0.7)
            case .empty:
                ProgressView().controlSize(.large)
            @unknown default:
                EmptyView()
            }
        }
    }

}

struct RemoteLogoImage: View {
    let url: URL?
    let accessibilityLabel: String
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .foregroundStyle(.secondary)
            case .empty:
                ProgressView().tint(.white.opacity(0.8))
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: height, height: height)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PlayerHeadshotImage: View {
    let url: URL?
    let initials: String
    let accessibilityLabel: String
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                initialsFallback
            case .empty:
                ProgressView().tint(.white.opacity(0.8))
            @unknown default:
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.12))
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .accessibilityLabel(accessibilityLabel)
    }

    private var initialsFallback: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
    }
}

struct FavoritesStrip: View {
    let players: [PlayerCatalogEntry]
    @Binding var selectedPlayerID: Int
    var activeTodayIDs: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Favorites", systemImage: "star.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(players) { player in
                        Button {
                            selectedPlayerID = player.id
                        } label: {
                            HStack(spacing: 6) {
                                if activeTodayIDs.contains(player.id) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                        .accessibilityLabel("Game today")
                                }
                                Text(player.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(player.id == selectedPlayerID ? Color.msMaroon : Color(.secondarySystemGroupedBackground))
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

struct TodayGameBanner: View {
    let game: TodayGame
    var isTracking: Bool = false
    var onTrack: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(stateColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(stateLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.msMaroonText)
                Text(game.headline)
                    .font(.headline)
                Text(game.statusText)
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondaryText)
            }
            Spacer(minLength: 0)

            if let onTrack, game.state != .final {
                Button(action: onTrack) {
                    Label(isTracking ? "Tracking" : "Track Live", systemImage: isTracking ? "dot.radiowaves.left.and.right" : "bell.badge.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(isTracking ? .gray : .msMaroon)
                .disabled(isTracking)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var iconName: String {
        switch game.state {
        case .scheduled: return "clock.fill"
        case .live: return "dot.radiowaves.left.and.right"
        case .final: return "flag.checkered"
        }
    }

    private var stateColor: Color {
        switch game.state {
        case .scheduled: return .blue
        case .live: return .red
        case .final: return .gray
        }
    }

    private var stateLabel: String {
        switch game.state {
        case .scheduled: return "Tonight's Game"
        case .live: return "Live Now"
        case .final: return "Today's Result"
        }
    }
}

struct BrandHeader: View {
    let isLandscape: Bool
    let isWidePortrait: Bool

    var body: some View {
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
        .background(Color.clear)
    }
}

struct ErrorRetryView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
            Button("Retry", action: onRetry)
                .font(.footnote)
                .buttonStyle(.bordered)
                .tint(.red)
        }
        .padding(.top, 4)
    }
}

enum PlayerSortOption: String, CaseIterable, Identifiable {
    case name
    case level
    case stateYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "A-Z"
        case .level: "Level"
        case .stateYear: "State Year"
        }
    }

    var iconName: String {
        switch self {
        case .name: "textformat.abc"
        case .level: "line.3.horizontal.decrease.circle"
        case .stateYear: "calendar"
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
