import AVFoundation
import Flutter
import ImageIO
import UIKit
import UniformTypeIdentifiers
import flutter_local_notifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Must equal `BackgroundTasks.sync` in Dart and the entry of
  /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
  static let backgroundSyncTask = "dev.coderoftime.rurana.sync"

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
  @MainActor
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "dev.coderoftime.rurana/device", binaryMessenger: messenger)
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

/// Takes the location out of a picked photo or video in place, as `LocationRemoval.kt` does on
/// Android, without encoding a JPEG, HEIC or video again. A file without a location stays
/// untouched.
private enum LocationRemoval {
  enum Failure: Error {
    case unreadable
    case notCopied
    case locationKept
    case notExported
  }

  static func remove(from url: URL, completion: @escaping (Error?) -> Void) {
    guard let type = UTType(filenameExtension: url.pathExtension) else {
      completion(nil)
      return
    }
    if type.conforms(to: .image) {
      do {
        try removeFromImage(at: url)
        completion(nil)
      } catch {
        completion(error)
      }
    } else if type.conforms(to: .movie) {
      removeFromVideo(at: url, type: type, completion: completion)
    } else {
      completion(nil)
    }
  }

  private static func removeFromImage(at url: URL) throws {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let type = CGImageSourceGetType(source)
    else { throw Failure.unreadable }
    guard hasLocation(source) else { return }
    let count = CGImageSourceGetCount(source)
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, type, count, nil) else {
      throw Failure.notCopied
    }
    if UTType(type as String) == .png {
      // Image I/O's lossless copy keeps a PNG's location, and PNG loses nothing when written again.
      for index in 0..<count {
        CGImageDestinationAddImageFromSource(
          destination, source, index, [kCGImagePropertyGPSDictionary: kCFNull] as CFDictionary)
      }
      guard CGImageDestinationFinalize(destination) else { throw Failure.notCopied }
    } else {
      // Without the metadata given, a JPEG's copy loses its orientation and a HEIC's keeps its
      // location.
      var options: [CFString: Any] = [kCGImageMetadataShouldExcludeGPS: true]
      if let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) {
        options[kCGImageDestinationMetadata] = withoutLocation(metadata)
      }
      var error: Unmanaged<CFError>?
      guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, &error)
      else { throw error?.takeRetainedValue() ?? Failure.notCopied }
    }
    guard let copy = CGImageSourceCreateWithData(data, nil), !hasLocation(copy) else {
      throw Failure.locationKept
    }
    try data.write(to: url, options: .atomic)
  }

  private static func hasLocation(_ source: CGImageSource) -> Bool {
    (0..<CGImageSourceGetCount(source)).contains { index in
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
      guard properties?[kCGImagePropertyGPSDictionary] == nil else { return true }
      guard let metadata = CGImageSourceCopyMetadataAtIndex(source, index, nil) else {
        return false
      }
      return !locationTags(metadata).isEmpty
    }
  }

  private static func withoutLocation(_ metadata: CGImageMetadata) -> CGImageMetadata {
    guard let copy = CGImageMetadataCreateMutableCopy(metadata) else { return metadata }
    for path in locationTags(metadata) {
      CGImageMetadataRemoveTagWithPath(copy, nil, path as CFString)
    }
    return copy
  }

  /// The EXIF GPS tags, whether the file keeps them in EXIF or in XMP.
  private static func locationTags(_ metadata: CGImageMetadata) -> [String] {
    let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] ?? []
    return tags.compactMap { tag in
      guard
        CGImageMetadataTagCopyNamespace(tag) as String? == kCGImageMetadataNamespaceExif as String,
        let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
        let name = CGImageMetadataTagCopyName(tag) as String?, name.hasPrefix("GPS")
      else { return nil }
      return "\(prefix):\(name)"
    }
  }

  private static func removeFromVideo(
    at url: URL, type: UTType, completion: @escaping (Error?) -> Void
  ) {
    let asset = AVURLAsset(url: url)
    guard asset.metadata.contains(where: isLocation) else {
      completion(nil)
      return
    }
    let fileType = AVFileType(rawValue: type.identifier)
    guard
      let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough),
      session.supportedFileTypes.contains(fileType)
    else {
      completion(Failure.notExported)
      return
    }
    let output = url.deletingLastPathComponent()
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(url.pathExtension)
    session.outputURL = output
    session.outputFileType = fileType
    session.metadataItemFilter = .forSharing()
    session.exportAsynchronously {
      do {
        guard session.status == .completed else { throw session.error ?? Failure.notExported }
        guard !AVURLAsset(url: output).metadata.contains(where: isLocation) else {
          throw Failure.locationKept
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: output)
        completion(nil)
      } catch {
        try? FileManager.default.removeItem(at: output)
        completion(error)
      }
    }
  }

  private static func isLocation(_ item: AVMetadataItem) -> Bool {
    item.commonKey == .commonKeyLocation
      || item.identifier == .quickTimeUserDataLocationISO6709
      || item.identifier?.rawValue.lowercased().contains("location") == true
  }
}
