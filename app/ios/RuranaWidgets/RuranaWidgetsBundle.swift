import SwiftUI
import WidgetKit

/// The app reloads widgets by these kinds.
enum WidgetKinds {
  static let tasks = "RuranaTasks"
  static let quickAdd = "RuranaQuickAdd"
}

@main
struct RuranaWidgetsBundle: WidgetBundle {
  var body: some Widget {
    TasksWidget()
    QuickAddWidget()
  }
}
