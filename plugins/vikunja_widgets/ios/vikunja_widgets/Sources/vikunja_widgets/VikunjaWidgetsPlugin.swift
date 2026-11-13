import Flutter
import UIKit
import WidgetKit

/// Runner side only: the widget extension never links Flutter or this plugin.
/// It reports the App Group container and asks WidgetKit to reload; the Dart
/// side does all file work there.
public final class VikunjaWidgetsPlugin: NSObject, FlutterPlugin {
  // Quick add reads a snapshot too (its account's quickAddKey).
  private static let kinds = ["VikunjaTasks", "VikunjaQuickAdd"]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "io.vikunja.vikunja_widgets",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(VikunjaWidgetsPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "directory":
      let arguments = call.arguments as? [String: Any]
      result(directories(appGroup: arguments?["appGroup"] as? String))
    case "update":
      Self.kinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
      result(nil)
    case "updateAll":
      WidgetCenter.shared.reloadAllTimelines()
      result(nil)
    case "configs":
      result([Any]())
    case "canRequestPin", "requestPin":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Nil without the App Group entitlement (a --no-codesign build).
  private func directories(appGroup: String?) -> [String: Any]? {
    guard let appGroup,
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup)
    else { return nil }
    return [
      "widgets": container.appendingPathComponent("widgets", isDirectory: true).path,
      "appGroup": container.path,
    ]
  }
}
