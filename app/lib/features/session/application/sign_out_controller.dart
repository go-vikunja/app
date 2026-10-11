import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';

part 'sign_out_controller.g.dart';

/// True while a sign-out runs. The shell and the account tab both need it:
/// one blocks system back, the other shows the progress.
@Riverpod(keepAlive: true)
class SignOutController extends _$SignOutController {
  @override
  bool build() => false;

  /// Navigation away follows from the account registry.
  Future<void> signOut(String accountId) async {
    if (state) return;
    state = true;
    try {
      await _prepareNextAccount(accountId);
      await ref.read(signOutProvider).call(accountId);
    } finally {
      state = false;
    }
  }

  /// Removing the active account activates the most recently active other
  /// one, like a switch.
  Future<void> _prepareNextAccount(String accountId) async {
    final registry = await ref.read(accountRegistryProvider).load();
    if (registry.activeAccountId != accountId) return;
    final next = registry.accountsByRecency
        .where((entry) => entry.id != accountId)
        .firstOrNull;
    if (next != null) await prepareSyncStatus(ref.container, next.id);
  }
}
