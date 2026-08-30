import Foundation
import ActivityKit

/// Stores Live Activity APNs push tokens so a server (or optional webhook)
/// can update Dynamic Island / Lock Screen without the app being open.
enum LiveActivityPushTokenStore {
    private static let tokensKey = "liveActivityPushTokens"
    /// Optional HTTPS endpoint that accepts POST JSON:
    /// `{ "playerID": 123, "activityID": "...", "pushToken": "hex", "playerName": "..." }`
    static let endpointDefaultsKey = "liveActivityPushEndpoint"

    static func save(playerID: Int, activityID: String, tokenHex: String) {
        var map = loadAll()
        map[String(playerID)] = [
            "activityID": activityID,
            "pushToken": tokenHex,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        SharedAppGroup.defaults.set(map, forKey: tokensKey)
    }

    static func remove(playerID: Int) {
        var map = loadAll()
        map.removeValue(forKey: String(playerID))
        SharedAppGroup.defaults.set(map, forKey: tokensKey)
    }

    static func tokenHex(for playerID: Int) -> String? {
        loadAll()[String(playerID)]?["pushToken"]
    }

    static func loadAll() -> [String: [String: String]] {
        SharedAppGroup.defaults.dictionary(forKey: tokensKey) as? [String: [String: String]] ?? [:]
    }

    static var pushEndpoint: URL? {
        // Prefer runtime override (App Group), then Info.plist key for production backends.
        if let raw = SharedAppGroup.defaults.string(forKey: endpointDefaultsKey),
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "LiveActivityPushEndpoint") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        return nil
    }

    static func uploadIfConfigured(playerID: Int, activityID: String, tokenHex: String, playerName: String) async {
        guard let endpoint = pushEndpoint else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "playerID": playerID,
            "activityID": activityID,
            "pushToken": tokenHex,
            "playerName": playerName,
            "app": "FormerDawgs"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }
}

@MainActor
final class DawgLiveActivityManager {
    static let shared = DawgLiveActivityManager()

    private var pushTokenTasks: [String: Task<Void, Never>] = [:]
    private var activityStateTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var activePlayerIDs: [Int] {
        Activity<DawgLiveActivityAttributes>.activities.map(\.attributes.playerID)
    }

    var hasActiveActivities: Bool {
        !Activity<DawgLiveActivityAttributes>.activities.isEmpty
    }

    func activeActivity(for playerID: Int) -> Activity<DawgLiveActivityAttributes>? {
        Activity<DawgLiveActivityAttributes>.activities
            .first { $0.attributes.playerID == playerID }
    }

    /// Re-bind token observers after cold launch so tokens keep flowing to storage/server.
    func restoreObservers() {
        for activity in Activity<DawgLiveActivityAttributes>.activities {
            observe(activity)
        }
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
            observe(existing)
        } else {
            do {
                // `.token` registers for remote APNs updates so Dynamic Island
                // can stay live without the app in the foreground.
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: .token
                )
                observe(activity)
            } catch {
                // Live Activity not started; surface silently — commonly disabled by user.
            }
        }

        // While games are tracked, poll more often so local refresh can fill gaps
        // until a push backend is configured.
        BackgroundRefreshScheduler.shared.schedule(preferFrequent: true)
    }

    func end(for dashboard: PlayerDashboard) {
        guard let activity = activeActivity(for: dashboard.catalogEntry.id) else { return }
        let state = contentState(for: dashboard, todayGame: dashboard.todayGame)
        let content = ActivityContent(state: state, staleDate: nil)
        cancelObservers(activityID: activity.id)
        LiveActivityPushTokenStore.remove(playerID: dashboard.catalogEntry.id)
        Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60 * 30))) }
    }

    func endAll() {
        for activity in Activity<DawgLiveActivityAttributes>.activities {
            cancelObservers(activityID: activity.id)
            LiveActivityPushTokenStore.remove(playerID: activity.attributes.playerID)
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Pull fresh dashboards for every tracked Live Activity and push content updates.
    /// Used by background refresh as a local stand-in when remote push isn't configured.
    func refreshAllActiveFromNetwork() async {
        let activities = Activity<DawgLiveActivityAttributes>.activities
        guard !activities.isEmpty else { return }

        let service = PlayerService()
        for activity in activities {
            let playerID = activity.attributes.playerID
            let player = PlayerCatalog.player(for: playerID)
            guard let result = try? await service.fetchDashboardWithOrigin(for: player, forceRefresh: true) else {
                continue
            }
            let dashboard = result.dashboard
            PlayerRuntimeStore.saveOverride(for: dashboard)

            if dashboard.todayGame?.state == .final {
                end(for: dashboard)
            } else if dashboard.todayGame != nil {
                startOrUpdate(for: dashboard)
            }
        }
    }

    private func observe(_ activity: Activity<DawgLiveActivityAttributes>) {
        let activityID = activity.id
        let playerID = activity.attributes.playerID
        let playerName = activity.attributes.playerName

        if pushTokenTasks[activityID] == nil {
            pushTokenTasks[activityID] = Task { [weak self] in
                for await tokenData in activity.pushTokenUpdates {
                    guard !Task.isCancelled else { break }
                    let hex = tokenData.map { String(format: "%02x", $0) }.joined()
                    LiveActivityPushTokenStore.save(
                        playerID: playerID,
                        activityID: activityID,
                        tokenHex: hex
                    )
                    await LiveActivityPushTokenStore.uploadIfConfigured(
                        playerID: playerID,
                        activityID: activityID,
                        tokenHex: hex,
                        playerName: playerName
                    )
                    _ = self
                }
            }
        }

        if activityStateTasks[activityID] == nil {
            activityStateTasks[activityID] = Task { [weak self] in
                for await state in activity.activityStateUpdates {
                    guard !Task.isCancelled else { break }
                    if state == .ended || state == .dismissed {
                        LiveActivityPushTokenStore.remove(playerID: playerID)
                        self?.cancelObservers(activityID: activityID)
                    }
                }
            }
        }
    }

    private func cancelObservers(activityID: String) {
        pushTokenTasks[activityID]?.cancel()
        pushTokenTasks[activityID] = nil
        activityStateTasks[activityID]?.cancel()
        activityStateTasks[activityID] = nil
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

    private static func isToday(_ dateText: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateText) else { return false }
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
