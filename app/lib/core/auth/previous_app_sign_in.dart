import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

final _log = Logger('PreviousAppSignIn');

enum PreviousAppSessionSkip { insecure, unsupported }

/// The previous app's session is not tried: over http this app asks
/// first, which the previous app never did, and a server below the
/// support floor cannot be used.
final class PreviousAppSessionNotKept implements Exception {
  const new(this.reason);

  final PreviousAppSessionSkip reason;

  @override
  String toString() => 'PreviousAppSessionNotKept(${reason.name})';
}

/// Ends a [PreviousAppSignIn.signIn] early. Once the server has confirmed
/// the account, the sign-in only registers it on this device, and a cancel
/// comes too late.
final class PreviousAppSignInCancellation {
  final _token = CancelToken();
  var _registering = false;

  bool get isCancelled => _token.isCancelled;

  /// True when this call ended the sign-in.
  bool cancel() {
    if (_registering || isCancelled) return false;
    _token.cancel();
    return true;
  }

  bool _startRegistering() {
    if (isCancelled) return false;
    _registering = true;
    return true;
  }
}

/// Keeps the session of the previous Vikunja app, which this app replaced:
/// its refresh token is exchanged for new tokens (the server does not check
/// which client asks), and the account is then registered and activated
/// like a browser sign-in, in the same order as `BrowserSignIn`.
final class PreviousAppSignIn {
  new({
    required this._connector,
    required this._tokenGateway,
    required this._accountGateway,
    required this._tokenStore,
    required this._registry,
    required this._sessions,
    this._clock = DateTime.now,
    this._userTimeout = const Duration(seconds: 20),
    this._logoutTimeout = const Duration(seconds: 20),
  });

  final ServerConnector _connector;
  final TokenGateway _tokenGateway;
  final AccountGateway _accountGateway;
  final TokenStore _tokenStore;
  final AccountRegistry _registry;
  final SessionManagers _sessions;
  final Clock _clock;
  final Duration _userTimeout;
  final Duration _logoutTimeout;

  /// Null when [cancellation] ended it; a session the server issued anyway
  /// is logged out then. Throws [PreviousAppSessionNotKept],
  /// `ServerConnectionFailure`, `VikunjaFailure` or a `TimeoutException`
  /// when `GET /user` does not answer within its own bound, also after a
  /// cancel. Stores nothing in either case.
  Future<RegisteredAccount?> signIn({
    required String serverAddress,
    required String refreshToken,
    PreviousAppSignInCancellation? cancellation,
  }) async {
    final cancel = cancellation ?? PreviousAppSignInCancellation();
    final ServerConnection connection;
    try {
      connection = await _connector.connect(
        serverAddress,
        cancelToken: cancel._token,
      );
    } on Object {
      if (cancel.isCancelled) return null;
      rethrow;
    }
    if (cancel.isCancelled) return null;
    if (connection.isInsecure) {
      throw const PreviousAppSessionNotKept(PreviousAppSessionSkip.insecure);
    }
    if (!connection.capabilities.isSupported) {
      throw const PreviousAppSessionNotKept(PreviousAppSessionSkip.unsupported);
    }
    final tokens = await _tokenGateway.refresh(connection, refreshToken);
    final receivedAt = _clock();
    if (cancel.isCancelled) {
      unawaited(_endSession(connection, tokens.accessToken));
      return null;
    }

    final User user;
    try {
      // Its retries could take more than a minute, and the old token is
      // spent either way.
      user = await _accountGateway
          .currentUser(connection, _IssuedTokens(tokens.accessToken))
          .timeout(_userTimeout);
      if (user.id != tokens.userId) {
        throw const UnexpectedResponse(
          null,
          message: 'GET /user returned a different user than the token',
        );
      }
    } on Object {
      unawaited(_endSession(connection, tokens.accessToken));
      rethrow;
    }
    if (!cancel._startRegistering()) {
      unawaited(_endSession(connection, tokens.accessToken));
      return null;
    }

    final accountId = accountIdFor(connection.rootUri, user.id);
    await _sessions.retire(accountId);
    await _tokenStore.write(accountId, tokens);
    await _sessions.signedIn(accountId, tokens, receivedAt: receivedAt);
    final entry = RegisteredAccount(
      account: Account(
        id: accountId,
        serverRoot: connection.rootUri,
        userId: user.id,
        username: user.username,
        displayName: user.displayName,
        addedAt: _clock().toUtc(),
      ),
      connection: connection,
    );
    await _registry.upsert(entry, activate: true);
    _log.info('Kept the previous app session as account $accountId');
    return entry;
  }

  /// Best effort: the new session is abandoned locally either way.
  Future<void> _endSession(
    ServerConnection connection,
    String accessToken,
  ) async {
    try {
      await _accountGateway
          .logout(connection, _IssuedTokens(accessToken))
          .timeout(_logoutTimeout);
    } on Object catch (error) {
      _log.info('Could not end an abandoned session: ${error.runtimeType}');
    }
  }
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
