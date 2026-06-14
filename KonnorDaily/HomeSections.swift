import SwiftUI

struct HomePlayerCard: View {
    let title: String
    let systemImage: String
    let dashboard: PlayerDashboard?
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: systemImage)

            if let dashboard {
                Button { action(dashboard.catalogEntry) } label: {
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
                    Link(destination: highlight.story.url) {
                        RowLink(
                            title: highlight.story.title,
                            subtitle: [highlight.player.displayName, highlight.story.source, highlight.story.publishedText]
                                .filter { !$0.isEmpty }
                                .joined(separator: " \u{2022} "),
                            systemImage: "arrow.up.right.square"
                        )
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

struct TodaysActivePlayersSection: View {
    let dashboards: [PlayerDashboard]
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Active Players", systemImage: "calendar.badge.clock")

            if dashboards.isEmpty {
                Text("No active game logs have posted for today yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dashboards, id: \.catalogEntry.id) { dashboard in
                    Button { action(dashboard.catalogEntry) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(dashboard.catalogEntry.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(dashboard.gameLogs.first?.formattedDate ?? "Today")
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

struct TodaySummarySection: View {
    let summary: TodayPerformanceSummary
    let action: (PlayerCatalogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today Tracker", systemImage: "sun.max.fill")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                StatTile(label: "Active", value: String(summary.activePlayers.count))
                StatTile(label: "HR Today", value: String(summary.homeredToday.count))
                StatTile(label: "Pitched", value: String(summary.pitchedToday.count))
                StatTile(label: "Multi-Hit", value: String(summary.multiHitToday.count))
            }

            if !summary.homeredToday.isEmpty {
                compactPlayerList(title: "Homered Today", dashboards: summary.homeredToday)
            }

            if !summary.pitchedToday.isEmpty {
                compactPlayerList(title: "Pitched Today", dashboards: summary.pitchedToday)
            }
        }
    }

    @ViewBuilder
    private func compactPlayerList(title: String, dashboards: [PlayerDashboard]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(dashboards, id: \.catalogEntry.id) { dashboard in
                Button { action(dashboard.catalogEntry) } label: {
                    HStack {
                        Text(dashboard.catalogEntry.displayName)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(dashboard.gameLogs.first?.line ?? dashboard.teamLine)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
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
                        HStack(alignment: .top, spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.appText)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.dashboard.catalogEntry.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(entry.detailText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                        Link(destination: highlight.story.url) {
                            RowLink(
                                title: highlight.story.title,
                                subtitle: [highlight.player.displayName, highlight.story.source, highlight.story.publishedText]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " \u{2022} "),
                                systemImage: "arrow.up.right.square"
                            )
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
