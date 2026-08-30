import Foundation
import BackgroundTasks
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class BackgroundRefreshScheduler {
    static let shared = BackgroundRefreshScheduler()
    static let taskIdentifier = "com.cwdawg.formerdawgs.refresh"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handle(task)
        }
    }

    func schedule(preferFrequent: Bool = false) {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        // When Live Activities are tracking live games, ask iOS to wake us sooner
        // so Lock Screen content can refresh even without a push backend.
        let interval: TimeInterval
        if preferFrequent || DawgLiveActivityManager.shared.hasActiveActivities {
            interval = 60 * 15
        } else {
            interval = 60 * 60 * 4
        }
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) {
        let frequent = DawgLiveActivityManager.shared.hasActiveActivities
        schedule(preferFrequent: frequent)
        let operation = Task {
            await DawgPushNotifier.shared.runPoll()
            // Keep Dynamic Island / Live Activities current from the device when
            // remote ActivityKit push isn't wired (or between pushes).
            await DawgLiveActivityManager.shared.refreshAllActiveFromNetwork()
        }
        task.expirationHandler = { operation.cancel() }
        Task {
            _ = await operation.value
            task.setTaskCompleted(success: true)
        }
    }
}

@MainActor
final class DawgPushNotifier {
    static let shared = DawgPushNotifier()
    private static let lastNotifiedKey = "dawgLastNotifiedEventIDs"
    private static let maxStoredIDs = 120
    private static let triviaReminderID = "trivia-reminder-today"

    private init() {}

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        if (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) == true {
            // Permission granted.
        }
    }

    func runPoll() async {
        await DraftWatcher.shared.checkForNewPicks()
        await refreshHomeAndNotify()
        await scheduleTriviaReminderIfNeeded()
    }

    func refreshHomeAndNotify() async {
        let service = PlayerService()
        let summary = await service.fetchHomeSummary(players: PlayerCatalog.players, forceRefresh: true)

        let favoriteIDs = FavoritePlayerStore.ids(
            from: SharedAppGroup.defaults.string(forKey: "favoritePlayerIDs") ?? ""
        )

        var events: [PendingNotification] = []

        // First pitch / game day for favorites
        for dashboard in summary.tonightScoreboard {
            let playerID = dashboard.catalogEntry.id
            let isPriority = favoriteIDs.contains(playerID)
            guard isPriority, let game = dashboard.todayGame else { continue }

            switch game.state {
            case .scheduled:
                events.append(PendingNotification(
                    id: "\(playerID)-FIRSTPITCH-\(Self.dayKey())",
                    title: "\(dashboard.name) plays tonight",
                    body: "\(game.headline) · \(game.statusText)",
                    isFavorite: true
                ))
            case .live:
                events.append(PendingNotification(
                    id: "\(playerID)-LIVE-\(Self.dayKey())",
                    title: "\(dashboard.name) is LIVE",
                    body: "\(game.headline) · \(game.statusText)",
                    isFavorite: true
                ))
            case .final:
                break
            }
        }

        // Box-score moments
        for dashboard in summary.todaysActivePlayers {
            let playerID = dashboard.catalogEntry.id
            let isFavorite = favoriteIDs.contains(playerID)
            guard let firstLog = dashboard.gameLogs.first else { continue }

            if dashboard.catalogEntry.kind == .hitter, (firstLog.homeRuns ?? 0) > 0 {
                events.append(PendingNotification(
                    id: "\(playerID)-HR-\(firstLog.dateText)",
                    title: "\(dashboard.name) went deep",
                    body: "\(firstLog.line) \(firstLog.opponentText)",
                    isFavorite: isFavorite
                ))
            }
            if dashboard.catalogEntry.kind == .hitter, (firstLog.hits ?? 0) >= 2 {
                events.append(PendingNotification(
                    id: "\(playerID)-MH-\(firstLog.dateText)",
                    title: "\(dashboard.name) multi-hit night",
                    body: "\(firstLog.line) \(firstLog.opponentText)",
                    isFavorite: isFavorite
                ))
            }
            if dashboard.catalogEntry.kind == .hitter, (firstLog.hits ?? 0) >= 3 {
                events.append(PendingNotification(
                    id: "\(playerID)-3H-\(firstLog.dateText)",
                    title: "\(dashboard.name) is on fire",
                    body: "\(firstLog.hits ?? 0) hits — \(firstLog.line)",
                    isFavorite: true
                ))
            }
            if dashboard.catalogEntry.kind == .pitcher, (firstLog.strikeOuts ?? 0) >= 8 {
                events.append(PendingNotification(
                    id: "\(playerID)-K-\(firstLog.dateText)",
                    title: "\(dashboard.name) dominated",
                    body: "\(firstLog.line) \(firstLog.opponentText)",
                    isFavorite: isFavorite
                ))
            }
            if dashboard.catalogEntry.kind == .pitcher,
               let ip = firstLog.inningsPitched, ip >= 5,
               (firstLog.strikeOuts ?? 0) >= 5 {
                events.append(PendingNotification(
                    id: "\(playerID)-QS-\(firstLog.dateText)",
                    title: "Quality start for \(dashboard.name)",
                    body: "\(firstLog.line) \(firstLog.opponentText)",
                    isFavorite: isFavorite
                ))
            }
            if dashboard.catalogEntry.kind == .pitcher, (dashboard.seasonStat?.stat.saves ?? 0) > 0,
               (firstLog.inningsPitched ?? 0) > 0 {
                events.append(PendingNotification(
                    id: "\(playerID)-SV-\(firstLog.dateText)",
                    title: "Save line for \(dashboard.name)",
                    body: "\(firstLog.line) \(firstLog.opponentText)",
                    isFavorite: isFavorite
                ))
            }
        }

        // Promotions / call-ups / transactions (priority if favorite)
        for highlight in summary.transactionTimeline {
            let playerID = highlight.player.id
            let isPriority = favoriteIDs.contains(playerID)
            let titleLower = highlight.story.title.lowercased()
            let isPromotion = titleLower.contains("promot")
                || titleLower.contains("call")
                || titleLower.contains("recalled")
                || titleLower.contains("debut")

            events.append(PendingNotification(
                id: "\(playerID)-TX-\(highlight.story.publishedText)",
                title: isPromotion
                    ? "\(highlight.player.displayName) — call-up buzz"
                    : "\(highlight.player.displayName) — transaction",
                body: highlight.story.title,
                isFavorite: isPriority || isPromotion
            ))
        }

        await deliver(events)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "FormerDawgsTodaysDawgsWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FormerDawgsFavoritePlayerWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FormerDawgsNewsWidget")
#endif
    }

    /// Local reminder if daily trivia not answered by evening.
    func scheduleTriviaReminderIfNeeded() async {
        let answered = SharedAppGroup.defaults.string(forKey: "triviaAnsweredDays") ?? ""
        let today = Self.dayKey()
        if answered.split(separator: ",").map(String.init).contains(today) {
            cancelTriviaReminder()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        center.removePendingNotificationRequests(withIdentifiers: [Self.triviaReminderID])

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 0
        guard let fireDate = Calendar.current.date(from: components), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Keep your Bulldog streak"
        content.body = "Tonight's trivia is still open — one question, then you're set."
        content.sound = .default
        content.interruptionLevel = .active

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: Self.triviaReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelTriviaReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.triviaReminderID])
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [Self.triviaReminderID])
    }

    private func deliver(_ events: [PendingNotification]) async {
        guard !events.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        var alreadySent = Set(SharedAppGroup.defaults.stringArray(forKey: Self.lastNotifiedKey) ?? [])

        // Prefer favorites first so we don't blow the delivery budget on noise
        let ordered = events.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
            return lhs.id < rhs.id
        }

        var deliveredThisRun = 0
        let maxPerRun = 8

        for event in ordered where !alreadySent.contains(event.id) {
            guard deliveredThisRun < maxPerRun else { break }
            // Non-favorites only if we still have room after favorites
            if !event.isFavorite && deliveredThisRun >= 4 { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.body
            content.sound = event.isFavorite ? .default : nil
            content.interruptionLevel = event.isFavorite ? .timeSensitive : .active
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
            do {
                try await center.add(request)
                alreadySent.insert(event.id)
                deliveredThisRun += 1
            } catch {
                continue
            }
        }

        if alreadySent.count > Self.maxStoredIDs {
            alreadySent = Set(alreadySent.suffix(Self.maxStoredIDs))
        }
        SharedAppGroup.defaults.set(Array(alreadySent), forKey: Self.lastNotifiedKey)
    }

    private static func dayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private struct PendingNotification {
        let id: String
        let title: String
        let body: String
        let isFavorite: Bool
    }
}
