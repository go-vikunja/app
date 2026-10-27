import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';

part 'sign_out_controller.g.dart';

final _log = Logger('SignOut');

/// True while a sign-out runs. The shell and the account tab both need it:
/// one blocks system back, the other shows the progress.
@Riverpod(keepAlive: true)
class SignOutController extends _$SignOutController {
  @override
  bool build() => false;

  /// Navigation away follows from the account registry. With
  /// [forgetConnectionSettings], the server's connection settings go too,
  /// once no account uses the server any more.
  Future<void> signOut(
    String accountId, {
    bool forgetConnectionSettings = false,
  }) async {
    if (state) return;
    state = true;
    try {
      final origin = forgetConnectionSettings
          ? await _originOf(accountId)
          : null;
      await _prepareNextAccount(accountId);
      await ref.read(signOutProvider).call(accountId);
      if (origin != null) await _forgetIfUnused(origin);
    } finally {
      state = false;
    }
  }

  /// Null when the registry cannot be read: the sign-out goes on and the
  /// settings stay.
  Future<OriginKey?> _originOf(String accountId) async {
    try {
      final registry = await ref.read(accountRegistryProvider).load();
      final root = registry.find(accountId)?.connection.rootUri;
      return root == null ? null : OriginKey.tryOf(root);
    } on Object catch (error) {
      _log.info('Connection settings kept: ${error.runtimeType}');
      return null;
    }
  }

  /// Another account may have been added on the server meanwhile. A
  /// failure leaves the settings behind; the sign-out stands.
  Future<void> _forgetIfUnused(OriginKey origin) async {
    try {
      final registry = await ref.read(accountRegistryProvider).load();
      final used = registry.accounts.any(
        (entry) => OriginKey.tryOf(entry.connection.rootUri) == origin,
      );
      if (!used) await ref.read(networkProfilesProvider).forget(origin);
    } on Object catch (error) {
      _log.info('Connection settings not forgotten: ${error.runtimeType}');
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
