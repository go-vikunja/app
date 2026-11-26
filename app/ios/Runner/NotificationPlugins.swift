import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

/// The plugins of an engine without UI: workmanager's background sync and the engine
/// flutter_local_notifications starts for a Done or Snooze. Every plugin instance a registrar
/// adds as an application delegate answers every notification response, so
/// flutter_local_notifications there is kept from it: the UI engine's instance or the one made
/// at launch (`LaunchNotificationPlugin`) answers alone (`NotificationResponses`).
enum BackgroundPlugins {
  static func register(with registry: FlutterPluginRegistry) {
    let filter = ApplicationDelegateFilter()
    GeneratedPluginRegistrant.register(with: WithoutNotificationDelegate(registry, filter))
    assert(filter.sawNotificationPlugin, "flutter_local_notifications registers by another key")
  }
}

private final class WithoutNotificationDelegate: NSObject, FlutterPluginRegistry {
  private let registry: FlutterPluginRegistry
  private let filter: ApplicationDelegateFilter

  init(_ registry: FlutterPluginRegistry, _ filter: ApplicationDelegateFilter) {
    self.registry = registry
    self.filter = filter
  }

  func registrar(forPlugin pluginKey: String) -> FlutterPluginRegistrar? {
    guard let registrar = registry.registrar(forPlugin: pluginKey) else { return nil }
    return filter.keepsApplicationDelegate(pluginKey)
      ? registrar : WithoutApplicationDelegate(registrar)
  }

  func hasPlugin(_ pluginKey: String) -> Bool {
    registry.hasPlugin(pluginKey)
  }

  func valuePublished(byPlugin pluginKey: String) -> NSObject? {
    registry.valuePublished(byPlugin: pluginKey)
  }
}

private final class WithoutApplicationDelegate: NSObject, FlutterPluginRegistrar {
  private let registrar: FlutterPluginRegistrar

  init(_ registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  var viewController: UIViewController? { registrar.viewController }

  func messenger() -> FlutterBinaryMessenger { registrar.messenger() }

  func textures() -> FlutterTextureRegistry { registrar.textures() }

  func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {
    registrar.register(factory, withId: factoryId)
  }

  func register(
    _ factory: FlutterPlatformViewFactory, withId factoryId: String,
    gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicy
  ) {
    registrar.register(
      factory, withId: factoryId, gestureRecognizersBlockingPolicy: gestureRecognizersBlockingPolicy
    )
  }

  func publish(_ value: NSObject) { registrar.publish(value) }

  func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {
    registrar.addMethodCallDelegate(delegate, channel: channel)
  }

  func addApplicationDelegate(_ delegate: FlutterPlugin) {}

  func addSceneDelegate(_ delegate: FlutterSceneLifeCycleDelegate) {
    registrar.addSceneDelegate(delegate)
  }

  func lookupKey(forAsset asset: String) -> String { registrar.lookupKey(forAsset: asset) }

  func lookupKey(forAsset asset: String, fromPackage package: String) -> String {
    registrar.lookupKey(forAsset: asset, fromPackage: package)
  }

  func valuePublished(byPlugin pluginKey: String) -> NSObject? {
    registrar.valuePublished(byPlugin: pluginKey)
  }
}

/// A flutter_local_notifications instance without an engine, for a Done or Snooze that arrives
/// while no UI engine runs. Its own channel goes nowhere: Dart never initializes it, so it only
/// hands an action to the plugin's background engine, which it starts as the UI engine's
/// instance would. It never becomes an application delegate.
final class LaunchNotificationPlugin {
  /// Where the plugin keeps the actions that open the app (an internal of 22.3.2, pinned by
  /// app/test/app/widget_extension_contract_test.dart).
  static let foregroundActionsKey =
    "dexterous.com/flutter/local_notifications/foreground_action_identifiers"

  private let registrar = DetachedRegistrar()

  init() {
    FlutterLocalNotificationsPlugin.register(with: registrar)
  }

  func receive(
    _ center: UNUserNotificationCenter, _ response: UNNotificationResponse,
    _ completionHandler: @escaping () -> Void
  ) {
    guard let plugin = registrar.plugin else { return completionHandler() }
    plugin.userNotificationCenter?(
      center, didReceive: response, withCompletionHandler: completionHandler)
  }
}

private final class DetachedRegistrar: NSObject, FlutterPluginRegistrar, FlutterBinaryMessenger,
  FlutterTextureRegistry
{
  private(set) var plugin: FlutterPlugin?

  var viewController: UIViewController? { nil }

  func messenger() -> FlutterBinaryMessenger { self }

  func textures() -> FlutterTextureRegistry { self }

  func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {}

  func register(
    _ factory: FlutterPlatformViewFactory, withId factoryId: String,
    gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicy
  ) {}

  func publish(_ value: NSObject) {}

  func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {
    plugin = delegate
  }

  func addApplicationDelegate(_ delegate: FlutterPlugin) {
    plugin = delegate
  }

  func addSceneDelegate(_ delegate: FlutterSceneLifeCycleDelegate) {}

  func lookupKey(forAsset asset: String) -> String { asset }

  func lookupKey(forAsset asset: String, fromPackage package: String) -> String { asset }

  func valuePublished(byPlugin pluginKey: String) -> NSObject? { nil }

  func send(onChannel channel: String, message: Data?) {}

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    callback?(nil)
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection { 0 }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  func register(_ texture: FlutterTexture) -> Int64 { 0 }

  func textureFrameAvailable(_ textureId: Int64) {}

  func unregisterTexture(_ textureId: Int64) {}
}
