import WidgetKit
import SwiftUI

@main
struct FormerDawgsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodaysDawgsWidget()
        FavoritePlayerWidget()
        NewsWidget()
        FormerDawgsWidget()
        DawgLiveActivityWidget()
    }
}
