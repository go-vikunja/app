import Flutter
import UIKit
import UniformTypeIdentifiers
import flutter_local_notifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Must equal `BackgroundTasks.sync` in Dart and the entry of
  /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
  static let backgroundSyncTask = "io.vikunja.app.sync"

  private let notificationResponses = NotificationResponses()
  private lazy var launchNotificationPlugin = LaunchNotificationPlugin()
  private weak var uiEngine: AnyObject?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS hands a notification response only to the delegate set before
    // launching ends, the Done or Snooze that launched the app included.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // A background launch, for a Done or Snooze as for a BGTaskScheduler
    // task (delivered only to a handler registered before launching ends),
    // connects no scene, so the engines the plugins start get their plugins
    // from here.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      BackgroundPlugins.register(with: registry)
    }
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      BackgroundPlugins.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: AppDelegate.backgroundSyncTask,
      earliestBeginInSeconds: NSNumber(value: 30 * 60)
    )
    WorkmanagerPlugin.registerLaunchHandlers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    DeviceChannel.register(with: engineBridge.applicationRegistrar.messenger())
    uiEngine = engineBridge.pluginRegistry
    notificationResponses.uiEngineRegistered()
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard
      NotificationResponses.isPluginNotification(response.notification.request.content.userInfo)
    else { return completionHandler() }
    let completionHandler = NotificationResponses.once(completionHandler)
    let foregroundActions =
      UserDefaults.standard.stringArray(forKey: LaunchNotificationPlugin.foregroundActionsKey) ?? []
    if !NotificationResponses.opensApp(
      response.actionIdentifier, foregroundActions: foregroundActions)
    {
      ActionTime.begin()
    }
    notificationResponses.receive(
      action: response.actionIdentifier, foregroundActions: foregroundActions,
      uiEngineAlive: uiEngine != nil,
      toUIEngine: {
        super.userNotificationCenter(
          center, didReceive: response, withCompletionHandler: completionHandler)
      },
      toLaunchPlugin: {
        launchNotificationPlugin.receive(center, response, completionHandler)
      })
  }
}

/// Background time for the plugin's engine to record a Done or Snooze: the plugin completes the
/// response at once, and iOS may suspend a process it launched for one right after. Long enough
/// for the engine to start, record the action and drain its 5 s.
@MainActor
private final class ActionTime {
  private var task = UIBackgroundTaskIdentifier.invalid

  static func begin() {
    let time = ActionTime()
    time.task = UIApplication.shared.beginBackgroundTask(withName: "Notification action") {
      MainActor.assumeIsolated { time.end() }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
      MainActor.assumeIsolated { time.end() }
    }
  }

  private func end() {
    guard task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
    task = .invalid
  }
}

/// The app's own calls on the UI engine (lib/core/platform/device_channel.dart);
/// the background and notification engines do not get it.
private enum DeviceChannel {
  @MainActor
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "io.vikunja.app/device", binaryMessenger: messenger)
    let capture = ScreenCapture(channel: channel)
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "setSecure":
        guard let secure = arguments?["secure"] as? Bool else {
          result(
            FlutterError(code: "invalid_arguments", message: "secure is missing", details: nil))
          return
        }
        result(capture.watch(secure))
      case "removeLocation":
        guard let path = arguments?["path"] as? String else {
          result(FlutterError(code: "invalid_arguments", message: "path is missing", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          LocationRemoval.remove(from: URL(fileURLWithPath: path)) { failure in
            DispatchQueue.main.async {
              result(
                failure.map {
                  FlutterError(
                    code: "remove_location_failed", message: String(describing: type(of: $0)),
                    details: nil)
                })
            }
          }
        }
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
      case "backgroundState":
        result(DeviceChannel.backgroundState())
      case "sinceBoot":
        result(DeviceChannel.sinceBoot())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Milliseconds on a clock that goes on while the device sleeps and that the user cannot set,
  /// for the app lock. Not `systemUptime` or `mach_absolute_time`, which stop in sleep.
  private static func sinceBoot() -> Int64 {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let nanos = Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom)
    return Int64(nanos / 1_000_000)
  }

  @MainActor
  private static func backgroundState() -> [String: Any] {
    let refresh =
      switch UIApplication.shared.backgroundRefreshStatus {
      case .available: "available"
      case .denied: "denied"
      case .restricted: "restricted"
      @unknown default: "unknown"
      }
    return [
      "backgroundRefresh": refresh,
      "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
    ]
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

/// iOS cannot keep a window out of a recording or a mirrored display. While Dart holds the window
/// secure (a secret on screen), this tells it whether the screen is captured, and the secret's
/// widget hides it meanwhile.
@MainActor
private final class ScreenCapture {
  // The only strong reference: the engine keeps the channel's handler, not the channel.
  private let channel: FlutterMethodChannel
  private var stopWatching: (@MainActor () -> Void)?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  /// Answers whether the screen is captured now; each change follows as `screenCaptureChanged`.
  func watch(_ secure: Bool) -> Bool {
    stopWatching?()
    stopWatching = nil
    guard secure, let scene = ScreenCapture.scene else { return false }
    if #available(iOS 17.0, *) {
      let registration = scene.registerForTraitChanges([UITraitSceneCaptureState.self]) {
        [weak self] (scene: UIWindowScene, _: UITraitCollection) in
        self?.report(ScreenCapture.isCaptured(scene))
      }
      stopWatching = { [weak scene] in scene?.unregisterForTraitChanges(registration) }
    } else {
      let observer = NotificationCenter.default.addObserver(
        forName: UIScreen.capturedDidChangeNotification, object: scene.screen, queue: .main
      ) { [weak self, weak scene] _ in
        MainActor.assumeIsolated {
          guard let scene else { return }
          self?.report(ScreenCapture.isCaptured(scene))
        }
      }
      stopWatching = { NotificationCenter.default.removeObserver(observer) }
    }
    return ScreenCapture.isCaptured(scene)
  }

  private func report(_ captured: Bool) {
    channel.invokeMethod("screenCaptureChanged", arguments: captured)
  }

  private static var scene: UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
  }

  private static func isCaptured(_ scene: UIWindowScene) -> Bool {
    if #available(iOS 17.0, *) {
      return scene.traitCollection.sceneCaptureState == .active
    }
    return scene.screen.isCaptured
  }
}
