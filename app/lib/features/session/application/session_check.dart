import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';

part 'session_check.g.dart';

final _log = Logger('SessionCheck');

@Riverpod(keepAlive: true)
SessionCheck sessionCheck(Ref ref) => SessionCheck(
  sessions: ref.watch(sessionManagersProvider),
  accountGateway: ref.watch(accountGatewayProvider),
);

/// Asks the server who is signed in when the app opens or resumes. Routing
/// never waits for it. A session the server ended is noticed here (the
/// session manager marks the account), and an expired access token is
/// refreshed, which keeps an idle session alive.
final class SessionCheck {
  new({
    required this._sessions,
    required this._accountGateway,
    this._clock = DateTime.now,
    this._minInterval = const Duration(minutes: 1),
  });

  final SessionManagers _sessions;
  final AccountGateway _accountGateway;
  final Clock _clock;
  final Duration _minInterval;
  final _lastChecked = <String, DateTime>{};
  final _running = <String>{};

  /// Never throws.
  Future<void> check(RegisteredAccount entry) async {
    if (entry.account.needsReauth || _running.contains(entry.id)) return;
    final now = _clock();
    final last = _lastChecked[entry.id];
    if (last != null && now.difference(last) < _minInterval) return;
    _lastChecked[entry.id] = now;
    _running.add(entry.id);
    try {
      await _accountGateway.currentUser(
        entry.connection,
        _sessions.forAccount(entry.id),
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

  /// The server has just confirmed this session, e.g. at sign-in.
  void noteVerified(String accountId) => _lastChecked[accountId] = _clock();
}
