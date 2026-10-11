import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

part 'account_switcher.g.dart';

/// Changes which account the app shows. Everything keyed by the active
/// account follows the registry; the shell closes the previous account's
/// screens.
final class AccountSwitcher {
  new({required this._registry, required this._prepare, required this._busy});

  final AccountRegistry _registry;

  /// Has the account's sync status at hand by the time it is active, so a
  /// switch to an account that has synced before never passes through the
  /// first-sync screen. Never throws.
  final Future<void> Function(String accountId) _prepare;

  /// Whether a sign-in or a sign-out runs. A sign-in activates its account
  /// when it ends, which would undo the switch; a sign-out wipes data a
  /// switch would read.
  final bool Function() _busy;
  var _switching = false;

  /// False when nothing changed: for the active account, an unknown id,
  /// during a sign-in or sign-out and while another switch is under way.
  Future<bool> switchTo(String accountId) async {
    if (_switching || _busy()) return false;
    _switching = true;
    try {
      final state = await _registry.load();
      if (state.activeAccountId == accountId || state.find(accountId) == null) {
        return false;
      }
      await _prepare(accountId);
      if (_busy()) return false;
      final next = await _registry.setActive(accountId);
      return next.activeAccountId == accountId;
    } finally {
      _switching = false;
    }
  }
}

@Riverpod(keepAlive: true)
AccountSwitcher accountSwitcher(Ref ref) => AccountSwitcher(
  registry: ref.watch(accountRegistryProvider),
  prepare: (accountId) => prepareSyncStatus(ref.container, accountId),
  busy: () =>
      ref.read(signOutControllerProvider) ||
      ref.read(signInControllerProvider) is SignInInProgress,
);

/// The queued changes of one account, active or not; opens its database.
@riverpod
Stream<int> accountPendingChanges(Ref ref, String accountId) =>
    ref.watch(appDatabaseProvider(accountId)).outboxDao.watchCount();
