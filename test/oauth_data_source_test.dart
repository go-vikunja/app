import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/data_sources/oauth_data_source.dart';

void main() {
  group('PKCE', () {
    test('generateCodeVerifier returns 43-128 character URL-safe string', () {
      final verifier = OAuthDataSource.generateCodeVerifier();
      expect(verifier.length, greaterThanOrEqualTo(43));
      expect(verifier.length, lessThanOrEqualTo(128));
      // URL-safe base64 characters only (no padding)
      expect(verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));
      // No padding characters
      expect(verifier.contains('='), isFalse);
    });

    test('generateCodeVerifier returns different values each call', () {
      final v1 = OAuthDataSource.generateCodeVerifier();
      final v2 = OAuthDataSource.generateCodeVerifier();
      expect(v1, isNot(equals(v2)));
    });

    test('generateCodeChallenge returns S256 hash of verifier', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      final challenge = OAuthDataSource.generateCodeChallenge(verifier);

      // Manually compute expected: base64url(sha256(verifier)) without padding
      final digest = sha256.convert(utf8.encode(verifier));
      final expected = base64Url.encode(digest.bytes).replaceAll('=', '');
      expect(challenge, equals(expected));
    });

    test('generateCodeChallenge has no padding characters', () {
      final verifier = OAuthDataSource.generateCodeVerifier();
      final challenge = OAuthDataSource.generateCodeChallenge(verifier);
      expect(challenge.contains('='), isFalse);
    });

    test('generateState returns non-empty URL-safe string', () {
      final state = OAuthDataSource.generateState();
      expect(state.isNotEmpty, isTrue);
      expect(state.contains('='), isFalse);
    });

    test('generateState returns different values each call', () {
      final s1 = OAuthDataSource.generateState();
      final s2 = OAuthDataSource.generateState();
      expect(s1, isNot(equals(s2)));
    });
  });

  group('buildAuthorizationUrl', () {
    test('builds correct URL with all parameters', () {
      final uri = OAuthDataSource.buildAuthorizationUrl(
        baseUrl: 'https://vikunja.example.com',
        codeChallenge: 'test_challenge',
        state: 'test_state',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'vikunja.example.com');
      expect(uri.path, '/api/v1/oauth/authorize');
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['client_id'], 'vikunja-flutter');
      expect(uri.queryParameters['redirect_uri'], 'vikunja://callback');
      expect(uri.queryParameters['code_challenge'], 'test_challenge');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(uri.queryParameters['state'], 'test_state');
    });

    test('strips trailing slash from baseUrl', () {
      final uri = OAuthDataSource.buildAuthorizationUrl(
        baseUrl: 'https://vikunja.example.com/',
        codeChallenge: 'c',
        state: 's',
      );
      expect(uri.path, '/api/v1/oauth/authorize');
    });
  });
}
