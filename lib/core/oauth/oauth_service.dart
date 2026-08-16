import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
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
  final Future<bool> Function(Uri uri) _launchAuthorizeUrl;
  final Stream<Uri> Function() _callbackUris;
  StreamSubscription<Uri>? _linkSubscription;
  Completer<Uri>? _callbackCompleter;

  OAuthService({
    Future<bool> Function(Uri uri)? launchAuthorizeUrl,
    Stream<Uri> Function()? callbackUris,
  }) : _launchAuthorizeUrl =
           launchAuthorizeUrl ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _callbackUris = callbackUris ?? (() => AppLinks().uriLinkStream);

  bool get isWaitingForCallback =>
      _callbackCompleter != null && !_callbackCompleter!.isCompleted;

  /// Cancels either a browser or client-transport authorization flow.
  void cancelAuthorize() {
    unawaited(_linkSubscription?.cancel());
    _linkSubscription = null;
    final completer = _callbackCompleter;
    _callbackCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(OAuthException(OAuthError.cancelled));
    }
  }

  /// Uses the normal browser flow unless [useClientTransport] selects the
  /// certificate-gated federator flow, whose immediate callback redirect must
  /// travel over [client].
  Future<String> authorize(
    Client client,
    String serverUrl, {
    bool useClientTransport = false,
  }) async {
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

    final completer = Completer<Uri>();
    _callbackCompleter = completer;
    final Uri callbackUri;

    try {
      if (useClientTransport) {
        unawaited(
          _resolveCallback(client, authorizeUrl).then(
            (uri) {
              if (!completer.isCompleted) completer.complete(uri);
            },
            onError: (Object e, StackTrace s) {
              if (!completer.isCompleted) completer.completeError(e, s);
            },
          ),
        );
      } else {
        _linkSubscription = _callbackUris().listen(
          (uri) {
            if (uri.scheme == 'vikunja-flutter' &&
                uri.host == 'callback' &&
                !completer.isCompleted) {
              completer.complete(uri);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        );
        if (!await _launchAuthorizeUrl(authorizeUrl)) {
          if (!completer.isCompleted) {
            completer.completeError(
              OAuthException(OAuthError.browserLaunchFailed),
            );
          }
        }
      }

      callbackUri = await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => throw OAuthException(OAuthError.noAuthorizationCode),
      );
    } finally {
      await _linkSubscription?.cancel();
      _linkSubscription = null;
      if (identical(_callbackCompleter, completer)) _callbackCompleter = null;
    }

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

  /// Issues the authorize GET over the mTLS transport and resolves the
  /// `vikunja-flutter://callback` redirect target. Throws [OAuthException] when
  /// the server does not answer with that redirect — which, for this
  /// certificate-gated leg, is almost always the ext_authz `Unauthorized` deny
  /// of a missing or rejected client certificate.
  Future<Uri> _resolveCallback(Client client, Uri authorizeUrl) async {
    final http.Response response = await client.getWithoutRedirect(
      authorizeUrl,
    );

    final location = response.headers['location'];
    if (response.statusCode < 300 ||
        response.statusCode >= 400 ||
        location == null ||
        location.isEmpty) {
      throw OAuthException(OAuthError.noAuthorizationCode);
    }

    final callbackUri = Uri.parse(location);
    if (callbackUri.scheme != 'vikunja-flutter' ||
        callbackUri.host != 'callback') {
      throw OAuthException(OAuthError.noAuthorizationCode);
    }

    return callbackUri;
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
