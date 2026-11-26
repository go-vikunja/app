import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

final _log = Logger('SignOut');

/// Removes what an account keeps on this device besides its tokens and its
/// registry entry: its database and files, drafts, notifications and
/// widget content.
typedef AccountDataWiper = Future<void> Function(String accountId);

/// Deletes the local data of the accounts the registry lists as still to
/// delete: right after a sign-out, and at the next start for one that a
/// crash or a failed wipe left. One wipe per account at a time.
final class AccountDeletions {
  new({
    required this._registry,
    required this._wipe,
    this._cancelScheduled,
    this._wipeUnknown,
    this._cancelTimeout = const Duration(seconds: 10),
  });

  final AccountRegistry _registry;
  final AccountDataWiper _wipe;

  /// Before [finishAll]'s wipes: what the account's database says it has
  /// scheduled, as no notification scheduler of this isolate knows it.
  final Future<void> Function(String accountId)? _cancelScheduled;

  /// After [finishAll]'s wipes, with every account id the registry knows:
  /// deletes what accounts it does not know left behind.
  final Future<void> Function(Set<String> knownAccountIds)? _wipeUnknown;
  final Duration _cancelTimeout;
  final _running = <String, Future<bool>>{};

  /// False, logged, when the wipe failed: the account stays listed for the
  /// next try. An account signed in again meanwhile keeps its data.
  Future<bool> finish(String accountId) {
    if (_running[accountId] case final running?) return running;
    final running = _running[accountId] = _finish(accountId).whenComplete(
      // Not awaited: what the removal returns is this very future.
      () => unawaited(_running.remove(accountId)),
    );
    // Noted before the wipe reads the list: a sign-in that registers the
    // account after that read would lose the database the wipe deletes.
    noteAccountDataDeletion(accountId, running);
    return running;
  }

  /// Every account still listed, then what accounts the registry does not
  /// know left; false when any listed is left. Never throws.
  Future<bool> finishAll() async {
    final List<String> accountIds;
    try {
      accountIds = await _registry.accountsToDelete();
    } on Object catch (error) {
      _log.warning(
        'Could not read the accounts still to delete: ${error.runtimeType}',
      );
      return false;
    }
    // Noted now, not at each account's turn: a sign-in of an account whose
    // turn has not come yet would not wait for its wipe.
    final turns = [
      for (final accountId in accountIds) (accountId, Completer<void>()),
    ];
    for (final (accountId, done) in turns) {
      noteAccountDataDeletion(accountId, done.future);
    }
    var finished = true;
    for (final (accountId, done) in turns) {
      try {
        await _cancelScheduledQuietly(accountId);
        if (!await finish(accountId)) finished = false;
      } finally {
        done.complete();
      }
    }
    await _wipeUnknownQuietly();
    return finished;
  }

  Future<void> _wipeUnknownQuietly() async {
    final wipeUnknown = _wipeUnknown;
    if (wipeUnknown == null) return;
    try {
      if (await _registry.knownAccountIds() case final known?) {
        await wipeUnknown(known);
      }
    } on Object catch (error) {
      _log.warning(
        'Could not delete what unknown accounts left: ${error.runtimeType}',
      );
    }
  }

  /// Off the list once it is signed in again: its files and notifications
  /// are the new session's then, as account ids repeat.
  Future<bool> _listed(String accountId) async =>
      (await _registry.accountsToDelete()).contains(accountId);

  Future<void> _cancelScheduledQuietly(String accountId) async {
    final cancel = _cancelScheduled;
    try {
      if (cancel == null || !await _listed(accountId)) return;
      await cancel(accountId).timeout(_cancelTimeout);
    } on Object catch (error) {
      _log.warning(
        'Could not cancel the notifications of account $accountId: '
        '${error.runtimeType}',
      );
    }
  }

  Future<bool> _finish(String accountId) async {
    try {
      if (!await _listed(accountId)) {
        _log.info('Account $accountId was signed in again; its data stays');
        return true;
      }
      await _wipe(accountId);
      await _registry.dataDeleted(accountId);
    } on Object catch (error) {
      _log.warning(
        'Could not delete the local data of account $accountId: '
        '${error.runtimeType}',
      );
      return false;
    }
    _log.info('Deleted the local data of account $accountId');
    return true;
  }
}

/// Ends the server session if it can, then forgets the account on this
/// device. Signing out never fails because the server is unreachable, nor
/// because the local data could not be deleted, which the next start tries
/// again. A link-share guest has no session on the server to end.
final class SignOut {
  new({
    required this._registry,
    required this._tokenStore,
    required this._linkShareStore,
    required this._clockOffsets,
    required this._sessions,
    required this._linkShares,
    required this._accountGateway,
    required this._deletions,
    this._logoutTimeout = const Duration(seconds: 15),
    this._diagnostics,
    this._clock = DateTime.now,
  });

  final AccountRegistry _registry;
  final TokenStore _tokenStore;
  final LinkShareStore _linkShareStore;
  final ServerClockOffsets _clockOffsets;
  final SessionManagers _sessions;
  final LinkShareSessions _linkShares;
  final AccountGateway _accountGateway;
  final AccountDeletions _deletions;
  final Duration _logoutTimeout;
  final SessionDiagnostics? _diagnostics;
  final Clock _clock;

  Future<void> call(String accountId) async {
    final entry = await _registry.find(accountId);
    if (entry != null &&
        !entry.account.needsReauth &&
        !entry.account.isLinkShare) {
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
    // One at a time with a guest's link stored again, which would leave a
    // removed guest a live session or its hash.
    await _linkShares.exclusive(accountId, () async {
      // Retire first: from then on nothing in this isolate writes the tokens
      // that are wiped next.
      await _sessions.retire(accountId);
      try {
        await _linkShares.retire(accountId);
        // Sibling isolates compare and commit a refresh under this same
        // lock. They either commit before the wipe or see no old token.
        await _tokenStore.mutate(accountId, (store) async {
          await store.delete();
          try {
            await _clockOffsets.delete(accountId);
          } on Object catch (error) {
            _log.info(
              'Could not remove the server clock offset: ${error.runtimeType}',
            );
          }
        });
        await _linkShareStore.delete(accountId);
        await _registry.remove(accountId);
      } on Object {
        // The account stays, but its retired session hands out nothing for
        // good: marked, it offers to sign in again, which replaces it. The
        // end goes on record first: a restore would take an earlier end's
        // record for this one and unmark it (decision log: Several accounts).
        await _recordEnd(accountId);
        await _markNeedsReauthQuietly(accountId);
        rethrow;
      }
      // After the registry: nothing of this account is shown by then, so no
      // screen holds its database open or reads it again.
      await _deletions.finish(accountId);
    });
    _log.info('Signed out account $accountId');
  }

  Future<void> _recordEnd(String accountId) async {
    await _diagnostics?.recordEnd(
      accountId,
      SessionEndDiagnosis(
        at: _clock(),
        cause: SessionEndCause.signOutFailed,
        part: AppPart.app,
      ),
    );
  }

  Future<void> _markNeedsReauthQuietly(String accountId) async {
    try {
      await _registry.markNeedsReauth(accountId);
    } on Object catch (error) {
      _log.warning(
        'Could not mark account $accountId to sign in again: '
        '${error.runtimeType}',
      );
    }
  }
}
