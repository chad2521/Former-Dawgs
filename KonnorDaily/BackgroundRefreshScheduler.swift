import Foundation
import BackgroundTasks
import UserNotifications

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

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 4)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()
        let operation = Task {
            await DawgPushNotifier.shared.runPoll()
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
    private static let maxStoredIDs = 100

    private init() {}

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        if (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) == true {
            // Permission granted.
        }
    }

    func runPoll() async {
        await refreshHomeAndNotify()
    }

    func refreshHomeAndNotify() async {
        let service = PlayerService()
        let summary = await service.fetchHomeSummary(players: PlayerCatalog.players, forceRefresh: true)

        let favoriteIDs = FavoritePlayerStore.ids(
            from: SharedAppGroup.defaults.string(forKey: "favoritePlayerIDs") ?? ""
        )

        var events: [PendingNotification] = []
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
            if dashboard.catalogEntry.kind == .pitcher, (firstLog.strikeOuts ?? 0) >= 8 {
                events.append(PendingNotification(
                    id: "\(playerID)-K-\(firstLog.dateText)",
                    title: "\(dashboard.name) dominated",
                    body: "\(firstLog.line) \(firstLog.opponentText)",
                    isFavorite: isFavorite
                ))
            }
            if dashboard.catalogEntry.kind == .pitcher, (dashboard.seasonStat?.stat.saves ?? 0) > 0,
               (firstLog.inningsPitched ?? 0) > 0 {
                events.append(PendingNotification(
                    id: "\(playerID)-SV-\(firstLog.dateText)",
                    title: "Save opportunity for \(dashboard.name)",
                    body: "\(firstLog.line) \(firstLog.opponentText)",
                    isFavorite: isFavorite
                ))
            }
        }

        for highlight in summary.transactionTimeline {
            let playerID = highlight.player.id
            events.append(PendingNotification(
                id: "\(playerID)-TX-\(highlight.story.publishedText)",
                title: "\(highlight.player.displayName) — transaction",
                body: highlight.story.title,
                isFavorite: favoriteIDs.contains(playerID)
            ))
        }

        await deliver(events)
    }

    private func deliver(_ events: [PendingNotification]) async {
        guard !events.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        var alreadySent = Set(SharedAppGroup.defaults.stringArray(forKey: Self.lastNotifiedKey) ?? [])

        for event in events where !alreadySent.contains(event.id) {
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
            } catch {
                continue
            }
        }

        if alreadySent.count > Self.maxStoredIDs {
            alreadySent = Set(alreadySent.suffix(Self.maxStoredIDs))
        }
        SharedAppGroup.defaults.set(Array(alreadySent), forKey: Self.lastNotifiedKey)
    }

    private struct PendingNotification {
        let id: String
        let title: String
        let body: String
        let isFavorite: Bool
    }
}
