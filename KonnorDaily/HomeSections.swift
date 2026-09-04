import SwiftUI

struct FreshDrafteesSection: View {
    let draftees: [DynamicDraftee]
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Fresh Draftees", systemImage: "sparkles")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(draftees) { draftee in
                        Button { action(draftee.toCatalogEntry()) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    PlayerHeadshotImage(
                                        url: draftee.toCatalogEntry().headshotURL,
                                        initials: draftee.toCatalogEntry().initials,
                                        accessibilityLabel: "\(draftee.fullName) headshot",
                                        size: 44
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(draftee.draftYear) DRAFT")
                                            .font(.caption2.weight(.bold))
                                        Text(draftee.role)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(.white)

                                Text(draftee.fullName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                Text(draftee.pickHeadline)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                            }
                            .padding(14)
                            .frame(width: 210, height: 150, alignment: .topLeading)
                            .background(
                                LinearGradient(
                                    colors: [Color.msMaroon, Color(red: 0.10, green: 0.10, blue: 0.11)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct HomePlayerCard: View {
    let title: String
    let systemImage: String
    let dashboard: PlayerDashboard?
    let action: (PlayerCatalogEntry) -> Void

    /// The best validated highlight resolved from the YouTube Data API.
    @State private var resolvedVideo: HighlightVideo?
    @State private var isResolvingVideo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: systemImage)

            if let dashboard {
                VStack(alignment: .leading, spacing: 10) {
                    Button { action(dashboard.catalogEntry) } label: {
                        HStack(alignment: .center, spacing: 14) {
                            PlayerHeadshotImage(
                                url: dashboard.catalogEntry.headshotURL,
                                initials: dashboard.catalogEntry.initials,
                                accessibilityLabel: "\(dashboard.name) headshot",
                                size: 76
                            )
                            VStack(alignment: .leading, spacing: 6) {
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
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    highlightLink(for: dashboard)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .task(id: dashboard.catalogEntry.id) {
                    await resolveHighlight(for: dashboard)
                }
            } else {
                Text("No player summary available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Shows the validated best highlight once resolved, a loading state while
    /// querying YouTube, a plain search link as a fallback, plus a compact
    /// secondary free curated "Videos on X" deep link (no X API).
    @ViewBuilder
    private func highlightLink(for dashboard: PlayerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let video = resolvedVideo {
                Link(destination: video.url) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Watch top highlight", systemImage: "play.rectangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.msMaroon)
                        Text(video.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else if isResolvingVideo {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding best highlight\u{2026}")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let searchURL = youTubeHighlightsURL(for: dashboard) {
                Link(destination: searchURL) {
                    Label("Search highlights on YouTube", systemImage: "magnifyingglass")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.msMaroon)
                }
            }

            Link(destination: XVideoService().searchURL(for: dashboard.name)) {
                Label("Videos on X", systemImage: "play.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Queries the YouTube Data API for the best playable highlight for this player.
    private func resolveHighlight(for dashboard: PlayerDashboard) async {
        resolvedVideo = nil
        isResolvingVideo = true
        defer { isResolvingVideo = false }

        let best = await YouTubeHighlightService().bestHighlight(
            for: dashboard.name,
            preferPitching: dashboard.catalogEntry.kind == .pitcher
        )
        guard !Task.isCancelled else { return }
        resolvedVideo = best
    }

    /// Builds a YouTube search URL for the player's highlights.
    private func youTubeHighlightsURL(for dashboard: PlayerDashboard) -> URL? {
        let query = "\(dashboard.name) baseball highlights"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")
    }

    private func summaryLine(for dashboard: PlayerDashboard) -> String {
        guard let stat = dashboard.seasonStat?.stat else {
            return "No current season stat line returned yet."
        }
        if dashboard.catalogEntry.kind == .pitcher {
            return "\(stat.era ?? "-") ERA \u{2022} \(stat.whip ?? "-") WHIP \u{2022} \(stat.strikeOuts.display) K"
        }
        return "\(stat.avg ?? "-") AVG \u{2022} \(stat.ops ?? "-") OPS \u{2022} \(stat.homeRuns.display) HR"
    }
}

struct HomeStoryCard: View {
    let title: String
    let systemImage: String
    let highlight: HomeStoryHighlight?
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: systemImage)

            if let highlight {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        PlayerHeadshotImage(
                            url: highlight.player.headshotURL,
                            initials: highlight.player.initials,
                            accessibilityLabel: "\(highlight.player.displayName) headshot",
                            size: 52
                        )
                        Link(destination: highlight.story.url) {
                            RowLink(
                                title: highlight.story.title,
                                subtitle: [highlight.player.displayName, highlight.story.source, highlight.story.publishedText]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " \u{2022} "),
                                systemImage: "arrow.up.right.square"
                            )
                        }
                    }

                    Button { action(highlight.player) } label: {
                        Text("Open \(highlight.player.displayName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.msMaroon)
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

struct TodaysDawgsSection: View {
    let summary: TodayPerformanceSummary
    let activePlayers: [PlayerDashboard]
    let action: (PlayerCatalogEntry) -> Void

    private var orderedPlayers: [PlayerDashboard] {
        let featuredIDs = Set(
            summary.homeredToday.map(\.catalogEntry.id)
            + summary.multiHitToday.map(\.catalogEntry.id)
            + summary.pitchedToday.map(\.catalogEntry.id)
        )
        return activePlayers.sorted { lhs, rhs in
            let leftFeatured = featuredIDs.contains(lhs.catalogEntry.id)
            let rightFeatured = featuredIDs.contains(rhs.catalogEntry.id)
            if leftFeatured != rightFeatured { return leftFeatured }
            return lhs.catalogEntry.displayName.localizedCaseInsensitiveCompare(rhs.catalogEntry.displayName) == .orderedAscending
        }
    }

    private var homeredIDs: Set<Int> {
        Set(summary.homeredToday.map(\.catalogEntry.id))
    }

    private var multiHitIDs: Set<Int> {
        Set(summary.multiHitToday.map(\.catalogEntry.id))
    }

    private var pitchedIDs: Set<Int> {
        Set(summary.pitchedToday.map(\.catalogEntry.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Dawgs", systemImage: "sun.max.fill")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                StatTile(label: "Active", value: String(max(summary.activePlayers.count, activePlayers.count)))
                StatTile(label: "HR", value: String(summary.homeredToday.count))
                StatTile(label: "Multi-Hit", value: String(summary.multiHitToday.count))
                StatTile(label: "Pitched", value: String(summary.pitchedToday.count))
            }

            if orderedPlayers.isEmpty {
                Text("No box scores have posted for today yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orderedPlayers, id: \.catalogEntry.id) { dashboard in
                    Button { action(dashboard.catalogEntry) } label: {
                        HStack(alignment: .center, spacing: 12) {
                            PlayerHeadshotImage(
                                url: dashboard.catalogEntry.headshotURL,
                                initials: dashboard.catalogEntry.initials,
                                accessibilityLabel: "\(dashboard.catalogEntry.displayName) headshot",
                                size: 44
                            )
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 6) {
                                    Text(dashboard.catalogEntry.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                    if !badges(for: dashboard).isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(badges(for: dashboard), id: \.self) { badge in
                                                Text(badge)
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(Color.msMaroonText)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(Color.msMaroon.opacity(0.15))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                Text(dashboard.gameLogs.first?.line ?? dashboard.teamLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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

    private func badges(for dashboard: PlayerDashboard) -> [String] {
        var labels: [String] = []
        let id = dashboard.catalogEntry.id
        if homeredIDs.contains(id) { labels.append("HR") }
        if multiHitIDs.contains(id) { labels.append("Multi") }
        if pitchedIDs.contains(id) { labels.append("P") }
        return labels
    }
}

struct WeeklyLeadersSection: View {
    let title: String
    let entries: [HomeLeaderboardEntry]
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: "chart.line.uptrend.xyaxis")

            if entries.isEmpty {
                Text("Not enough recent games yet to rank this week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button { action(entry.dashboard.catalogEntry) } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .frame(width: 28, alignment: .leading)
                            PlayerHeadshotImage(
                                url: entry.dashboard.catalogEntry.headshotURL,
                                initials: entry.dashboard.catalogEntry.initials,
                                accessibilityLabel: "\(entry.dashboard.catalogEntry.displayName) headshot",
                                size: 44
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.dashboard.catalogEntry.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(entry.detailText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
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

struct TransactionTimelineSection: View {
    let highlights: [HomeStoryHighlight]
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Transactions Timeline", systemImage: "arrow.triangle.branch")

            if highlights.isEmpty {
                Text("No recent transaction-style stories found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(highlights) { highlight in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            PlayerHeadshotImage(
                                url: highlight.player.headshotURL,
                                initials: highlight.player.initials,
                                accessibilityLabel: "\(highlight.player.displayName) headshot",
                                size: 40
                            )
                            Link(destination: highlight.story.url) {
                                RowLink(
                                    title: highlight.story.title,
                                    subtitle: [highlight.player.displayName, highlight.story.source, highlight.story.publishedText]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " \u{2022} "),
                                    systemImage: "arrow.up.right.square"
                                )
                            }
                        }
                        Button { action(highlight.player) } label: {
                            Text("Open \(highlight.player.displayName)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct FavoritesWatchlistSection: View {
    let dashboards: [PlayerDashboard]
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My Dawgs", systemImage: "star.bubble.fill")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                StatTile(label: "Tracked", value: String(dashboards.count))
                StatTile(label: "Active Today", value: String(dashboards.filter { !$0.gameLogs.isEmpty && $0.gameLogs.first?.formattedDate == "Today" }.count))
                StatTile(label: "With News", value: String(dashboards.filter { !$0.stories.isEmpty }.count))
            }

            ForEach(dashboards, id: \.catalogEntry.id) { dashboard in
                Button { action(dashboard.catalogEntry) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            PlayerHeadshotImage(
                                url: dashboard.catalogEntry.headshotURL,
                                initials: dashboard.catalogEntry.initials,
                                accessibilityLabel: "\(dashboard.catalogEntry.displayName) headshot",
                                size: 48
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dashboard.catalogEntry.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(dashboard.teamLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(dashboard.catalogEntry.levelLabel)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.msMaroon.opacity(0.2))
                                .clipShape(Capsule())
                        }

                        Text(favoriteInsight(for: dashboard))
                            .font(.caption)
                            .foregroundStyle(Color.appText)

                        Text(dashboard.gameLogs.first?.line ?? dashboard.seasonStat?.stat.summary ?? "Season line available")
                            .font(.caption2)
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

    private func favoriteInsight(for dashboard: PlayerDashboard) -> String {
        if dashboard.catalogEntry.kind == .pitcher {
            let strikeouts = dashboard.gameLogs.prefix(5).compactMap(\.strikeOuts).reduce(0, +)
            if strikeouts > 0 {
                return "\(strikeouts) strikeouts across recent tracked appearances."
            }
            return dashboard.seasonStat?.stat.era.map { "Current season marker: \($0) ERA." } ?? "No recent pitching trend available yet."
        }

        let hits = dashboard.gameLogs.prefix(5).compactMap(\.hits).reduce(0, +)
        if hits > 0 {
            return "\(hits) hits across recent tracked games."
        }
        return dashboard.seasonStat?.stat.ops.map { "Current season marker: \($0) OPS." } ?? "No recent hitting trend available yet."
    }
}

struct ComparePlayersSection: View {
    @Binding var comparePlayerAID: Int
    @Binding var comparePlayerBID: Int
    let dashboards: [PlayerDashboard]

    private var compareOptions: [PlayerDashboard] {
        Array(dashboards.prefix(12))
    }

    private var playerA: PlayerDashboard? {
        dashboards.first { $0.catalogEntry.id == comparePlayerAID }
    }

    private var playerB: PlayerDashboard? {
        dashboards.first { $0.catalogEntry.id == comparePlayerBID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Compare Players", systemImage: "rectangle.split.2x1.fill")

            if compareOptions.count < 2 {
                Text("Need at least two loaded player dashboards to compare.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Picker("Player A", selection: $comparePlayerAID) {
                        ForEach(compareOptions, id: \.catalogEntry.id) { dashboard in
                            Text(dashboard.catalogEntry.displayName).tag(dashboard.catalogEntry.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appText)
                    .foregroundStyle(Color.appText)

                    Picker("Player B", selection: $comparePlayerBID) {
                        ForEach(compareOptions, id: \.catalogEntry.id) { dashboard in
                            Text(dashboard.catalogEntry.displayName).tag(dashboard.catalogEntry.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.appText)
                    .foregroundStyle(Color.appText)
                }

                if let playerA, let playerB {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            comparisonColumn(for: playerA)
                            comparisonColumn(for: playerB)
                        }

                        ForEach(comparisonMetrics(playerA: playerA, playerB: playerB), id: \.title) { metric in
                            comparisonMetricRow(metric)
                        }
                    }
                }
            }
        }
    }

    private func comparisonColumn(for dashboard: PlayerDashboard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PlayerHeadshotImage(
                url: dashboard.catalogEntry.headshotURL,
                initials: dashboard.catalogEntry.initials,
                accessibilityLabel: "\(dashboard.catalogEntry.displayName) headshot",
                size: 52
            )
            Text(dashboard.catalogEntry.displayName)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(dashboard.catalogEntry.kind == .pitcher ? pitcherSummary(for: dashboard) : hitterSummary(for: dashboard))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(primaryEdge(for: dashboard))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func hitterSummary(for dashboard: PlayerDashboard) -> String {
        guard let stat = dashboard.seasonStat?.stat else { return "No current stat line." }
        return "\(stat.avg ?? "-") AVG \u{2022} \(stat.ops ?? "-") OPS \u{2022} \(stat.homeRuns.display) HR \u{2022} \(stat.rbi.display) RBI"
    }

    private func pitcherSummary(for dashboard: PlayerDashboard) -> String {
        guard let stat = dashboard.seasonStat?.stat else { return "No current stat line." }
        return "\(stat.era ?? "-") ERA \u{2022} \(stat.whip ?? "-") WHIP \u{2022} \(stat.strikeOuts.display) K \u{2022} \(stat.inningsPitched ?? "-") IP"
    }

    private func primaryEdge(for dashboard: PlayerDashboard) -> String {
        if dashboard.catalogEntry.kind == .pitcher {
            let strikeouts = dashboard.gameLogs.prefix(5).compactMap(\.strikeOuts).reduce(0, +)
            return strikeouts > 0 ? "Recent edge: \(strikeouts) K" : "Recent edge pending"
        }

        let hits = dashboard.gameLogs.prefix(5).compactMap(\.hits).reduce(0, +)
        return hits > 0 ? "Recent edge: \(hits) H" : "Recent edge pending"
    }

    private func comparisonMetrics(playerA: PlayerDashboard, playerB: PlayerDashboard) -> [ComparisonMetric] {
        if playerA.catalogEntry.kind == .pitcher || playerB.catalogEntry.kind == .pitcher {
            return [
                ComparisonMetric(title: "Strikeouts", lhs: Double(playerA.seasonStat?.stat.strikeOuts ?? 0), rhs: Double(playerB.seasonStat?.stat.strikeOuts ?? 0), higherIsBetter: true),
                ComparisonMetric(title: "Recent K", lhs: Double(playerA.gameLogs.prefix(5).compactMap(\.strikeOuts).reduce(0, +)), rhs: Double(playerB.gameLogs.prefix(5).compactMap(\.strikeOuts).reduce(0, +)), higherIsBetter: true),
                ComparisonMetric(title: "WHIP", lhs: doubleValue(playerA.seasonStat?.stat.whip), rhs: doubleValue(playerB.seasonStat?.stat.whip), higherIsBetter: false)
            ]
        }

        return [
            ComparisonMetric(title: "OPS", lhs: doubleValue(playerA.seasonStat?.stat.ops), rhs: doubleValue(playerB.seasonStat?.stat.ops), higherIsBetter: true),
            ComparisonMetric(title: "Home Runs", lhs: Double(playerA.seasonStat?.stat.homeRuns ?? 0), rhs: Double(playerB.seasonStat?.stat.homeRuns ?? 0), higherIsBetter: true),
            ComparisonMetric(title: "Recent Hits", lhs: Double(playerA.gameLogs.prefix(5).compactMap(\.hits).reduce(0, +)), rhs: Double(playerB.gameLogs.prefix(5).compactMap(\.hits).reduce(0, +)), higherIsBetter: true)
        ]
    }

    private func comparisonMetricRow(_ metric: ComparisonMetric) -> some View {
        let maxValue = max(metric.lhs, metric.rhs, 1)
        let lhsProgress = metric.lhs / maxValue
        let rhsProgress = metric.rhs / maxValue
        let leader = metric.leadingSide

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.title)
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Text(leader)
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondaryText)
            }

            comparisonBar(label: "A", value: metric.lhs, progress: lhsProgress, isLeader: leader == "Player A edge")
            comparisonBar(label: "B", value: metric.rhs, progress: rhsProgress, isLeader: leader == "Player B edge")
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func comparisonBar(label: String, value: Double, progress: Double, isLeader: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .frame(width: 16)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemGroupedBackground))
                    Capsule()
                        .fill(isLeader ? Color.msMaroon : Color.appSecondaryText.opacity(0.5))
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
            Text(formattedMetric(value))
                .font(.caption2)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func doubleValue(_ value: String?) -> Double {
        Double(value ?? "") ?? 0
    }

    private func formattedMetric(_ value: Double) -> String {
        value == floor(value) ? String(Int(value)) : String(format: "%.3f", value)
    }
}

private struct ComparisonMetric {
    let title: String
    let lhs: Double
    let rhs: Double
    let higherIsBetter: Bool

    var leadingSide: String {
        guard lhs != rhs else { return "Even" }
        let lhsLeads = higherIsBetter ? lhs > rhs : lhs < rhs
        return lhsLeads ? "Player A edge" : "Player B edge"
    }
}

struct HomeLiveGamesSection: View {
    let scoreboard: [PlayerDashboard]
    let favoritePlayerIDs: Set<Int>
    let onSelectPlayer: (PlayerCatalogEntry) -> Void
    let onOpenTonight: () -> Void
    let onTrack: (PlayerDashboard) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var liveGames: [PlayerDashboard] {
        scoreboard
            .filter { $0.todayGame?.state == .live }
            .sorted { lhs, rhs in
                let leftFavorite = favoritePlayerIDs.contains(lhs.catalogEntry.id)
                let rightFavorite = favoritePlayerIDs.contains(rhs.catalogEntry.id)
                if leftFavorite != rightFavorite { return leftFavorite }
                return lhs.catalogEntry.displayName.localizedCaseInsensitiveCompare(rhs.catalogEntry.displayName) == .orderedAscending
            }
    }

    private var upcomingGames: [PlayerDashboard] {
        scoreboard
            .filter { $0.todayGame?.state == .scheduled }
            .sorted {
                ($0.todayGame?.startTime ?? .distantFuture) < ($1.todayGame?.startTime ?? .distantFuture)
            }
    }

    var body: some View {
        Group {
            if let featured = liveGames.first {
                VStack(alignment: .leading, spacing: 12) {
                    featuredCard(featured)
                    ForEach(Array(liveGames.dropFirst()), id: \.catalogEntry.id) { dashboard in
                        compactLiveRow(dashboard)
                    }
                }
            } else if let next = upcomingGames.first {
                upcomingCard(next, extraCount: max(0, upcomingGames.count - 1))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func featuredCard(_ dashboard: PlayerDashboard) -> some View {
        let game = dashboard.todayGame
        let tracking = DawgLiveActivityManager.shared.activeActivity(for: dashboard.catalogEntry.id) != nil

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.25 : 0.85)
                        .opacity(pulse ? 1 : 0.55)
                    Text("LIVE")
                        .font(.caption.weight(.heavy))
                        .tracking(1.4)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                Button(action: onOpenTonight) {
                    Text(liveGames.count > 1 ? "\(liveGames.count) live · map" : "Ballpark map")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .buttonStyle(.plain)
            }

            Button { onSelectPlayer(dashboard.catalogEntry) } label: {
                HStack(alignment: .center, spacing: 14) {
                    PlayerHeadshotImage(
                        url: dashboard.catalogEntry.headshotURL,
                        initials: dashboard.catalogEntry.initials,
                        accessibilityLabel: "\(dashboard.catalogEntry.displayName) headshot",
                        size: 72
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(dashboard.catalogEntry.displayName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            if favoritePlayerIDs.contains(dashboard.catalogEntry.id) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text(dashboard.teamLine)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                        if let game {
                            Text(game.headline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(game?.scoreLine ?? "—")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game?.inningText ?? "In progress")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    if let venue = game?.venueName {
                        Text(venue)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button { onSelectPlayer(dashboard.catalogEntry) } label: {
                    Label("Player", systemImage: "person.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button { onTrack(dashboard) } label: {
                    Label(
                        tracking ? "Tracking" : "Track Live",
                        systemImage: tracking ? "dot.radiowaves.left.and.right" : "bell.badge.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(tracking ? .gray : Color.red)
                .disabled(tracking)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.msMaroon, Color(red: 0.18, green: 0.04, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(liveAccessibility(dashboard))
    }

    private func compactLiveRow(_ dashboard: PlayerDashboard) -> some View {
        Button { onSelectPlayer(dashboard.catalogEntry) } label: {
            HStack(spacing: 12) {
                PlayerHeadshotImage(
                    url: dashboard.catalogEntry.headshotURL,
                    initials: dashboard.catalogEntry.initials,
                    accessibilityLabel: "\(dashboard.catalogEntry.displayName) headshot",
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(dashboard.catalogEntry.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(dashboard.todayGame?.headline ?? dashboard.teamLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dashboard.todayGame?.scoreLine ?? "LIVE")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.msMaroonText)
                    Text(dashboard.todayGame?.inningText ?? "Live")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func upcomingCard(_ dashboard: PlayerDashboard, extraCount: Int) -> some View {
        Button(action: onOpenTonight) {
            HStack(spacing: 12) {
                PlayerHeadshotImage(
                    url: dashboard.catalogEntry.headshotURL,
                    initials: dashboard.catalogEntry.initials,
                    accessibilityLabel: "\(dashboard.catalogEntry.displayName) headshot",
                    size: 48
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Up next")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.msMaroonText)
                    Text(dashboard.catalogEntry.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(dashboard.todayGame?.headline ?? dashboard.teamLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dashboard.todayGame?.statusText ?? "Today")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    if extraCount > 0 {
                        Text("+\(extraCount) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.msMaroonText)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens tonight's scoreboard map")
    }

    private func liveAccessibility(_ dashboard: PlayerDashboard) -> String {
        let game = dashboard.todayGame
        let score = game?.scoreLine ?? ""
        let inning = game?.inningText ?? "in progress"
        return "Live now. \(dashboard.catalogEntry.displayName), \(game?.headline ?? ""), \(score), \(inning)."
    }
}
