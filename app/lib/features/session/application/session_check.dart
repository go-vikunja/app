import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/deleted_account.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';

part 'session_check.g.dart';

final _log = Logger('SessionCheck');

@Riverpod(keepAlive: true)
SessionCheck sessionCheck(Ref ref) => SessionCheck(
  sessions: ref.watch(sessionManagersProvider),
  linkShares: ref.watch(linkShareSessionsProvider),
  accountGateway: ref.watch(accountGatewayProvider),
);

/// Asks the server who is signed in when the app opens or resumes. Routing
/// never waits for it. A session the server ended is noticed here (the
/// session manager marks the account), and an expired access token is
/// refreshed, which keeps an idle session alive.
final class SessionCheck {
  new({
    required this._sessions,
    required this._linkShares,
    required this._accountGateway,
    this._clock = DateTime.now,
    this._minInterval = const Duration(minutes: 1),
  });

  final SessionManagers _sessions;
  final LinkShareSessions _linkShares;
  final AccountGateway _accountGateway;
  final Clock _clock;
  final Duration _minInterval;
  final _lastChecked = <String, DateTime>{};
  final _running = <String>{};
  final _refreshOnNextCheck = <String>{};

  /// Never throws.
  Future<void> check(RegisteredAccount entry) async {
    if (entry.account.needsReauth || _running.contains(entry.id)) return;
    final refresh = _refreshOnNextCheck.remove(entry.id);
    final now = _clock();
    final last = _lastChecked[entry.id];
    if (!refresh && last != null && now.difference(last) < _minInterval) {
      return;
    }
    _lastChecked[entry.id] = now;
    _running.add(entry.id);
    try {
      if (entry.account.isLinkShare) return await _checkGuest(entry);
      final session = _sessions.forAccount(entry.id);
      if (refresh) await session.refreshNow();
      await endingSessionOfDeletedAccount(
        session,
        () => _accountGateway.currentUser(entry.connection, session),
      );
    } on SessionEnded {
      // Marked by the session manager, or the account was signed out.
    } on Object catch (error) {
      _log.info(
        'Session check of account ${entry.id} failed: ${error.runtimeType}',
      );
    } finally {
      _running.remove(entry.id);
    }
  }

  /// The token is renewed when due, and the share is read through the
  /// guest's pseudo user: `/token/test` passes a deleted share's token.
  /// Throws like [check] catches.
  Future<void> _checkGuest(RegisteredAccount entry) async {
    final session = _linkShares.forAccount(entry.id);
    try {
      await _accountGateway.currentUser(entry.connection, session);
    } on LinkShareGone catch (failure) {
      session.noteGone(failure);
      rethrow;
    } on UnexpectedResponse catch (failure) {
      // v2's answer to the token of a deleted share; this client has no
      // LinkShareGoneInterceptor.
      if (failure.statusCode != 401) rethrow;
      final gone = LinkShareGone(message: failure.message);
      session.noteGone(gone);
      throw gone;
    }
  }

  /// Before the user leaves for a page that can end the session, the web's
  /// password or two-factor page: the next [check] of the account (the app
  /// back in front) runs at once and rotates the tokens, because the access
  /// token outlives the session by up to ten minutes.
  void refreshOnNextCheck(String accountId) =>
      _refreshOnNextCheck.add(accountId);

  /// The server has just confirmed this session, e.g. at sign-in.
  void noteVerified(String accountId) => _lastChecked[accountId] = _clock();
}
