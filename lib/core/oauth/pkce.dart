import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _charset =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// Generates a cryptographically random string from the RFC 7636
/// unreserved character set.
String generateRandomString(int length) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => _charset[random.nextInt(_charset.length)],
  ).join();
}

/// Generates the S256 code challenge from a code verifier.
/// code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
/// with trailing '=' padding stripped per RFC 7636.
String generateCodeChallenge(String verifier) {
  final bytes = utf8.encode(verifier);
  final digest = sha256.convert(bytes);
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
