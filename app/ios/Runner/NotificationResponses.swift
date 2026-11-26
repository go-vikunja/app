import UserNotifications

/// Picks the one flutter_local_notifications instance that answers a notification response, so
/// that each Done or Snooze runs exactly once. The UI engine's instance answers while that engine
/// lives. Without it (iOS launched the app in the background for a Done or Snooze, so no scene
/// connected, or the scene's engine is gone) an action runs through an instance made at launch,
/// which starts the plugin's background engine as the UI engine's would. A tap that opens the
/// app waits for the scene's engine, whose instance tells Dart that it launched the app.
final class NotificationResponses {
  private var waiting: [() -> Void] = []

  func receive(
    action: String, foregroundActions: [String], uiEngineAlive: Bool,
    toUIEngine: @escaping () -> Void, toLaunchPlugin: () -> Void
  ) {
    if uiEngineAlive {
      toUIEngine()
    } else if Self.opensApp(action, foregroundActions: foregroundActions) {
      waiting.append(toUIEngine)
    } else {
      toLaunchPlugin()
    }
  }

  /// A tap on the notification itself or an action that brings the app to the front, unlike
  /// Done or Snooze.
  static func opensApp(_ action: String, foregroundActions: [String]) -> Bool {
    action == UNNotificationDefaultActionIdentifier || foregroundActions.contains(action)
  }

  /// What flutter_local_notifications takes for its own (`isAFlutterLocalNotification`); it
  /// leaves any other response without completing it.
  static func isPluginNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    ["NotificationId", "presentAlert", "presentSound", "presentBadge", "payload"].allSatisfy {
      userInfo[$0] != nil
    }
  }

  /// The completion handler, whichever instance calls it and however often.
  static func once(_ completion: @escaping () -> Void) -> () -> Void {
    var pending: (() -> Void)? = completion
    return {
      let completion = pending
      pending = nil
      completion?()
    }
  }

  func uiEngineRegistered() {
    let replay = waiting
    waiting = []
    replay.forEach { $0() }
  }
}

/// Which plugins of an engine without UI may become application delegates (`BackgroundPlugins`):
/// all but flutter_local_notifications, by the key the generated registrant gives it.
final class ApplicationDelegateFilter {
  static let notificationPluginKey = "FlutterLocalNotificationsPlugin"

  private(set) var sawNotificationPlugin = false

  func keepsApplicationDelegate(_ pluginKey: String) -> Bool {
    guard pluginKey == Self.notificationPluginKey else { return true }
    sawNotificationPlugin = true
    return false
  }
}
