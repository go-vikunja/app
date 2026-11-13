import SwiftUI
import WidgetKit

/// The app reloads widgets by these kinds.
enum WidgetKinds {
  static let tasks = "VikunjaTasks"
  static let quickAdd = "VikunjaQuickAdd"
}

@main
struct VikunjaWidgetsBundle: WidgetBundle {
  var body: some Widget {
    TasksWidget()
    QuickAddWidget()
  }
}
