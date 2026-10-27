import 'dart:async';
import 'dart:io';

import 'package:vikunja_mobile/core/network/network_profile.dart';

/// Shorter header values and passwords turn up by chance in error texts
/// that never saw them (ports, errno numbers, durations, host names), so
/// only longer ones count as quoted.
const minIdentifiableSecretLength = 8;

/// Whether the text of any of [values] contains one of the [secrets] long
/// enough to identify.
bool quotesSecret(ProfileSecrets secrets, Iterable<Object?> values) {
  final identifiable = [
    for (final secret in secrets.secretTexts)
      if (secret.length >= minIdentifiableSecretLength) secret,
  ];
  if (identifiable.isEmpty) return false;
  return values.nonNulls.any((value) {
    final text = value.toString();
    return identifiable.any(text.contains);
  });
}

/// An error of [error]'s kind, as far as failure classification tells
/// kinds apart, without any of its text; null for other kinds.
Exception? textFreeLike(Object? error) => switch (error) {
  CertificateException() => const CertificateException(),
  HandshakeException() => const HandshakeException(),
  TlsException() => const TlsException(),
  SocketException() => const SocketException(''),
  HttpException() => const HttpException(''),
  WebSocketException() => const WebSocketException(),
  TimeoutException() => TimeoutException(null),
  _ => null,
};
