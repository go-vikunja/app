import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  // The session managers run on the real clock.
  final noon = DateTime.now().toUtc();
  late AuthFakes auth;
  late ProviderContainer container;
  late FakeUserSettingsWritePort server;
  late Map<String, List<String>> avatarRequests;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    auth = AuthFakes();
    server = FakeUserSettingsWritePort(
      settings: const UserSettings(name: 'Alice Example'),
    );
    avatarRequests = {};
    final files = FakeAccountDatabaseFiles();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) => AppDatabase(NativeDatabase.memory()),
          ),
        ),
        readClientProvider.overrideWith((ref, _) => FakeSyncClient()),
        userSettingsWritePortProvider.overrideWith((ref, _) => server),
        accountAvatarCacheProvider.overrideWith(
          (ref, accountId) => AvatarCache((username, size) async {
            avatarRequests.putIfAbsent(accountId, () => []).add(username);
            return AvatarImage(
              bytes: Uint8List.fromList([1, 2, 3]),
              contentType: 'image/png',
            );
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<RegisteredAccount> seedAlice() async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    auth.accountGateway.onCurrentUser = (_) async =>
        const User(id: 7, username: 'alice', name: 'Alice Example');
    await container.read(accountsProvider.future);
    return alice;
  }

  void serveProfile({required String name, required DateTime updated}) {
    final user = User(id: 7, username: 'alice', name: name);
    auth.accountGateway
      ..onCurrentUser = ((_) async => user)
      ..profile = UserProfile(
        id: 7,
        username: 'alice',
        name: name,
        authProvider: 'local',
        updated: updated,
      );
  }

  /// GET /user answers what [server] holds, as the real server would.
  void serveFromServer() {
    final gateway = auth.accountGateway;
    gateway.onCurrentUser = (_) async {
      gateway.profile = server.profile;
      return server.profile.user;
    };
  }

  String? displayName(String accountId) => container
      .read(accountsProvider)
      .value
      ?.find(accountId)
      ?.account
      .displayName;

  group('the sync', () {
    test('puts the name from GET /user into the account list', () async {
      final alice = await seedAlice();
      serveProfile(name: 'Alice Renamed', updated: noon);

      await container.read(syncEngineProvider(alice.id)).ensureInitialSync();
      await pumpEventQueue();

      expect(displayName(alice.id), 'Alice Renamed');
      final stored = await container
          .read(accountSettingsRepositoryForProvider(alice.id))
          .watch()
          .first;
      expect(stored.profile, auth.accountGateway.profile);
    });

    test("tells the account's avatar cache the user's updated: a newer one "
        'evicts the own avatar', () async {
      final alice = await seedAlice();
      final cache = container.read(accountAvatarCacheProvider(alice.id));
      final engine = container.read(syncEngineProvider(alice.id));
      serveProfile(name: 'Alice Example', updated: noon);
      await engine.ensureInitialSync();
      await cache.load('alice', 64);

      await engine.refresh();
      expect(cache.generationOf('alice'), 0);
      expect(cache.peek('alice', 64), isNotNull);

      serveProfile(
        name: 'Alice Example',
        updated: noon.add(const Duration(minutes: 1)),
      );
      await engine.refresh();

      expect(cache.generationOf('alice'), 1);
      expect(cache.peek('alice', 64), isNull);
    });
  });

  group('the repository', () {
    test('follows the active account and is null without one', () async {
      await container.read(accountsProvider.future);
      expect(container.read(accountSettingsRepositoryProvider), isNull);
      container.listen(accountSettingsProvider, (_, _) {});
      expect(
        await container.read(accountSettingsProvider.future),
        const AccountSettingsState(),
      );

      final alice = await seedAlice();
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);

      expect(
        container.read(accountSettingsRepositoryProvider),
        same(container.read(accountSettingsRepositoryForProvider(alice.id))),
      );
    });

    test('a name change reaches the account list and evicts the own avatar '
        'here and in other accounts of the same server', () async {
      final alice = await seedAlice();
      final bob = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
        activate: false,
      );
      final carol = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: noon, userId: 9, username: 'carol'),
        activate: false,
      );
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);
      serveFromServer();
      final caches = {
        for (final id in [alice.id, bob.id, carol.id])
          id: container.read(accountAvatarCacheProvider(id)),
      };
      for (final cache in caches.values) {
        await cache.load('alice', 64);
      }

      await container
          .read(accountSettingsRepositoryForProvider(alice.id))
          .update(const UserSettingsChanges(name: 'Alice Renamed'));
      await pumpEventQueue();

      expect(displayName(alice.id), 'Alice Renamed');
      expect(caches[alice.id]!.generationOf('alice'), 1);
      expect(caches[bob.id]!.generationOf('alice'), 1);
      expect(caches[carol.id]!.generationOf('alice'), 0);
    });

    test('a change that leaves the avatar keeps it, also when the sync '
        'reports the bumped updated afterwards', () async {
      final alice = await seedAlice();
      final cache = container.read(accountAvatarCacheProvider(alice.id));
      final engine = container.read(syncEngineProvider(alice.id));
      serveFromServer();
      await engine.ensureInitialSync();
      await cache.load('alice', 64);

      await container
          .read(accountSettingsRepositoryForProvider(alice.id))
          .update(const UserSettingsChanges(weekStart: 1));
      await engine.refresh();

      expect(cache.generationOf('alice'), 0);
      expect(cache.peek('alice', 64), isNotNull);
      expect(avatarRequests[alice.id], ['alice']);
    });

    test('a change that leaves the avatar still evicts it for a newer '
        'updated stored meanwhile, e.g. by a background sync', () async {
      final alice = await seedAlice();
      final cache = container.read(accountAvatarCacheProvider(alice.id))
        ..noteUpdated(
          'alice',
          fakeProfileUpdated.subtract(const Duration(minutes: 2)),
        );
      await cache.load('alice', 64);
      await container.read(appDatabaseProvider(alice.id)).syncStateDao.write({
        SyncStateKeys.userProfile: encodeUserProfile(
          UserProfile(
            id: 7,
            username: 'alice',
            name: 'Alice Example',
            updated: fakeProfileUpdated.subtract(const Duration(minutes: 1)),
          ),
        ),
      });

      await container
          .read(accountSettingsRepositoryForProvider(alice.id))
          .update(const UserSettingsChanges(weekStart: 1));

      expect(cache.generationOf('alice'), 1);
      expect(cache.peek('alice', 64), isNull);
    });

    test('an avatar upload evicts the own avatar, and the cache asks '
        'again once', () async {
      final alice = await seedAlice();
      final cache = container.read(accountAvatarCacheProvider(alice.id));
      final engine = container.read(syncEngineProvider(alice.id));
      serveFromServer();
      await engine.ensureInitialSync();
      await cache.load('alice', 64);

      await container
          .read(accountSettingsRepositoryForProvider(alice.id))
          .setAvatarProvider(AvatarProvider.marble);
      await engine.refresh();
      await cache.load('alice', 64);

      expect(cache.generationOf('alice'), 1);
      expect(avatarRequests[alice.id], ['alice', 'alice']);
    });
  });
}
