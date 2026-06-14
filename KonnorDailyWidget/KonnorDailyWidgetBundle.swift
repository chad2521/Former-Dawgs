import WidgetKit
import SwiftUI

@main
struct KonnorDailyWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodaysDawgsWidget()
        KonnorDailyWidget()
        DawgLiveActivityWidget()
    }
}
