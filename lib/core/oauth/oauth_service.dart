import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/oauth/pkce.dart';

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
  cancelled,
}

class OAuthException implements Exception {
  final OAuthError error;
  final String? serverMessage;

  OAuthException(this.error, {this.serverMessage});
}

class OAuthService {
  static const String _clientId = 'vikunja-flutter';
  static const String _redirectUri = 'vikunja-flutter://callback';

  String _codeVerifier = '';
  String _state = '';
  StreamSubscription<Uri>? _linkSubscription;
  Completer<Uri>? _callbackCompleter;

  bool get isWaitingForCallback =>
      _callbackCompleter != null && !_callbackCompleter!.isCompleted;

  /// Cancels a pending authorization flow.
  void cancelAuthorize() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    if (_callbackCompleter != null && !_callbackCompleter!.isCompleted) {
      _callbackCompleter!.completeError(OAuthException(OAuthError.cancelled));
    }
    _callbackCompleter = null;
  }

  /// Launches the OAuth authorization flow in the system browser.
  /// Returns a Future that completes with the authorization code
  /// when the app receives the callback deep link.
  Future<String> authorize(String serverUrl) async {
    cancelAuthorize();

    _codeVerifier = generateRandomString(128);
    _state = generateRandomString(32);
    final codeChallenge = generateCodeChallenge(_codeVerifier);

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

    _callbackCompleter = Completer<Uri>();
    final appLinks = AppLinks();
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'vikunja-flutter' && uri.host == 'callback') {
        if (!_callbackCompleter!.isCompleted) {
          _callbackCompleter!.complete(uri);
        }
      }
    });

    final callbackUri = await _callbackCompleter!.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () {
        cancelAuthorize();
        throw OAuthException(OAuthError.noAuthorizationCode);
      },
    );

    _linkSubscription?.cancel();
    _linkSubscription = null;
    _callbackCompleter = null;

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
