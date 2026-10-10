import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

final _log = Logger('SignOut');

/// Removes what an account keeps on this device besides its tokens and its
/// registry entry: the local database.
typedef AccountDataWiper = Future<void> Function(String accountId);

/// Ends the server session if it can, then forgets the account on this
/// device. Signing out never fails because the server is unreachable.
final class SignOut {
  new({
    required this._registry,
    required this._tokenStore,
    required this._clockOffsets,
    required this._sessions,
    required this._accountGateway,
    required this._wipeAccountData,
    this._logoutTimeout = const Duration(seconds: 15),
  });

  final AccountRegistry _registry;
  final TokenStore _tokenStore;
  final ServerClockOffsets _clockOffsets;
  final SessionManagers _sessions;
  final AccountGateway _accountGateway;
  final AccountDataWiper _wipeAccountData;
  final Duration _logoutTimeout;

  Future<void> call(String accountId) async {
    final entry = await _registry.find(accountId);
    if (entry != null && !entry.account.needsReauth) {
      try {
        // The session manager refreshes first if the access token is about
        // to expire, because logout needs a valid one.
        await _accountGateway
            .logout(entry.connection, _sessions.forAccount(accountId))
            .timeout(_logoutTimeout);
      } on Object catch (error) {
        _log.info(
          'Server logout failed, signing out locally: '
          '${redactSecrets('$error')}',
        );
      }
    }
    // Retire first: from then on nothing in this isolate writes the tokens
    // that are wiped next.
    await _sessions.retire(accountId);
    await _tokenStore.delete(accountId);
    try {
      await _clockOffsets.delete(accountId);
    } on Object catch (error) {
      _log.info(
        'Could not remove the server clock offset: ${error.runtimeType}',
      );
    }
    await _registry.remove(accountId);
    // After the registry: nothing of this account is shown by then, so no
    // screen holds its database open or reads it again.
    try {
      await _wipeAccountData(accountId);
    } on Object catch (error) {
      _log.warning(
        'Could not delete the local data of account $accountId: '
        '${error.runtimeType}',
      );
    }
    _log.info('Signed out account $accountId');
  }
}
