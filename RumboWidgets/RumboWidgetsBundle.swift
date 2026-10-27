import SwiftUI
import WidgetKit

@main
struct RumboWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RumboHomeWidget()
        RumboLockScreenWidget()
        RumboTimerLiveActivity()
    }
}
