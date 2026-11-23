import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/issued_access_token.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/sign_in_tokens.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

typedef AuthorizationRequestFactory = AuthorizationRequest Function(
  ServerConnection connection,
  OAuthClientConfig client,
);

final _log = Logger('BrowserSignIn');

Future<void> _delay(Duration duration) => Future<void>.delayed(duration);

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
    this._diagnostics,
    OAuthClientConfig? client,
    this._clock = DateTime.now,
    this._sleep = _delay,
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
  final SessionDiagnostics? _diagnostics;
  final OAuthClientConfig _client;
  final Clock _clock;
  final Sleep _sleep;
  final AuthorizationRequestFactory _createRequest;
  final Duration _logoutTimeout;
  late final _signInTokens = SignInTokens(
    tokenStore: _tokenStore,
    tokenGateway: _tokenGateway,
    accountGateway: _accountGateway,
    diagnostics: _diagnostics,
    clock: _clock,
    sleep: _sleep,
    logoutTimeout: _logoutTimeout,
  );

  /// Signs in and makes the account active. Null when the user closed the
  /// browser. With [expectedAccount], only that user is accepted.
  /// [beforeStoring] runs once the browser has told which account it is,
  /// before anything of its new session is stored, and a throw there ends
  /// the sign-in. [beforeActivatingExisting] runs for an account already
  /// on this device before it becomes active again. Throws
  /// `VikunjaFailure`, `AuthorizationCallbackException`,
  /// [WebAuthenticationFailed] or [SignedInAsDifferentUser].
  Future<RegisteredAccount?> signIn(
    ServerConnection connection, {
    Account? expectedAccount,
    Future<void> Function(String accountId)? beforeStoring,
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
    final String accountId;
    try {
      user = await _accountGateway.currentUser(
        connection,
        IssuedAccessToken(tokens.accessToken),
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
      accountId = accountIdFor(connection.rootUri, user.id);
      await beforeStoring?.call(accountId);
    } on Object {
      unawaited(_signInTokens.abandon(connection, tokens));
      rethrow;
    }

    await _sessions.retire(accountId);
    final ReplacedTokens replaced;
    try {
      replaced = await _signInTokens.store(accountId, tokens);
    } on Object {
      unawaited(_signInTokens.abandon(connection, tokens));
      // The account stays with what storage still holds, which a new
      // manager reads as after a restart: the retired one hands out nothing.
      _sessions.replaceRetired(accountId);
      rethrow;
    }
    final session = await _sessions.signedIn(
      accountId,
      tokens,
      receivedAt: receivedAt,
    );

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

    unawaited(
      _signInTokens.settleReplaced(
        connection,
        accountId,
        replaced,
        session: session,
      ),
    );
    return entry;
  }
}
