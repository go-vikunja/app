import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/oauth/oauth_service.dart';

void main() {
  group('OAuthTokenResponse.fromJson', () {
    test('parses valid token response', () {
      final json = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.test',
        'token_type': 'bearer',
        'expires_in': 600,
        'refresh_token': 'refresh-abc-123',
      };

      final response = OAuthTokenResponse.fromJson(json);

      expect(response.accessToken, 'eyJhbGciOiJIUzI1NiJ9.test');
      expect(response.refreshToken, 'refresh-abc-123');
      expect(response.expiresIn, 600);
    });

    test('throws on missing access_token', () {
      final json = {
        'token_type': 'bearer',
        'expires_in': 600,
        'refresh_token': 'refresh-abc-123',
      };

      expect(
        () => OAuthTokenResponse.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws on missing refresh_token', () {
      final json = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.test',
        'token_type': 'bearer',
        'expires_in': 600,
      };

      expect(
        () => OAuthTokenResponse.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('OAuthException', () {
    test('stores error type', () {
      final ex = OAuthException(OAuthError.stateMismatch);
      expect(ex.error, OAuthError.stateMismatch);
      expect(ex.serverMessage, isNull);
    });

    test('stores server message when provided', () {
      final ex = OAuthException(
        OAuthError.tokenExchangeFailed,
        serverMessage: 'code expired',
      );
      expect(ex.error, OAuthError.tokenExchangeFailed);
      expect(ex.serverMessage, 'code expired');
    });
  });
}
