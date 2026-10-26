import SwiftUI
import WidgetKit

@main
struct RumboWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DiagnosticsWidget()
        RumboTimerLiveActivity()
    }
}
