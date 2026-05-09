import SwiftUI

@main
struct KonnorDailyApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        }
        .defaultSize(width: 980, height: 1280)
    }
}
