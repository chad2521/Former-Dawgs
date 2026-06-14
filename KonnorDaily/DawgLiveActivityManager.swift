import Foundation
import ActivityKit

@MainActor
final class DawgLiveActivityManager {
    static let shared = DawgLiveActivityManager()

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func activeActivity(for playerID: Int) -> Activity<DawgLiveActivityAttributes>? {
        Activity<DawgLiveActivityAttributes>.activities
            .first { $0.attributes.playerID == playerID }
    }

    func startOrUpdate(for dashboard: PlayerDashboard) {
        guard isSupported, let todayGame = dashboard.todayGame else { return }
        let attributes = DawgLiveActivityAttributes(
            playerID: dashboard.catalogEntry.id,
            playerName: dashboard.name,
            teamLogoCode: dashboard.resolvedTeamLogoCode,
            role: dashboard.catalogEntry.role
        )
        let state = contentState(for: dashboard, todayGame: todayGame)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 15))

        if let existing = activeActivity(for: dashboard.catalogEntry.id) {
            Task { await existing.update(content) }
        } else {
            do {
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } catch {
                // Live Activity not started; surface silently — commonly disabled by user.
            }
        }
    }

    func end(for dashboard: PlayerDashboard) {
        guard let activity = activeActivity(for: dashboard.catalogEntry.id) else { return }
        let state = contentState(for: dashboard, todayGame: dashboard.todayGame)
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60 * 30))) }
    }

    func endAll() {
        for activity in Activity<DawgLiveActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func contentState(for dashboard: PlayerDashboard, todayGame: TodayGame?) -> DawgLiveActivityAttributes.ContentState {
        guard let todayGame else {
            return DawgLiveActivityAttributes.ContentState(
                statusLabel: "Scheduled",
                headlineText: "No game info",
                scoreText: "—",
                inningText: nil,
                lineText: nil
            )
        }

        let lineText: String?
        if let firstLog = dashboard.gameLogs.first,
           Self.isToday(firstLog.dateText) {
            lineText = firstLog.line
        } else {
            lineText = nil
        }

        let label: String
        switch todayGame.state {
        case .scheduled: label = "PREGAME"
        case .live: label = "LIVE"
        case .final: label = "FINAL"
        }

        return DawgLiveActivityAttributes.ContentState(
            statusLabel: label,
            headlineText: todayGame.headline,
            scoreText: scoreText(for: todayGame),
            inningText: todayGame.inningText,
            lineText: lineText
        )
    }

    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func isToday(_ dateText: String) -> Bool {
        guard let date = isoDayFormatter.date(from: dateText) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func scoreText(for game: TodayGame) -> String {
        switch game.state {
        case .scheduled:
            return game.startTime.map { date in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeStyle = .short
                return formatter.string(from: date)
            } ?? "Today"
        case .live, .final:
            let home = game.homeScore ?? 0
            let away = game.awayScore ?? 0
            return game.isHome ? "\(home)-\(away)" : "\(away)-\(home)"
        }
    }
}
