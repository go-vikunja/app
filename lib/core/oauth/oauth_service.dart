import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vikunja_app/core/network/client.dart';

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

enum OAuthError {
  browserLaunchFailed,
  stateMismatch,
  noAuthorizationCode,
  tokenExchangeFailed,
}

class OAuthException implements Exception {
  final OAuthError error;
  final String? serverMessage;

  OAuthException(this.error, {this.serverMessage});
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
      throw OAuthException(OAuthError.browserLaunchFailed);
    }

    // Listen for the callback deep link with a 10-minute timeout
    // (matches the server-side authorization code expiry)
    final appLinks = AppLinks();
    final callbackUri = await appLinks.uriLinkStream
        .firstWhere(
          (uri) => uri.scheme == 'vikunja-flutter' && uri.host == 'callback',
        )
        .timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            throw OAuthException(OAuthError.noAuthorizationCode);
          },
        );

    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != _state) {
      throw OAuthException(OAuthError.stateMismatch);
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw OAuthException(OAuthError.noAuthorizationCode);
    }

    return code;
  }

  /// Exchanges the authorization code for access and refresh tokens.
  Future<OAuthTokenResponse> exchangeCode(Client client, String code) async {
    final response = await client.postUnauthenticated(
      url: '/oauth/token',
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'code_verifier': _codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw OAuthException(
        OAuthError.tokenExchangeFailed,
        serverMessage: error['message'] as String?,
      );
    }

    return OAuthTokenResponse.fromJson(jsonDecode(response.body));
  }
}
