import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart'
    show mentionsClientCertificateRefusal, preConsentProbeKey;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/network/profile_http_client.dart';
import 'package:vikunja_mobile/core/network/secret_scrubbing.dart';

final _log = Logger('NetworkProfileAdapter');

/// Applies each origin's connection profile below every interceptor, so
/// header values and certificates never reach an object above the
/// transport (network.md §2.1). Origins without a profile go to the
/// platform adapter unchanged; header-only profiles stay on it; a pin, a CA
/// or a client certificate needs dart:io, with one adapter per origin.
final class NetworkProfileAdapter implements HttpClientAdapter {
  new(
    this._platform,
    this._profiles, {
    this.refusalCheckTimeout = const Duration(seconds: 5),
    this.refusalCheckWait = const Duration(seconds: 3),
    DateTime Function()? clock,
    @visibleForTesting
    HttpClientAdapter Function(CreateHttpClient create)? createDartIoAdapter,
  }) : _clock = clock ?? DateTime.now,
       _createDartIoAdapter =
           createDartIoAdapter ??
           ((create) => IOHttpClientAdapter(createHttpClient: create));

  static const _refusalCheckValidFor = Duration(seconds: 10);
  static final _infoPath = RegExp(r'/api/v[12]/info$');

  final HttpClientAdapter _platform;
  final NetworkProfiles _profiles;
  final DateTime Function() _clock;
  final HttpClientAdapter Function(CreateHttpClient create)
  _createDartIoAdapter;

  /// For the TCP connect and handshake of the client-certificate check.
  final Duration refusalCheckTimeout;

  /// How long the check waits after its handshake for the server to hang up.
  final Duration refusalCheckWait;

  final _dartIo = <OriginKey, _IoAdapter>{};
  final _refusalChecks = <OriginKey, (DateTime, bool)>{};
  final _recordedMismatches = <OriginKey, String>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final origin = OriginKey.tryOf(options.uri);
    if (origin == null) {
      return await _platform.fetch(options, requestStream, cancelFuture);
    }
    final NetworkProfile? profile;
    try {
      profile = await _profiles.forOrigin(origin);
    } on Object catch (error) {
      if (!_isConnectionSettingsError(error)) rethrow;
      throw _connectionError(options, error);
    }
    // Recording again once the stored record is gone ("Keep current").
    if (profile?.lastPinMismatch == null) _recordedMismatches.remove(origin);
    if (!origin.isSecure && !(profile?.hasCleartextConsent ?? false)) {
      if (!_isPreConsentProbe(options)) {
        throw _connectionError(
          options,
          CleartextBlockedException(origin.toString()),
        );
      }
      _dropDartIo(origin);
      return await _platform.fetch(options, requestStream, cancelFuture);
    }
    if (profile == null || (!profile.hasHeaders && !profile.needsDartIo)) {
      _dropDartIo(origin);
      return await _platform.fetch(options, requestStream, cancelFuture);
    }
    final sent = _withProfileHeaders(options, profile.headers);
    try {
      if (!profile.needsDartIo) {
        _dropDartIo(origin);
        return await _platform.fetch(sent, requestStream, cancelFuture);
      }
      return await _fetchDartIo(profile, sent, requestStream, cancelFuture);
    } on Object catch (error, stackTrace) {
      throw _scrubbed(error, stackTrace, options, profile);
    }
  }

  @override
  void close({bool force = false}) {
    _platform.close(force: force);
    for (final io in _dartIo.values) {
      io.close(force: force);
    }
    _dartIo.clear();
  }

  Future<ResponseBody> _fetchDartIo(
    NetworkProfile profile,
    RequestOptions sent,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Picked and used in one synchronous step after the profile lookup, so
    // a concurrent revision change cannot close it in between.
    var io = _dartIoFor(profile);
    try {
      try {
        return await io.adapter.fetch(sent, requestStream, cancelFuture);
        // IOHttpClientAdapter's error for a fetch after close.
        // ignore: avoid_catching_errors
      } on StateError {
        // Closed before its first byte, so the request stream is untouched:
        // once more on a fresh one.
        if (identical(_dartIo[profile.origin], io)) {
          _dropDartIo(profile.origin);
        }
        io = _dartIoFor(profile);
        return await io.adapter.fetch(sent, requestStream, cancelFuture);
      }
    } on Object catch (error) {
      if (!profile.origin.isSecure || !_isLostBeforeResponse(error)) rethrow;
      if (await _clientCertificateRefused(profile, io.context)) {
        throw _connectionError(
          sent,
          ClientCertificateRefusedException(profile.origin.toString()),
        );
      }
      rethrow;
    }
  }

  _IoAdapter _dartIoFor(NetworkProfile profile) {
    final origin = profile.origin;
    final key = _transportKey(profile);
    final cached = _dartIo[origin];
    if (cached != null && cached.key == key) return cached;
    _dropDartIo(origin);
    final SecurityContext context;
    try {
      context = profileSecurityContext(profile);
    } on Object catch (error) {
      if (error is! TlsException && error is! ArgumentError) rethrow;
      _log.info('Stored TLS settings refused: ${error.runtimeType}');
      throw ConnectionProfileIncompleteException(origin.toString());
    }
    final adapter = _createDartIoAdapter(
      () => profileHttpClient(
        profile,
        context: context,
        onPinMismatch: (seen) => _onPinMismatch(origin, seen),
      ),
    );
    return _dartIo[origin] = _IoAdapter(key, adapter, context);
  }

  void _dropDartIo(OriginKey origin) => _dartIo.remove(origin)?.close();

  void _onPinMismatch(OriginKey origin, CertificateInfo seen) {
    if (_recordedMismatches[origin] == seen.sha256) return;
    _recordedMismatches[origin] = seen.sha256;
    unawaited(
      _profiles
          .recordPinMismatch(origin, seen)
          .catchError(
            (Object error) =>
                _log.info('Mismatch not recorded: ${error.runtimeType}'),
          ),
    );
  }

  /// A TLS 1.3 server refuses a client certificate only after the client
  /// finished its handshake, so the request just sees the connection end;
  /// so do a stale keep-alive connection and a network change. A second
  /// handshake that sends no HTTP tells them apart: a server that refuses
  /// the certificate hangs up on it at once, a healthy one waits for a
  /// request.
  Future<bool> _clientCertificateRefused(
    NetworkProfile profile,
    SecurityContext context,
  ) async {
    final origin = profile.origin;
    final now = _clock();
    if (_refusalChecks[origin] case (final checkedAt, final refused)
        when now.difference(checkedAt) < _refusalCheckValidFor) {
      return refused;
    }
    final refused = await _checkHandshake(profile, context);
    _refusalChecks[origin] = (_clock(), refused);
    return refused;
  }

  Future<bool> _checkHandshake(
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
      timeout: refusalCheckTimeout,
    );
    final SecureSocket socket;
    try {
      socket = await connecting.timeout(refusalCheckTimeout);
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
      return await ended.future.timeout(
        refusalCheckWait,
        onTimeout: () => false,
      );
    } finally {
      unawaited(subscription.cancel());
      socket.destroy();
    }
  }

  /// Every error leaves with the caller's own options, which never held
  /// the profile's headers. One whose text quotes a secret keeps its kind
  /// but loses its text.
  DioException _scrubbed(
    Object error,
    StackTrace stackTrace,
    RequestOptions options,
    NetworkProfile profile,
  ) {
    final inner = error is DioException ? error.error : error;
    // Built here, with nothing but the origin in them.
    if (_isConnectionSettingsError(inner) ||
        inner is ClientCertificateRefusedException) {
      return _connectionError(options, inner!);
    }
    if (profile.hasHeaders &&
        (inner is FormatException || inner is ArgumentError)) {
      _log.info('A stored setting was refused: ${inner.runtimeType}');
      return _connectionError(
        options,
        ConnectionProfileIncompleteException(profile.origin.toString()),
      );
    }
    if (quotesSecret(profile.secrets, [
      inner,
      if (error is DioException) ...[error.message, error],
    ])) {
      _log.info('Error text dropped: ${inner.runtimeType}');
      return DioException(
        requestOptions: options,
        type: error is DioException
            ? error.type
            : DioExceptionType.connectionError,
        error: textFreeLike(inner),
        stackTrace: error is DioException ? error.stackTrace : stackTrace,
      );
    }
    if (error is DioException) return error.copyWith(requestOptions: options);
    return DioException(
      requestOptions: options,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static RequestOptions _withProfileHeaders(
    RequestOptions options,
    Map<String, String> profileHeaders,
  ) {
    final present = {
      for (final name in options.headers.keys) name.toLowerCase(),
    };
    final headers = <String, dynamic>{...options.headers};
    for (final MapEntry(:key, :value) in profileHeaders.entries) {
      if (!present.contains(key.toLowerCase())) headers[key] = value;
    }
    return options.copyWith(headers: headers, followRedirects: false);
  }

  /// Only the `/info` probes, which carry no credentials, reach an http
  /// origin before the user allowed unencrypted connections to it.
  static bool _isPreConsentProbe(RequestOptions options) =>
      options.extra[preConsentProbeKey] == true &&
      options.method.toUpperCase() == 'GET' &&
      _infoPath.hasMatch(options.uri.path) &&
      !options.headers.keys.any(
        (name) => name.toLowerCase() == 'authorization',
      );

  static bool _isLostBeforeResponse(Object error) => switch (error) {
    HttpException() => true,
    DioException(error: HttpException()) => true,
    _ => false,
  };

  static bool _isConnectionSettingsError(Object? error) =>
      error is ConnectionProfileLockedException ||
      error is ConnectionProfileIncompleteException ||
      error is ConnectionProfilesDamagedException ||
      error is CleartextBlockedException;

  static DioException _connectionError(RequestOptions options, Object error) =>
      DioException(
        type: DioExceptionType.connectionError,
        requestOptions: options,
        error: error,
      );

  static _TransportKey _transportKey(NetworkProfile profile) => (
    revision: profile.revision,
    pin: profile.pin?.sha256,
    caPem: profile.caCertificate?.pem,
    clientCertificate: profile.clientCertificate?.importedAt,
  );
}

typedef _TransportKey = ({
  int revision,
  String? pin,
  String? caPem,
  DateTime? clientCertificate,
});

final class _IoAdapter {
  new(this.key, this.adapter, this.context);

  final _TransportKey key;
  final HttpClientAdapter adapter;
  final SecurityContext context;

  // Not forced: requests in flight on the old settings finish.
  void close({bool force = false}) => adapter.close(force: force);
}
