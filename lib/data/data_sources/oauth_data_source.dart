import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:vikunja_app/data/models/oauth_token_response.dart';

/// Handles OAuth 2.0 Authorization Code with PKCE for Vikunja.
///
/// PKCE methods and URL builder are static (pure functions).
/// Token exchange and refresh use HTTP directly (form-encoded, not JSON),
/// so this class does NOT use the app's [Client] which sends JSON.
class OAuthDataSource {
  static const clientId = 'vikunja-flutter';
  static const redirectUri = 'vikunja://callback';

  // --- PKCE ---

  /// Generates a cryptographically random code verifier (43-128 chars).
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Derives the S256 code challenge from a code verifier.
  static String generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a random state string for CSRF protection.
  static String generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // --- URL Builder ---

  /// Builds the authorization URL to open in a system browser.
  static Uri buildAuthorizationUrl({
    required String baseUrl,
    required String codeChallenge,
    required String state,
  }) {
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);

    return Uri.parse('$base/api/v1/oauth/authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );
  }

  // --- Token Exchange ---

  /// Exchanges an authorization code for tokens.
  /// Throws on non-200 responses.
  Future<OAuthTokenResponse> exchangeCode({
    required String baseUrl,
    required String code,
    required String codeVerifier,
  }) async {
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);

    final response = await http.post(
      Uri.parse('$base/api/v1/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw OAuthException(
        error['code'] as int? ?? 0,
        error['message'] as String? ?? 'Token exchange failed',
      );
    }

    return OAuthTokenResponse.fromJson(jsonDecode(response.body));
  }

  // --- Token Refresh ---

  /// Refreshes the access token using a refresh token.
  /// Throws on non-200 responses.
  Future<OAuthTokenResponse> refreshToken({
    required String baseUrl,
    required String refreshToken,
  }) async {
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);

    final response = await http.post(
      Uri.parse('$base/api/v1/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw OAuthException(
        error['code'] as int? ?? 0,
        error['message'] as String? ?? 'Token refresh failed',
      );
    }

    return OAuthTokenResponse.fromJson(jsonDecode(response.body));
  }
}

class OAuthException implements Exception {
  final int code;
  final String message;
  OAuthException(this.code, this.message);

  @override
  String toString() => 'OAuthException($code): $message';
}
