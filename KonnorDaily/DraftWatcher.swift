import Foundation
import UserNotifications

@MainActor
final class DraftWatcher {
    static let shared = DraftWatcher()

    private let service = DraftService()
    private static let notifiedKey = "drafteeNotifiedIDs"
    private static let lastCheckKey = "drafteeLastCheckedAt"

    private init() {}

    var yearsToWatch: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return [currentYear, currentYear - 1]
    }

    func checkForNewPicks() async {
        var newlyAdded: [DynamicDraftee] = []
        for year in yearsToWatch {
            if let picks = try? await service.fetchMSUPicks(year: year) {
                newlyAdded.append(contentsOf: DynamicDrafteeStore.upsert(picks))
            }
            if let freeAgents = try? await service.fetchMSUUndraftedFreeAgents(year: year) {
                newlyAdded.append(contentsOf: DynamicDrafteeStore.upsert(freeAgents))
            }
        }
        SharedAppGroup.defaults.set(Date(), forKey: Self.lastCheckKey)
        await notify(newlyAdded)
    }

    private func notify(_ draftees: [DynamicDraftee]) async {
        guard !draftees.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        var alreadyNotified = Set(SharedAppGroup.defaults.stringArray(forKey: Self.notifiedKey) ?? [])

        for draftee in draftees {
            let key = "draft-\(draftee.draftYear)-\(draftee.id)"
            guard !alreadyNotified.contains(key) else { continue }

            let content = UNMutableNotificationContent()
            content.title = draftee.wasUndraftedFreeAgent
                ? "Bulldog Signed! \u{1F415} \u{26BE}"
                : "Bulldog Drafted! \u{1F415} \u{26BE}"
            content.body = "\(draftee.fullName) — \(draftee.pickHeadline)"
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: key, content: content, trigger: trigger)
            do {
                try await center.add(request)
                alreadyNotified.insert(key)
            } catch {
                continue
            }
        }

        SharedAppGroup.defaults.set(Array(alreadyNotified), forKey: Self.notifiedKey)
    }
}
