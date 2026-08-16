import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Substrings identifying a transient network-connectivity failure that should
/// not be reported to Sentry.
///
/// The `cronet_http` client used to surface these as Chromium `net::ERR_*`
/// codes, which a `beforeSend` filter dropped. `ok_http` surfaces the same
/// failures as an [http.ClientException] whose message is the underlying
/// OkHttp/Java `IOException.toString()` (e.g.
/// `java.net.UnknownHostException: Unable to resolve host ...`), so match those
/// Java exception class names and Android errno message fragments instead.
///
/// Deliberately excludes TLS/certificate errors (`SSLException`,
/// `CertPathValidatorException`, ...): those are actionable — and the mTLS
/// client-certificate feature depends on seeing them — so they must still reach
/// Sentry, exactly as the original Cronet filter (connectivity codes only) left
/// them alone.
const _ignoredNetworkErrorSignatures = <String>[
  // Java exception class names thrown by OkHttp (via package:ok_http).
  'UnknownHostException', // DNS failure          (was ERR_NAME_NOT_RESOLVED)
  'ConnectException', // refused / unreachable (was ERR_CONNECTION_REFUSED)
  'NoRouteToHostException', //                    (was ERR_ADDRESS_UNREACHABLE)
  'PortUnreachableException',
  'SocketTimeoutException', // read/connect timeout (was ERR_CONNECTION_TIMED_OUT)
  'InterruptedIOException', // OkHttp call timeout
  // Android/POSIX message fragments that accompany the above.
  'Unable to resolve host', //                    (was ERR_NAME_NOT_RESOLVED)
  'Failed to connect', //                         (was ERR_CONNECTION_REFUSED)
  'Network is unreachable', //                    (was ERR_INTERNET_DISCONNECTED)
  'No route to host', //                          (was ERR_ADDRESS_UNREACHABLE)
  'Connection reset', //                          (was ERR_CONNECTION_RESET)
  'Connection refused', //                        (was ERR_CONNECTION_REFUSED)
  'Connection closed', //                         (was ERR_CONNECTION_CLOSED)
  'Software caused connection abort',
  'ECONNREFUSED',
  'ENETUNREACH',
  'EHOSTUNREACH',
];

/// Whether [throwable] is an expected transient network failure that should be
/// filtered out of Sentry reporting.
///
/// Returns true for:
/// - a [SocketException] (the `dart:io` `IOClient` fallback and other socket
///   failures — the device is offline / the host is unreachable),
/// - a [TimeoutException] (the client-side `.timeout(...)` guard firing), and
/// - an [http.ClientException] whose message contains one of the OkHttp/Java
///   connectivity signatures above (the `ok_http` client's failure shape).
bool isIgnoredNetworkError(Object? throwable) {
  if (throwable == null) return false;
  if (throwable is SocketException || throwable is TimeoutException) {
    return true;
  }
  if (throwable is! http.ClientException) return false;

  final message = throwable.toString();
  for (final signature in _ignoredNetworkErrorSignatures) {
    if (message.contains(signature)) return true;
  }
  return false;
}
