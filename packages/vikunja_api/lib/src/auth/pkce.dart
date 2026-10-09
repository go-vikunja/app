import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// RFC 7636 §4.1: 32 random octets give a 43-character verifier.
String generateCodeVerifier({Random? random}) =>
    randomUrlSafeString(32, random: random);

/// RFC 7636 §4.2, method S256.
String codeChallengeS256(String codeVerifier) =>
    _base64UrlWithoutPadding(sha256.convert(ascii.encode(codeVerifier)).bytes);

String generateState({Random? random}) =>
    randomUrlSafeString(16, random: random);

/// [byteCount] random bytes, base64url-encoded without padding.
String randomUrlSafeString(int byteCount, {Random? random}) {
  final source = random ?? Random.secure();
  return _base64UrlWithoutPadding([
    for (var i = 0; i < byteCount; i++) source.nextInt(256),
  ]);
}

String _base64UrlWithoutPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
