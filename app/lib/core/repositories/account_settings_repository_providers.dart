import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/deleted_account.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'account_settings_repository_providers.g.dart';

@riverpod
AccountSettingsRepository accountSettingsRepositoryFor(
  Ref ref,
  String accountId,
) {
  final registry = ref.watch(accountRegistryProvider);
  final gateway = ref.watch(accountGatewayProvider);
  final sessions = ref.watch(sessionManagersProvider);
  final cache = ref.watch(accountAvatarCacheProvider(accountId));
  // A change outlives the page that started it, and with it this provider.
  return LocalAccountSettingsRepository(
    db: ref.watch(appDatabaseProvider(accountId)),
    sync: ref.watch(syncEngineProvider(accountId)),
    write: ref.watch(userSettingsWritePortProvider(accountId)),
    currentUser: () async {
      final entry = await registry.find(accountId);
      if (entry == null) {
        throw StateError('Account $accountId is not registered');
      }
      // What the server answers a guest; it has no session manager either.
      if (entry.account.isLinkShare) throw const Forbidden(code: 1023);
      final session = sessions.forAccount(accountId);
      return await endingSessionOfDeletedAccount(
        session,
        () => gateway.currentUserWithProfile(entry.connection, session),
      );
    },
    onName: (name) => registry.updateDisplayName(accountId, name),
    noteAvatar: (profile, change) {
      final updated = profile.updated;
      switch (change) {
        case OwnAvatarChange.changed:
          cache.evict(profile.username, updated: updated);
          _evictOnSameServer(ref, accountId, profile.username);
        case OwnAvatarChange.unchanged when updated != null:
          cache.recordUpdated(profile.username, updated);
        case OwnAvatarChange.unknown when updated != null:
          cache.noteUpdated(profile.username, updated);
        case OwnAvatarChange.unchanged || OwnAvatarChange.unknown:
          break;
      }
    },
  );
}

/// Another account on the same server can show this user, as an assignee.
void _evictOnSameServer(Ref ref, String accountId, String username) {
  if (!ref.mounted) return;
  final accounts = ref.read(accountsProvider).value;
  final serverRoot = accounts?.find(accountId)?.account.serverRoot;
  for (final entry in accounts?.accounts ?? const <Never>[]) {
    if (entry.id == accountId || entry.account.serverRoot != serverRoot) {
      continue;
    }
    if (ref.exists(accountAvatarCacheProvider(entry.id))) {
      ref.read(accountAvatarCacheProvider(entry.id)).evict(username);
    }
  }
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
AccountSettingsRepository? accountSettingsRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountSettingsRepositoryForProvider(accountId));
}

/// The active account's settings, profile and avatar provider as stored;
/// empty while nobody is signed in.
@riverpod
Stream<AccountSettingsState> accountSettings(Ref ref) =>
    ref.watch(accountSettingsRepositoryProvider)?.watch() ??
    Stream.value(const AccountSettingsState());
