import Flutter
import UIKit
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
  }
}
