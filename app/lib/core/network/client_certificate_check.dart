import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart'
    show mentionsClientCertificateRefusal;
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/network/profile_http_client.dart';

/// A TLS 1.3 server refuses a client certificate only after the client
/// finished its handshake, so a request or an upgrade just sees the
/// connection end; so do a stale keep-alive connection and a network
/// change. A second handshake that sends no HTTP tells them apart: a server
/// that refuses the certificate hangs up on it at once, a healthy one
/// waits for a request. An answer is kept for 10 s per origin.
final class ClientCertificateRefusalCheck {
  new(
    this._log, {
    this.timeout = const Duration(seconds: 5),
    this.wait = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const _validFor = Duration(seconds: 10);

  final Logger _log;
  final DateTime Function() _clock;

  /// For the TCP connect and handshake.
  final Duration timeout;

  /// How long to wait after the handshake for the server to hang up.
  final Duration wait;

  final _checked = <OriginKey, (DateTime, bool)>{};

  /// [context] is the one the failed connection used.
  Future<bool> refused(NetworkProfile profile, SecurityContext context) async {
    final origin = profile.origin;
    final now = _clock();
    if (_checked[origin] case (final checkedAt, final refused)
        when now.difference(checkedAt) < _validFor) {
      return refused;
    }
    final refused = await _handshake(profile, context);
    _checked[origin] = (_clock(), refused);
    return refused;
  }

  Future<bool> _handshake(
    NetworkProfile profile,
    SecurityContext context,
  ) async {
    final origin = profile.origin;
    // `timeout` bounds only the TCP connect, not the handshake.
    final connecting = SecureSocket.connect(
      origin.host,
      origin.port,
      context: context,
      onBadCertificate: switch (profile.pin) {
        final pin? => pinnedSocketCheck(origin, pin.sha256),
        null => null,
      },
      timeout: timeout,
    );
    final SecureSocket socket;
    try {
      socket = await connecting.timeout(timeout);
    } on TimeoutException {
      unawaited(
        connecting.then((orphan) => orphan.destroy(), onError: (Object _) {}),
      );
      _log.fine('Client-certificate check inconclusive: TimeoutException');
      return false;
    } on HandshakeException catch (error) {
      return mentionsClientCertificateRefusal('$error');
    } on Object catch (error) {
      _log.fine('Client-certificate check inconclusive: ${error.runtimeType}');
      return false;
    }
    final ended = Completer<bool>();
    final subscription = socket.listen(
      (_) {
        if (!ended.isCompleted) ended.complete(false);
      },
      onError: (Object _) {
        if (!ended.isCompleted) ended.complete(true);
      },
      onDone: () {
        if (!ended.isCompleted) ended.complete(true);
      },
      cancelOnError: true,
    );
    try {
      return await ended.future.timeout(wait, onTimeout: () => false);
    } finally {
      unawaited(subscription.cancel());
      socket.destroy();
    }
  }
}
