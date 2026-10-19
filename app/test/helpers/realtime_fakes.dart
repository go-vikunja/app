import 'dart:async';

import 'package:vikunja_api/vikunja_api.dart';

/// Hands out [FakeRealtimeSocket]s, or refuses the upgrade while [accepts]
/// is false. [onConnect] replaces the outcome of the next connects, e.g. to
/// throw or to hold a connect open.
final class FakeRealtimeConnector implements RealtimeConnector {
  new({this.accepts = true, this.refusedStatus = 404});

  bool accepts;
  int refusedStatus;

  /// Every socket answers its authentications with success while set.
  bool autoAuthenticate = true;

  Future<RealtimeSocket> Function(Uri url)? onConnect;

  final List<Uri> urls = [];
  final List<Map<String, String>> headers = [];
  final List<FakeRealtimeSocket> sockets = [];

  int get connectCalls => urls.length;

  FakeRealtimeSocket get lastSocket => sockets.last;

  @override
  Future<RealtimeSocket> connect(
    Uri url, {
    Map<String, String> headers = const {},
  }) async {
    urls.add(url);
    this.headers.add(headers);
    if (onConnect case final handler?) return await handler(url);
    if (!accepts) throw RealtimeUpgradeRefused(refusedStatus);
    return open();
  }

  /// A socket as [connect] hands it out, recorded in [sockets].
  FakeRealtimeSocket open() {
    final socket = FakeRealtimeSocket(autoAuthenticate: autoAuthenticate);
    sockets.add(socket);
    return socket;
  }
}

/// A socket the test plays the server of: [push] delivers a message,
/// [serverClose] closes with a code (null: dropped without a close frame).
/// What the client sent is recorded.
final class FakeRealtimeSocket implements RealtimeSocket {
  new({this.autoAuthenticate = true});

  bool autoAuthenticate;

  /// [close] only records the code; the stream ends with [serverClose],
  /// like a socket whose server's close frame is still on its way.
  bool awaitsServerClose = false;
  final _messages = StreamController<RealtimeMessage>();

  final List<String> tokens = [];
  final List<String> subscriptions = [];

  /// `auth` and `subscribe <event>`, in order; never the token itself.
  final List<String> sent = [];

  /// The code the client closed with; null while it has not.
  int? closedWith;
  int? _closeCode;
  String? _closeReason;

  bool get isClosed => _messages.isClosed;

  @override
  Stream<RealtimeMessage> get messages => _messages.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  void authenticate(String token) {
    tokens.add(token);
    sent.add('auth');
    if (autoAuthenticate) push(const RealtimeAuthSucceeded());
  }

  @override
  void subscribe(String event) {
    subscriptions.add(event);
    sent.add('subscribe $event');
  }

  void push(RealtimeMessage message) {
    if (!_messages.isClosed) _messages.add(message);
  }

  void serverClose(int? code, [String? reason]) {
    if (_messages.isClosed) return;
    _closeCode = code;
    _closeReason = reason;
    unawaited(_messages.close());
  }

  @override
  Future<void> close([int code = 1000]) async {
    if (_messages.isClosed) return;
    closedWith ??= code;
    if (awaitsServerClose) return;
    _closeCode = code;
    unawaited(_messages.close());
  }
}
