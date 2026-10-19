import 'package:vikunja_api/src/realtime/realtime_message.dart';

/// Vikunja's `/ws` socket: authenticate with a user JWT, subscribe, then
/// receive pushed events. Sending after the socket closed does nothing.
abstract interface class RealtimeSocket {
  static const notificationCreated = 'notification.created';

  /// Single-subscription; done when the socket closes.
  Stream<RealtimeMessage> get messages;

  /// Also re-authenticates an open socket with a refreshed token of the same
  /// session.
  void authenticate(String token);

  /// The server never acknowledges a subscription.
  void subscribe(String event);

  /// Set once [messages] is done; null when the connection dropped without a
  /// close frame.
  int? get closeCode;
  String? get closeReason;

  Future<void> close([int code = 1000]);
}

abstract interface class RealtimeConnector {
  /// Throws [RealtimeUpgradeRefused] for any answer but 101 and otherwise
  /// plain I/O exceptions, never a `VikunjaFailure`: `SocketException`,
  /// `HttpException`, `HandshakeException` (TLS), `TimeoutException`, or
  /// `WebSocketException` for a 101 that is no valid WebSocket handshake.
  Future<RealtimeSocket> connect(
    Uri url, {
    Map<String, String> headers = const {},
  });
}

final class RealtimeUpgradeRefused implements Exception {
  const new(this.statusCode, {this.retryAfter});

  final int statusCode;

  /// Only for a 429.
  final Duration? retryAfter;

  @override
  String toString() =>
      'RealtimeUpgradeRefused($statusCode'
      '${retryAfter == null ? '' : ', retryAfter: $retryAfter'})';
}
