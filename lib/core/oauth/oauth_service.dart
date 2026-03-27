import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OAuthTokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  OAuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory OAuthTokenResponse.fromJson(Map<String, dynamic> json) {
    return OAuthTokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

class OAuthService {
  static const String _clientId = 'vikunja-flutter';
  static const String _redirectUri = 'vikunja-flutter://callback';
  static const String _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  String _codeVerifier = '';
  String _state = '';

  /// Generates a cryptographically random code verifier for PKCE (43-128 chars).
  String _generateCodeVerifier() {
    final random = Random.secure();
    return List.generate(
      128,
      (_) => _charset[random.nextInt(_charset.length)],
    ).join();
  }

  /// Generates the S256 code challenge from the code verifier.
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a random state parameter for CSRF protection.
  String _generateState() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => _charset[random.nextInt(_charset.length)],
    ).join();
  }

  /// Launches the OAuth authorization flow in the system browser.
  /// Returns a Future that completes with the authorization code
  /// when the app receives the callback deep link.
  Future<String> authorize(String serverUrl) async {
    _codeVerifier = _generateCodeVerifier();
    _state = _generateState();
    final codeChallenge = _generateCodeChallenge(_codeVerifier);

    final authorizeUrl = Uri.parse('$serverUrl/oauth/authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': _state,
      },
    );

    final launched = await launchUrl(
      authorizeUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Could not launch browser for OAuth authorization');
    }

    // Listen for the callback deep link
    final appLinks = AppLinks();
    final callbackUri = await appLinks.uriLinkStream.firstWhere(
      (uri) => uri.scheme == 'vikunja-flutter' && uri.host == 'callback',
    );

    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != _state) {
      throw Exception('OAuth state mismatch - possible CSRF attack');
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('No authorization code received from OAuth callback');
    }

    return code;
  }

  /// Exchanges the authorization code for access and refresh tokens.
  Future<OAuthTokenResponse> exchangeCode(String serverUrl, String code) async {
    final response = await http.post(
      Uri.parse('$serverUrl/api/v1/oauth/token'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Vikunja Mobile App',
      },
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'code_verifier': _codeVerifier,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Token exchange failed: ${error['message'] ?? response.body}',
      );
    }

    return OAuthTokenResponse.fromJson(jsonDecode(response.body));
  }
}
