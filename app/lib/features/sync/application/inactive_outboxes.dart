import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

part 'inactive_outboxes.g.dart';

final _log = Logger('InactiveOutboxes');

/// The outbox of any account, active or not.
abstract interface class AccountOutboxes {
  /// Opens the account's database.
  Future<int> queuedOps(String accountId);

  /// Builds the account's sender when it has none, which starts a drain.
  Future<void> drain(String accountId);
}

@Riverpod(keepAlive: true)
AccountOutboxes accountOutboxes(Ref ref) => _ProviderAccountOutboxes(ref);

final class _ProviderAccountOutboxes implements AccountOutboxes {
  const new(this._ref);

  final Ref _ref;

  @override
  Future<int> queuedOps(String accountId) =>
      _ref.read(appDatabaseProvider(accountId)).outboxDao.count();

  @override
  Future<void> drain(String accountId) =>
      _ref.read(outboxSenderProvider(accountId)).drain();
}

/// Asks the senders of the accounts other than the active one to send what
/// they have queued, so changes made before a switch, or left by an earlier
/// run, are not stuck until that account is active again. Accounts that
/// need a new sign-in are skipped, and a sender is only built for an
/// account with queued ops; once built, it keeps retrying on its own.
final class InactiveOutboxes {
  new({required this._outboxes, required this._accounts});

  final AccountOutboxes _outboxes;
  final AccountRegistryState? Function() _accounts;
  Future<void>? _running;
  var _requested = false;
  var _disposed = false;

  /// Never throws. A call during a check makes it look once more.
  Future<void> check() {
    if (_disposed) return Future.value();
    _requested = true;
    return _running ??= _run().whenComplete(() => _running = null);
  }

  void dispose() => _disposed = true;

  Future<void> _run() async {
    // Not on the caller's stack, which may be a provider's build.
    await Future<void>.value();
    while (_requested && !_disposed) {
      _requested = false;
      for (final accountId in _drainable()) {
        if (_disposed) return;
        final int queued;
        try {
          queued = await _outboxes.queuedOps(accountId);
        } on Object catch (error) {
          _log.warning(
            'Could not count the queued changes of account $accountId: '
            '${error.runtimeType}',
          );
          continue;
        }
        // Switched to, flagged or removed while counting.
        if (queued == 0 || _disposed || !_drainable().contains(accountId)) {
          continue;
        }
        _log.fine('Sending $queued queued changes of account $accountId');
        unawaited(
          Future.sync(() => _outboxes.drain(accountId)).then<void>(
            (_) {},
            onError: (Object error) => _log.warning(
              'Outbox drain of account $accountId failed: '
              '${error.runtimeType}',
            ),
          ),
        );
      }
    }
  }

  List<String> _drainable() {
    final state = _accounts();
    if (state == null) return const [];
    return [
      for (final entry in state.accounts)
        if (entry.id != state.activeAccountId && !entry.account.needsReauth)
          entry.id,
    ];
  }
}

/// Checks the inactive accounts' outboxes while the shell listens: when it
/// starts listening, when the app comes back to the front and when the
/// accounts change. Gone during a sign-out, whose wipe a new sender would
/// race; built again, and so checking again, once it is over. The active
/// account's sender has its own triggers.
@Riverpod(keepAlive: true)
InactiveOutboxes? inactiveOutboxes(Ref ref) {
  if (ref.watch(signOutControllerProvider)) return null;
  final outboxes = InactiveOutboxes(
    outboxes: ref.watch(accountOutboxesProvider),
    // The rebuild that retires this instance may come after a check that
    // was already counting.
    accounts: () => ref.read(signOutControllerProvider)
        ? null
        : ref.read(accountsProvider).value,
  );
  var listened = true;
  void checkWhileListened() {
    if (listened) unawaited(outboxes.check());
  }

  final lifecycle = AppLifecycleListener(onResume: checkWhileListened);
  ref
    ..listen(accountsProvider, (_, _) => checkWhileListened())
    ..onDispose(() {
      lifecycle.dispose();
      outboxes.dispose();
    })
    ..onCancel(() => listened = false)
    ..onResume(() {
      listened = true;
      unawaited(outboxes.check());
    });
  unawaited(outboxes.check());
  return outboxes;
}
