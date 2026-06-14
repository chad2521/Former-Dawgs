import SwiftUI

struct StatsSection: View {
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
        guard dashboard.catalogEntry.isMinorLeaguer else { return "Season Stats" }
        if let sport = dashboard.seasonStat?.sport?.abbreviation {
            return "\(sport) Season Stats"
        }
        return "MiLB Season Stats"
    }
}

struct MinorLeagueBanner: View {
    let dashboard: PlayerDashboard

    var body: some View {
        Label(bannerText, systemImage: "exclamationmark.triangle.fill")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.msMaroon)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var bannerText: String {
        let level = dashboard.catalogEntry.levelLabel
        if let team = dashboard.profile.currentTeam?.name {
            return "Minor Leagues \u{2014} \(level) (\(team))"
        }
        return "Minor Leagues \u{2014} \(level)"
    }
}

struct CareerTimelineSection: View {
    let dashboard: PlayerDashboard

    private var stops: [CareerStop] { CareerStop.timeline(for: dashboard) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Career Arc", systemImage: "map.fill")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    CareerTimelineRow(stop: stop, isLast: index == stops.count - 1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct CareerTimelineRow: View {
    let stop: CareerStop
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .strokeBorder(stop.isCurrent ? Color.msMaroon : Color.secondary.opacity(0.4), lineWidth: 2)
                        .background(Circle().fill(stop.isCurrent ? Color.msMaroon : Color.clear))
                        .frame(width: 14, height: 14)
                    if stop.isPast {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(stop.isPast ? Color.msMaroon.opacity(0.4) : Color.secondary.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stop.title)
                        .font(.subheadline)
                        .fontWeight(stop.isCurrent ? .bold : .semibold)
                        .foregroundStyle(stop.isCurrent ? Color.msMaroonText : .primary)
                    if stop.isCurrent {
                        Text("NOW")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.msMaroon)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                if let subtitle = stop.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : 14)
            .padding(.top, 1)

            Spacer(minLength: 0)
        }
    }
}

private struct CareerStop: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let isCurrent: Bool
    let isPast: Bool

    static func timeline(for dashboard: PlayerDashboard) -> [CareerStop] {
        let currentRank = dashboard.catalogEntry.levelSortRank
        let teamName = dashboard.profile.currentTeam?.name

        let path: [(label: String, rank: Int)] = [
            ("Mississippi State", -1),
            ("Rookie Ball", 5),
            ("Single-A", 4),
            ("High-A", 3),
            ("Double-A", 2),
            ("Triple-A", 1),
            ("Major Leagues", 0)
        ]

        return path.map { entry in
            let isCurrent: Bool
            let isPast: Bool
            let subtitle: String?

            if entry.rank == -1 {
                isCurrent = false
                isPast = true
                subtitle = "State \(dashboard.catalogEntry.msuYears)"
            } else {
                isCurrent = entry.rank == currentRank
                isPast = entry.rank > currentRank
                subtitle = isCurrent ? teamName : nil
            }

            return CareerStop(title: entry.label, subtitle: subtitle, isCurrent: isCurrent, isPast: isPast)
        }
    }
}

struct HittingStats: View {
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

struct PitchingStats: View {
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

struct RecentGameLogsSection: View {
    let dashboard: PlayerDashboard

    private var gameLogs: [GameLogEntry] {
        dashboard.gameLogs
    }

    private var insights: [String] {
        gameLogInsights(for: dashboard)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Game Logs", systemImage: "list.bullet.rectangle.portrait.fill")

            if gameLogs.isEmpty {
                Text("No recent game logs available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if !insights.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(insights, id: \.self) { insight in
                            Text(insight)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                ForEach(gameLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.formattedDate)
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

    private func gameLogInsights(for dashboard: PlayerDashboard) -> [String] {
        let logs = dashboard.gameLogs
        guard !logs.isEmpty else { return [] }

        if dashboard.catalogEntry.kind == .pitcher {
            let recentStrikeouts = logs.prefix(5).compactMap(\.strikeOuts).reduce(0, +)
            let recentInnings = logs.prefix(5).compactMap(\.inningsPitched).reduce(0, +)
            let lastAppearance = logs.first?.formattedDate ?? "Recent"
            return [
                "\(lastAppearance) appearance",
                "\(recentStrikeouts) K over last 5 logs",
                "\(formattedInnings(recentInnings)) IP tracked recently"
            ]
        }

        let recentHits = logs.prefix(5).compactMap(\.hits).reduce(0, +)
        let recentRBI = logs.prefix(5).compactMap(\.rbi).reduce(0, +)
        let hitGames = logs.prefix(5).filter { ($0.hits ?? 0) > 0 }.count
        return [
            "\(recentHits) hits over last 5 logs",
            "\(hitGames) games with a hit",
            "\(recentRBI) RBI tracked recently"
        ]
    }

    private func formattedInnings(_ value: Double) -> String {
        value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct HighlightsSection: View {
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
                            subtitle: [video.source, video.publishedText].filter { !$0.isEmpty }.joined(separator: " \u{2022} "),
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

struct StoriesSection: View {
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
                            subtitle: [story.source, story.publishedText].filter { !$0.isEmpty }.joined(separator: " \u{2022} "),
                            systemImage: "doc.text"
                        )
                    }
                }
            }
        }
    }
}
