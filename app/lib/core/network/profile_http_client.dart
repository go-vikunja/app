import 'dart:convert';
import 'dart:io';

import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

typedef PinMismatchHook = void Function(CertificateInfo seen);

typedef CertificateCheck = bool Function(
  X509Certificate certificate,
  String host,
  int port,
);

/// The trust and identity of [profile]: no system roots when it pins or
/// trusts its own CA, and its client certificate. Throws a [TlsException]
/// or an [ArgumentError] when the stored CA or PKCS#12 cannot be loaded,
/// and an [ArgumentError] when the PKCS#12 secrets are missing.
SecurityContext profileSecurityContext(NetworkProfile profile) {
  assert(
    profile.pin == null || profile.caCertificate == null,
    'A pin and a trusted CA exclude each other',
  );
  final context = SecurityContext(
    withTrustedRoots: profile.pin == null && profile.caCertificate == null,
  );
  if (profile.caCertificate case final ca?) {
    context.setTrustedCertificatesBytes(utf8.encode(ca.pem));
  }
  if (profile.clientCertificate != null) {
    final ProfileSecrets(:pkcs12, :pkcs12Password) = profile.secrets;
    if (pkcs12 == null || pkcs12Password == null) {
      throw ArgumentError('The client certificate is not available');
    }
    context
      ..useCertificateChainBytes(pkcs12, password: pkcs12Password)
      ..usePrivateKeyBytes(pkcs12, password: pkcs12Password);
  }
  return context;
}

/// Pins in the TLS handshake: with no trusted roots every chain fails
/// verification, so dart:io asks this for the leaf on every new connection
/// before any HTTP byte is written. Only [origin]'s host and port can pass;
/// a different leaf goes to [onMismatch], which may never throw into the
/// handshake.
CertificateCheck pinnedCertificateCheck(
  OriginKey origin,
  String sha256, {
  PinMismatchHook? onMismatch,
}) => (certificate, host, port) {
  if (host.toLowerCase() != origin.host || port != origin.port) return false;
  if (CertificateInfo.sha256Of(certificate.der) == sha256) return true;
  try {
    onMismatch?.call(CertificateInfo.fromX509(certificate));
  } on Object {
    // Recording is best effort; the connection fails either way.
  }
  return false;
};

/// [pinnedCertificateCheck] for a [SecureSocket] to [origin].
bool Function(X509Certificate certificate) pinnedSocketCheck(
  OriginKey origin,
  String sha256, {
  PinMismatchHook? onMismatch,
}) {
  final check = pinnedCertificateCheck(origin, sha256, onMismatch: onMismatch);
  return (certificate) => check(certificate, origin.host, origin.port);
}

/// An [HttpClient] for [profile]'s origin (network.md §2.3). [context] is
/// [profileSecurityContext] unless the caller built and validated it
/// already.
HttpClient profileHttpClient(
  NetworkProfile profile, {
  SecurityContext? context,
  PinMismatchHook? onPinMismatch,
}) {
  final client = HttpClient(context: context ?? profileSecurityContext(profile))
    ..idleTimeout = const Duration(seconds: 15);
  if (profile.pin case final pin?) {
    client.badCertificateCallback = pinnedCertificateCheck(
      profile.origin,
      pin.sha256,
      onMismatch: onPinMismatch,
    );
  }
  return client;
}
