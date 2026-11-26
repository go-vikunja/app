import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

final _log = Logger('SignInTokens');

Future<void> _delay(Duration duration) => Future<void>.delayed(duration);

/// Tokens a sign-in stored in place of what storage held for the account,
/// for [SignInTokens.settleReplaced].
final class ReplacedTokens {
  const new _(this._previous, {required this._unreadable, required this._by});

  /// What storage held; null when nothing, or nothing it could read.
  final StoredTokens? _previous;
  final bool _unreadable;
  final TokenSet _by;

  /// Storage held no tokens for the account before the sign-in; a read that
  /// failed counts as holding some.
  bool get heldNone => _previous == null && !_unreadable;
}

/// What a sign-in does with the tokens it got, a browser sign-in and the
/// previous app's alike: stores them, trying secure storage again when it
/// fails, and settles the session they replace (decision log: Sessions).
final class SignInTokens {
  new({
    required this._tokenStore,
    required this._tokenGateway,
    required this._accountGateway,
    this._diagnostics,
    this._clock = DateTime.now,
    this._sleep = _delay,
    this._logoutTimeout = const Duration(seconds: 20),
  });

  static const storageRetryDelay = Duration(milliseconds: 500);
  static const storageWriteAttempts = 3;

  final TokenStore _tokenStore;
  final TokenGateway _tokenGateway;
  final AccountGateway _accountGateway;
  final SessionDiagnostics? _diagnostics;
  final Clock _clock;
  final Sleep _sleep;
  final Duration _logoutTimeout;

  /// Stores [tokens] for [accountId]. Throws when storage keeps refusing
  /// them; old tokens it cannot read do not stop it.
  Future<ReplacedTokens> store(String accountId, TokenSet tokens) =>
      _tokenStore.mutate(accountId, (store) async {
        StoredTokens? previous;
        var unreadable = false;
        try {
          previous = await store.read();
        } on Object catch (error) {
          _log.warning(
            'Could not read the old tokens of account $accountId: '
            '${error.runtimeType}',
          );
          unreadable = true;
        }
        await _write(store, accountId, tokens);
        return ReplacedTokens._(previous, unreadable: unreadable, by: tokens);
      });

  /// A write that fails twice may mean that secure storage lost its key
  /// for good, which only a reset of the storage repairs: the third write
  /// lets the platform reset it, which it does only when the key really
  /// cannot be unwrapped, so a passing failure deletes nothing.
  Future<void> _write(
    AccountTokenMutation store,
    String accountId,
    TokenSet tokens,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await store.write(
          tokens,
          recoverLostKey: attempt == storageWriteAttempts,
        );
        await _diagnostics?.noteReadable(accountId);
        return;
      } on Object catch (error) {
        _log.warning(
          'Could not store the tokens of account $accountId: '
          '${error.runtimeType}',
        );
        if (attempt == storageWriteAttempts) rethrow;
        await _sleep(storageRetryDelay);
      }
    }
  }

  /// Ends the session [replaced] replaces, and for an account whose session
  /// ended notes what became of it: a session the server still lists
  /// although it refuses the old refresh token is revoked with the new
  /// [session] (decision log: Sessions). Never throws.
  Future<void> settleReplaced(
    ServerConnection connection,
    String accountId,
    ReplacedTokens replaced, {
    required AccessTokenSource session,
  }) async {
    try {
      final ended = await _diagnostics?.lastEnd(accountId);
      final tokens = replaced._previous;
      if (tokens != null && tokens.refreshToken == replaced._by.refreshToken) {
        return;
      }
      final resolution = replaced._unreadable
          ? SessionEndResolution.unknown
          : tokens == null
          ? SessionEndResolution.noTokens
          : switch (await _endSession(connection, tokens)) {
              _Logout.ofLiveSession => SessionEndResolution.wasAlive,
              _Logout.refused => await _revokeOrphan(
                connection,
                tokens,
                session,
              ),
              _Logout.unconfirmed => SessionEndResolution.unknown,
            };
      if (ended == null || ended.resolution != null) return;
      await _diagnostics?.recordEnd(accountId, ended.resolved(resolution));
      _log.info('The ended session of account $accountId: ${resolution.name}');
    } on Object catch (error) {
      _log.info('Could not settle the replaced session: ${error.runtimeType}');
    }
  }

  /// Deletes [tokens] of a sign-in that could not register its account,
  /// only while storage still holds their refresh token, so tokens another
  /// sign-in stored meanwhile stay. The caller retires the sign-in's
  /// manager first, so nothing writes them back. Whether it deleted them;
  /// never throws.
  Future<bool> takeBack(String accountId, TokenSet tokens) async {
    try {
      return await _tokenStore.mutate(accountId, (store) async {
        final stored = await store.read();
        if (stored?.refreshToken != tokens.refreshToken) return false;
        await store.delete();
        _log.info('Took back the tokens of account $accountId');
        return true;
      });
    } on Object catch (error) {
      _log.warning(
        'Could not take back the tokens of account $accountId: '
        '${error.runtimeType}',
      );
      return false;
    }
  }

  /// Best effort: the session of [tokens] is abandoned locally either way.
  Future<void> abandon(ServerConnection connection, TokenSet tokens) =>
      _endSession(
        connection,
        StoredTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        ),
      );

  Future<SessionEndResolution> _revokeOrphan(
    ServerConnection connection,
    StoredTokens previous,
    AccessTokenSource session,
  ) async {
    final sessionId = JwtClaims.tryParse(previous.accessToken)?.sessionId;
    if (sessionId == null) return SessionEndResolution.unknown;
    try {
      final listed = await _accountGateway.sessions(connection, session);
      if (!listed.any((entry) => entry.id == sessionId)) {
        return SessionEndResolution.goneOnServer;
      }
      await _accountGateway.revokeSession(connection, session, sessionId);
      return SessionEndResolution.orphanRevoked;
    } on Object catch (error) {
      _log.info('Could not look for the old session: ${error.runtimeType}');
      return SessionEndResolution.unknown;
    }
  }

  Future<_Logout> _endSession(
    ServerConnection connection,
    StoredTokens tokens,
  ) async {
    final detached = _DetachedSession(
      tokens,
      refresh: (refreshToken) =>
          _tokenGateway.refresh(connection, refreshToken),
      clock: _clock,
    );
    try {
      await _accountGateway
          .logout(connection, detached)
          .timeout(_logoutTimeout);
      // An access token can outlive its session by minutes: only a refresh
      // the server took proves the session was alive.
      return detached.tookRefresh ? _Logout.ofLiveSession : _Logout.unconfirmed;
    } on SessionEnded {
      return _Logout.refused;
    } on Object catch (error) {
      _log.info('Could not end an abandoned session: ${error.runtimeType}');
      return _Logout.unconfirmed;
    }
  }
}

enum _Logout { ofLiveSession, refused, unconfirmed }

/// Tokens of a session that is being abandoned: refreshed at most once, in
/// memory only, just to be able to log it out.
final class _DetachedSession implements AccessTokenSource {
  new(this._tokens, {required this._refresh, required this._clock});

  final StoredTokens _tokens;
  final RefreshCall _refresh;
  final Clock _clock;
  Future<String>? _refreshed;
  bool _tookRefresh = false;

  /// The server took the old refresh token.
  bool get tookRefresh => _tookRefresh;

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
      _refreshed ??= _refresh(_tokens.refreshToken).then((tokens) {
        _tookRefresh = true;
        return tokens.accessToken;
      });
}
