import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

typedef AuthorizationRequestFactory = AuthorizationRequest Function(
  ServerConnection connection,
  OAuthClientConfig client,
);

final _log = Logger('BrowserSignIn');

/// Vikunja has no consent screen, so the sign-in page decides who signs in.
/// When it is not the account being signed in again, nothing is stored.
final class SignedInAsDifferentUser implements Exception {
  const new({required this.signedInUsername, required this.expectedUsername});

  final String signedInUsername;
  final String expectedUsername;

  @override
  String toString() => 'SignedInAsDifferentUser';
}

/// OAuth 2.0 authorization code flow with PKCE through the server's web
/// login page, which covers local, LDAP, OpenID Connect and TOTP accounts.
final class BrowserSignIn {
  new({
    required this._authenticator,
    required this._tokenGateway,
    required this._accountGateway,
    required this._tokenStore,
    required this._registry,
    required this._sessions,
    OAuthClientConfig? client,
    this._clock = DateTime.now,
    this._createRequest = AuthorizationRequest.create,
    Duration previousSessionLogoutTimeout = const Duration(seconds: 20),
  }) : _client = client ?? appOAuthClient,
       _logoutTimeout = previousSessionLogoutTimeout;

  final WebAuthenticator _authenticator;
  final TokenGateway _tokenGateway;
  final AccountGateway _accountGateway;
  final TokenStore _tokenStore;
  final AccountRegistry _registry;
  final SessionManagers _sessions;
  final OAuthClientConfig _client;
  final Clock _clock;
  final AuthorizationRequestFactory _createRequest;
  final Duration _logoutTimeout;

  /// Signs in and makes the account active. Null when the user closed the
  /// browser. With [expectedAccount], only that user is accepted.
  /// [beforeActivatingExisting] runs for an account already on this device
  /// before it becomes active again. Throws `VikunjaFailure`,
  /// `AuthorizationCallbackException`, [WebAuthenticationFailed] or
  /// [SignedInAsDifferentUser].
  Future<RegisteredAccount?> signIn(
    ServerConnection connection, {
    Account? expectedAccount,
    Future<void> Function(String accountId)? beforeActivatingExisting,
  }) async {
    final request = _createRequest(connection, _client);
    _log.info('Opening sign-in page at ${describeUriForLog(request.url)}');
    final callback = await _authenticator.authenticate(
      request.url,
      callbackUrlScheme: _client.redirectUri.scheme,
    );
    if (callback == null) {
      _log.info('Sign-in cancelled');
      return null;
    }
    final code = request.codeFromCallback(callback);
    final tokens = await _tokenGateway.exchangeCode(
      connection,
      code: code,
      request: request,
    );
    final receivedAt = _clock();

    final User user;
    try {
      user = await _accountGateway.currentUser(
        connection,
        _IssuedTokens(tokens.accessToken),
      );
      if (user.id != tokens.userId) {
        throw const UnexpectedResponse(
          null,
          message: 'GET /user returned a different user than the token',
        );
      }
      if (expectedAccount != null && user.id != expectedAccount.userId) {
        throw SignedInAsDifferentUser(
          signedInUsername: user.username,
          expectedUsername: expectedAccount.username,
        );
      }
    } on Object {
      unawaited(_endSession(connection, _storedFrom(tokens)));
      rethrow;
    }

    final accountId = accountIdFor(connection.rootUri, user.id);
    await _sessions.retire(accountId);
    final previous = await _tokenStore.read(accountId);
    await _tokenStore.write(accountId, tokens);
    await _sessions.signedIn(accountId, tokens, receivedAt: receivedAt);

    final existing = await _registry.find(accountId);
    if (existing != null) await beforeActivatingExisting?.call(accountId);
    final entry = RegisteredAccount(
      account: Account(
        id: accountId,
        serverRoot: connection.rootUri,
        userId: user.id,
        username: user.username,
        displayName: user.displayName,
        addedAt: existing?.account.addedAt ?? _clock().toUtc(),
      ),
      connection: connection,
    );
    await _registry.upsert(entry, activate: true);
    _log.info('Signed in account $accountId');

    if (previous != null && previous.refreshToken != tokens.refreshToken) {
      unawaited(_endSession(connection, previous));
    }
    return entry;
  }

  /// Best effort: the session is abandoned locally either way.
  Future<void> _endSession(
    ServerConnection connection,
    StoredTokens tokens,
  ) async {
    try {
      await _accountGateway
          .logout(
            connection,
            _DetachedSession(
              tokens,
              refresh: (refreshToken) =>
                  _tokenGateway.refresh(connection, refreshToken),
              clock: _clock,
            ),
          )
          .timeout(_logoutTimeout);
    } on Object catch (error) {
      _log.info('Could not end an abandoned session: ${error.runtimeType}');
    }
  }

  static StoredTokens _storedFrom(TokenSet tokens) => StoredTokens(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
  );
}

/// The access token of a token response that was not persisted yet; it is
/// minutes old, so a rejection is final.
final class _IssuedTokens implements AccessTokenSource {
  const new(this._accessToken);

  final String _accessToken;

  @override
  Future<String> validAccessToken() async => _accessToken;

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async => null;
}

/// Tokens of a session that is being abandoned: refreshed at most once, in
/// memory only, just to be able to log it out.
final class _DetachedSession implements AccessTokenSource {
  new(this._tokens, {required this._refresh, required this._clock});

  final StoredTokens _tokens;
  final RefreshCall _refresh;
  final Clock _clock;
  Future<String>? _refreshed;

  @override
  Future<String> validAccessToken() async {
    final expiresAt = JwtClaims.tryParse(_tokens.accessToken)?.expiresAt;
    final usable =
        expiresAt != null &&
        expiresAt.difference(_clock()) > SessionManager.refreshMargin;
    return usable ? _tokens.accessToken : await _refreshOnce();
  }

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async =>
      _refreshed == null ? await _refreshOnce() : null;

  Future<String> _refreshOnce() =>
      _refreshed ??= _refresh(_tokens.refreshToken)
          .then((tokens) => tokens.accessToken);
}
