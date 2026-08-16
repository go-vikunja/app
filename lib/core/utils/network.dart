import 'package:vikunja_app/core/network/response.dart';

String normalizeServerURL(String input) {
  var url = input.trim();
  if (url.isEmpty) return url;
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.endsWith('/api/v1')) {
    url = url.substring(0, url.length - '/api/v1'.length);
  }
  return url;
}

/// Whether [exceptionMessage] indicates that the TLS peer required or rejected
/// a client certificate. BoringSSL exposes TLS alert names in these messages;
/// TLS 1.3 uses `certificate_required`, while a presented-but-rejected
/// certificate commonly produces `bad_certificate` or `unknown_ca`.
///
/// TLS 1.2 can report only a generic handshake failure when no certificate was
/// sent, which is intentionally not classified here because it is ambiguous.
/// The login screen therefore always offers a manual certificate picker on
/// Android as a recovery path for TLS 1.2 and other server-specific failures.
bool isCertificateRequiredError(String exceptionMessage) {
  const clientCertificateAlerts = [
    'CERTIFICATE_REQUIRED',
    'ALERT_BAD_CERTIFICATE',
    'ALERT_UNKNOWN_CA',
  ];
  return clientCertificateAlerts.any(exceptionMessage.contains);
}

/// Whether a failed `/api/v1/info` probe means the server's edge requires a
/// client certificate the app is not (yet) presenting — the signal the login
/// screen uses to offer the certificate picker.
///
/// This deployment can report that in two shapes, and both must offer the
/// picker:
///
///  * An edge that *requires* the certificate during the TLS handshake fails
///    the connection outright; `ok_http` surfaces it as an [ExceptionResponse]
///    whose message carries a BoringSSL alert — classified by
///    [isCertificateRequiredError].
///  * An edge that leaves the certificate *optional* at TLS and enforces it in
///    an Envoy ext_authz filter (`optionalClientCertificate: true`) completes
///    the handshake and returns HTTP 401/403 instead. `/api/v1/info` is
///    unauthenticated on stock Vikunja, so a 401/403 there is never the app's
///    own doing — it can only be that proxy certificate gate.
bool serverInfoRequiresClientCertificate(Response<dynamic> info) {
  if (info.isException) {
    return isCertificateRequiredError(info.toException().message);
  }
  if (info.isError) {
    final status = info.toError().statusCode;
    return status == 401 || status == 403;
  }
  return false;
}
