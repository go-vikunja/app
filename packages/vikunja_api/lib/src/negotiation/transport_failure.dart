import 'dart:io' show CertificateException, TlsException;

import 'package:dio/dio.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Maps a request that got no HTTP response to the failure the user sees.
/// Cancellation must be handled before.
ServerConnectionFailure transportFailure(Uri root, DioException exception) {
  // By type only: classification never depends on their text.
  if (_refusedByConnectionSettings(root, exception.error) case final failure?) {
    return failure;
  }
  final cause = exception.error ?? exception.message;
  switch (exception.type) {
    case DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout:
      return ServerTimeout(root);
    case DioExceptionType.badCertificate:
      return TlsFailure(root, cause: cause, certificateRejected: true);
    case DioExceptionType.connectionError ||
        DioExceptionType.unknown ||
        DioExceptionType.badResponse ||
        DioExceptionType.cancel:
      final description = _describe(exception, root);
      // A plain http connection cannot fail on TLS.
      if (root.isScheme('https') && _looksLikeTls(exception, description)) {
        final clientCertificateRefused = _clientCertificateMarkers.hasMatch(
          description,
        );
        return TlsFailure(
          root,
          cause: cause,
          certificateRejected:
              !clientCertificateRefused &&
              (exception.error is CertificateException ||
                  _certificateMarkers.hasMatch(description)),
          clientCertificateRefused: clientCertificateRefused,
        );
      }
      if (_timeoutMarkers.hasMatch(description)) return ServerTimeout(root);
      return ServerUnreachable(root, cause: cause);
  }
}

/// The same classification as [transportFailure] for a request of an
/// established connection.
NetworkProblem networkProblemOf(DioException exception) =>
    _problemOf(transportFailure(exception.requestOptions.uri, exception));

/// The problem of one of the app transport's own exceptions when it reaches
/// a caller outside a `DioException`, null for any other error.
NetworkProblem? connectionSettingsProblemOf(Object? error) =>
    switch (_refusedByConnectionSettings(Uri(), error)) {
      final failure? => _problemOf(failure),
      null => null,
    };

NetworkProblem _problemOf(ServerConnectionFailure failure) => switch (failure) {
  ConnectionSettingsFailure(:final problem) => switch (problem) {
    ConnectionSettingsProblem.cleartextBlocked =>
      NetworkProblem.cleartextBlocked,
    ConnectionSettingsProblem.locked => NetworkProblem.profileLocked,
    ConnectionSettingsProblem.incomplete => NetworkProblem.profileIncomplete,
    ConnectionSettingsProblem.damaged => NetworkProblem.profileDamaged,
  },
  TlsFailure(clientCertificateRefused: true) =>
    NetworkProblem.clientCertificate,
  TlsFailure() => NetworkProblem.tls,
  ServerTimeout() => NetworkProblem.timeout,
  _ => NetworkProblem.unreachable,
};

/// Whether an error text names a refused or missing client certificate, by
/// the same markers as [transportFailure].
bool mentionsClientCertificateRefusal(String errorText) =>
    _clientCertificateMarkers.hasMatch(errorText.toLowerCase());

/// Whether nothing answered at the address, so another port or scheme may
/// still reach Vikunja. A rejected certificate, server or client, means a
/// TLS server answered; a request the connection settings stopped must not
/// move on to plain http either.
bool isConnectionLevel(ServerConnectionFailure failure) => switch (failure) {
  TlsFailure(:final certificateRejected, :final clientCertificateRefused) =>
    !certificateRejected && !clientCertificateRefused,
  ServerTimeout() || ServerUnreachable() => true,
  _ => false,
};

/// Picks the failure that tells the user most; earlier ones win ties.
ServerConnectionFailure mostInformative(
  Iterable<ServerConnectionFailure> failures,
) => failures.reduce((best, next) => _rank(next) > _rank(best) ? next : best);

int _rank(ServerConnectionFailure failure) => switch (failure) {
  ConnectionSettingsFailure() => 6,
  BehindLoginProxy() => 5,
  NotAVikunjaServer() || ServerUnavailable() => 4,
  TlsFailure() => 3,
  ServerTimeout() => 2,
  ServerUnreachable() => 1,
  InvalidServerAddress() => 0,
};

// Native adapters (cronet_http, cupertino_http) surface TLS problems only as
// exception text: Chromium `net::ERR_CERT_*` / `ERR_SSL_*` and internal codes
// -200..-299, -110 and -117, NSURLErrorDomain -1200..-1206, Secure Transport
// `errSSL*`.
final _tlsMarkers = RegExp(
  'ssl|tls|certificate|handshake|err_cert_|'
  r'nsurlerrordomain.*code=-120[0-6]\b|cronetinternalerrorcode=-2\d\d\b|'
  r'cronetinternalerrorcode=-11[07]\b',
);

// Chromium ERR_CERT_* and the internal codes -200..-299 are certificate
// errors; NSURLErrorDomain -1201..-1204 are the server's certificate.
// ERR_SSL_*, -1200 and WRONG_VERSION_NUMBER also occur when the port speaks
// plain http, so they do not count.
final _certificateMarkers = RegExp(
  r'certificate_verify_failed|err_cert_|cronetinternalerrorcode=-2\d\d\b|'
  r'nsurlerrordomain.*code=-120[1-4]\b|'
  'errssl(xcert|norootcert|unknownrootcert|certexpired|certnotyetvalid|'
  'badcert)',
);

// Chromium -110/-117 and NSURLErrorDomain -1205/-1206 name the client
// certificate. BoringSSL names an alert the client received by its TLS 1.0
// or SSLv3 constant; a server sends these only about the client's
// certificate. Recorded with dart:io against Caddy (TLS 1.3, step 35b):
// TLSV1_ALERT_CERTIFICATE_REQUIRED without a certificate, and
// TLSV1_ALERT_UNKNOWN_CA for one from another CA, both in an HttpException
// on the first read after the handshake. Not handshake_failure, which any
// cipher or version mismatch sends. A server that just closes the
// connection is confirmed by the app's transport itself, which then throws
// a ClientCertificateRefusedException.
const _clientCertificateMarkerPatterns = [
  'err_bad_ssl_client_auth_cert',
  'err_ssl_client_auth_cert_needed',
  r'cronetinternalerrorcode=-11[07]\b',
  r'nsurlerrordomain.*code=-120[56]\b',
  r'sslv3_alert_(bad_certificate|unsupported_certificate)\b',
  r'sslv3_alert_certificate_(revoked|expired|unknown)\b',
  r'tlsv1_alert_(unknown_ca|access_denied|certificate_required)\b',
];

final _clientCertificateMarkers = RegExp(
  _clientCertificateMarkerPatterns.join('|'),
);

final _timeoutMarkers = RegExp(
  'timed out|timeout|err_(connection_)?timed_out|'
  r'nsurlerrordomain.*code=-1001\b',
);

// Host names such as ssl.example.com must not look like a TLS failure.
final _urls = RegExp(r'([a-z][a-z0-9+.-]*://|uri=)\S*');

ServerConnectionFailure? _refusedByConnectionSettings(Uri root, Object? error) {
  ConnectionSettingsFailure settings(ConnectionSettingsProblem problem) =>
      ConnectionSettingsFailure(root, problem: problem);
  return switch (error) {
    CleartextBlockedException() => settings(
      ConnectionSettingsProblem.cleartextBlocked,
    ),
    ConnectionProfileLockedException() => settings(
      ConnectionSettingsProblem.locked,
    ),
    ConnectionProfileIncompleteException() => settings(
      ConnectionSettingsProblem.incomplete,
    ),
    ConnectionProfilesDamagedException() => settings(
      ConnectionSettingsProblem.damaged,
    ),
    ClientCertificateRefusedException() => TlsFailure(
      root,
      cause: error,
      clientCertificateRefused: true,
    ),
    _ => null,
  };
}

bool _looksLikeTls(DioException exception, String description) =>
    exception.error is TlsException || _tlsMarkers.hasMatch(description);

String _describe(DioException exception, Uri root) =>
    '${exception.error ?? ''} ${exception.message ?? ''}'
        .toLowerCase()
        .replaceAll(_urls, ' ')
        .replaceAll(root.host, ' ');
