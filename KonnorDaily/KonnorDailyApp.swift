import SwiftUI

@main
struct KonnorDailyApp: App {
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
        BackgroundRefreshScheduler.shared.schedule()
        Task { await DawgPushNotifier.shared.requestPermission() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 980, height: 1280)
    }
}
