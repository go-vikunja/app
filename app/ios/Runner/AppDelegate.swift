import Flutter
import UIKit
import UniformTypeIdentifiers
import flutter_local_notifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Must equal `BackgroundTasks.sync` in Dart and the entry of
  /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
  static let backgroundSyncTask = "dev.coderoftime.vikunja.sync"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications receives taps and actions through the
    // delegate, including the one that launched the app.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // BGTaskScheduler delivers a task only to a launch handler registered
    // before launching ends, and a background launch connects no scene, so
    // the engine the plugin starts for the sync gets its plugins from here.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: AppDelegate.backgroundSyncTask,
      earliestBeginInSeconds: NSNumber(value: 30 * 60)
    )
    WorkmanagerPlugin.registerLaunchHandlers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // The engine the plugin starts for a notification action that shows no
    // UI needs the plugins registered too (database, preferences, network).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    DeviceChannel.register(with: engineBridge.applicationRegistrar.messenger())
  }
}

/// The app's own calls on the UI engine (lib/core/platform/device_channel.dart);
/// the background and notification engines do not get it.
private enum DeviceChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "dev.coderoftime.vikunja/device", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "excludeFromBackup":
        guard let paths = arguments?["paths"] as? [String] else {
          result(FlutterError(code: "invalid_arguments", message: "paths is missing", details: nil))
          return
        }
        result(DeviceChannel.excludeFromBackup(paths))
      case "copySensitive":
        guard let text = arguments?["text"] as? String else {
          result(FlutterError(code: "invalid_arguments", message: "text is missing", details: nil))
          return
        }
        // Not to other devices through Universal Clipboard, and gone after two minutes.
        UIPasteboard.general.setItems(
          [[UTType.utf8PlainText.identifier: text]],
          options: [.localOnly: true, .expirationDate: Date(timeIntervalSinceNow: 120)])
        result(nil)
      case "openAppSettings":
        // The app's page in Settings, with its Language entry.
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url) { opened in result(opened) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Creates each folder when missing. A restore or a move to another device clears the flag,
  /// so the app sets it at every start. A failure names its type only, never a path.
  private static func excludeFromBackup(_ paths: [String]) -> FlutterError? {
    var failure: Error?
    for path in paths {
      var url = URL(fileURLWithPath: path, isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
      } catch {
        failure = failure ?? error
      }
    }
    guard let failure else { return nil }
    return FlutterError(
      code: "exclude_failed", message: String(describing: type(of: failure)), details: nil)
  }
}
