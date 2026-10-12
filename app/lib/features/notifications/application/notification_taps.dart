import 'dart:async';

/// Where taps on notifications come from: the plugin's
/// `onDidReceiveNotificationResponse` while the app runs and
/// `getNotificationAppLaunchDetails()` for the tap that started it.
abstract interface class NotificationTapSource {
  /// The payload JSON of every tapped notification, actions excluded.
  Stream<String> get taps;

  /// The payload of the notification that launched the app, or null.
  Future<String?> launchPayload();
}

/// The gateway's tap callback feeds [add]; [launchPayload] is answered by
/// the plugin's launch details.
final class NotificationTaps implements NotificationTapSource {
  new({Future<String?> Function()? launchPayload})
    : _launchPayload = launchPayload ?? (() async => null);

  final Future<String?> Function() _launchPayload;
  final _taps = StreamController<String>.broadcast();

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() => _launchPayload();

  void add(String payload) {
    if (!_taps.isClosed) _taps.add(payload);
  }

  Future<void> dispose() => _taps.close();
}
