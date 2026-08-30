import SwiftUI

@main
struct FormerDawgsApp: App {
    init() {
        CloudSyncStore.syncFromCloud()
        CloudSyncStore.startObserving()
        let question = TriviaCatalog.dailyQuestion(for: Date())
        let instance = TriviaCatalog.instance(for: question)
        CloudSyncStore.pushTodayTrivia(
            prompt: question.prompt,
            choices: instance.choices,
            answer: question.answer,
            category: question.category
        )
        BackgroundRefreshScheduler.shared.register()
        BackgroundRefreshScheduler.shared.schedule(
            preferFrequent: DawgLiveActivityManager.shared.hasActiveActivities
        )
        DawgLiveActivityManager.shared.restoreObservers()
        Task {
            await DawgPushNotifier.shared.requestPermission()
            await DawgPushNotifier.shared.scheduleTriviaReminderIfNeeded()
        }
        Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await DraftWatcher.shared.checkForNewPicks()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 980, height: 1280)
    }
}
