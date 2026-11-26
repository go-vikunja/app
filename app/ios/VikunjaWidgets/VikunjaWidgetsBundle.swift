import SwiftUI
import WidgetKit

@main
struct VikunjaWidgetsBundle: WidgetBundle {
  var body: some Widget {
    TasksWidget()
    QuickAddWidget()
  }
}
