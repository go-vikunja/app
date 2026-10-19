import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A frame the server sent over the realtime socket.
@immutable
sealed class RealtimeMessage {
  const new();
}

final class RealtimeAuthSucceeded extends RealtimeMessage {
  const new();
}

/// [event] names the refused subscription of an [invalidEvent].
final class RealtimeError extends RealtimeMessage {
  const new(this.code, {this.event});

  static const invalidToken = 'invalid_token';
  static const authRequired = 'auth_required';
  static const invalidEvent = 'invalid_event';

  /// One of the constants above or a code this client does not know.
  final String code;
  final String? event;

  @override
  bool operator ==(Object other) =>
      other is RealtimeError && other.code == code && other.event == event;

  @override
  int get hashCode => Object.hash(code, event);

  @override
  String toString() =>
      'RealtimeError($code${event == null ? '' : ', event: $event'})';
}

final class RealtimeNotification extends RealtimeMessage {
  const new(this.notification);

  final ServerNotification notification;

  @override
  bool operator ==(Object other) =>
      other is RealtimeNotification && other.notification == notification;

  @override
  int get hashCode => notification.hashCode;

  // The payload holds task titles and comments, which must not reach logs.
  @override
  String toString() =>
      'RealtimeNotification(${notification.id}, ${notification.name})';
}

/// Anything else, including frames that are not JSON. Ignored.
final class RealtimeUnknown extends RealtimeMessage {
  const new();
}
