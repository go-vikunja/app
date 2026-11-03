import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/oauth/pkce.dart';

void main() {
  group('generateRandomString', () {
    test('produces string of requested length', () {
      expect(generateRandomString(128).length, 128);
      expect(generateRandomString(32).length, 32);
      expect(generateRandomString(43).length, 43);
    });

    test('only contains RFC 7636 unreserved characters', () {
      final unreserved = RegExp(r'^[A-Za-z0-9\-._~]+$');
      for (var i = 0; i < 100; i++) {
        expect(unreserved.hasMatch(generateRandomString(128)), isTrue);
      }
    });

    test('produces different strings on each call', () {
      final a = generateRandomString(128);
      final b = generateRandomString(128);
      expect(a, isNot(equals(b)));
    });
  });

  group('generateCodeChallenge', () {
    // RFC 7636 Appendix B test vector
    test('matches RFC 7636 Appendix B test vector', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      const expected = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
      expect(generateCodeChallenge(verifier), expected);
    });

    test('produces base64url encoding without padding', () {
      final challenge = generateCodeChallenge('test-verifier');
      expect(challenge.contains('='), isFalse);
      expect(challenge.contains('+'), isFalse);
      expect(challenge.contains('/'), isFalse);
    });

    test('is deterministic for the same input', () {
      const verifier = 'some-fixed-verifier-string';
      final a = generateCodeChallenge(verifier);
      final b = generateCodeChallenge(verifier);
      expect(a, equals(b));
    });

    test('is SHA-256 of the verifier encoded as base64url', () {
      const verifier = 'hello-world-verifier';
      final digest = sha256.convert(utf8.encode(verifier));
      final expected = base64Url.encode(digest.bytes).replaceAll('=', '');
      expect(generateCodeChallenge(verifier), expected);
    });
  });
}
