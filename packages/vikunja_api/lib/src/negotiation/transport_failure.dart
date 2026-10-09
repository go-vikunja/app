import 'dart:io' show CertificateException, TlsException;

import 'package:dio/dio.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Maps a request that got no HTTP response to the failure the user sees.
/// Cancellation must be handled before.
ServerConnectionFailure transportFailure(Uri root, DioException exception) {
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
        return TlsFailure(
          root,
          cause: cause,
          certificateRejected:
              exception.error is CertificateException ||
              _certificateMarkers.hasMatch(description),
        );
      }
      if (_timeoutMarkers.hasMatch(description)) return ServerTimeout(root);
      return ServerUnreachable(root, cause: cause);
  }
}

/// Whether nothing answered at the address, so another port or scheme may
/// still reach Vikunja. A rejected certificate means a TLS server answered.
bool isConnectionLevel(ServerConnectionFailure failure) => switch (failure) {
  TlsFailure(:final certificateRejected) => !certificateRejected,
  ServerTimeout() || ServerUnreachable() => true,
  _ => false,
};

/// Picks the failure that tells the user most; earlier ones win ties.
ServerConnectionFailure mostInformative(
  Iterable<ServerConnectionFailure> failures,
) => failures.reduce((best, next) => _rank(next) > _rank(best) ? next : best);

int _rank(ServerConnectionFailure failure) => switch (failure) {
  BehindLoginProxy() => 5,
  NotAVikunjaServer() || ServerUnavailable() => 4,
  TlsFailure() => 3,
  ServerTimeout() => 2,
  ServerUnreachable() => 1,
  InvalidServerAddress() => 0,
};

// Native adapters (cronet_http, cupertino_http) surface TLS problems only as
// exception text: Chromium `net::ERR_CERT_*` / `ERR_SSL_*` and internal codes
// -200..-299, NSURLErrorDomain -1200..-1206, Secure Transport `errSSL*`.
final _tlsMarkers = RegExp(
  'ssl|tls|certificate|handshake|err_cert_|'
  r'nsurlerrordomain.*code=-120[0-6]\b|cronetinternalerrorcode=-2\d\d\b',
);

// Chromium ERR_CERT_* and the internal codes -200..-299 are certificate
// errors; NSURLErrorDomain -1201..-1206 cover server and client certificates.
// ERR_SSL_*, -1200 and WRONG_VERSION_NUMBER also occur when the port speaks
// plain http, so they do not count.
final _certificateMarkers = RegExp(
  r'certificate_verify_failed|err_cert_|cronetinternalerrorcode=-2\d\d\b|'
  r'nsurlerrordomain.*code=-120[1-6]\b|'
  'errssl(xcert|norootcert|unknownrootcert|certexpired|certnotyetvalid|'
  'badcert)',
);

final _timeoutMarkers = RegExp(
  'timed out|timeout|err_(connection_)?timed_out|'
  r'nsurlerrordomain.*code=-1001\b',
);

// Host names such as ssl.example.com must not look like a TLS failure.
final _urls = RegExp(r'([a-z][a-z0-9+.-]*://|uri=)\S*');

bool _looksLikeTls(DioException exception, String description) =>
    exception.error is TlsException || _tlsMarkers.hasMatch(description);

String _describe(DioException exception, Uri root) =>
    '${exception.error ?? ''} ${exception.message ?? ''}'
        .toLowerCase()
        .replaceAll(_urls, ' ')
        .replaceAll(root.host, ' ');
