import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_account_settings_repository.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeUserSettingsWritePort server;
  late List<String> names;
  late List<(String, DateTime?, OwnAvatarChange)> avatarNotes;
  late int userReads;
  Exception? readFailure;
  late LocalAccountSettingsRepository repository;

  setUp(() {
    db = testDatabase();
    sync = RecordingSyncEngine();
    server = FakeUserSettingsWritePort(
      settings: const UserSettings(
        name: 'Alice Example',
        timezone: 'Europe/Berlin',
        weekStart: 1,
      ),
    );
    names = [];
    avatarNotes = [];
    userReads = 0;
    readFailure = null;
    repository = LocalAccountSettingsRepository(
      db: db,
      sync: sync,
      write: server,
      currentUser: () async {
        userReads++;
        if (readFailure case final failure?) throw failure;
        return (
          user: server.profile.user,
          profile: server.profile,
          settings: server.settings,
        );
      },
      onName: (name) async => names.add(name),
      noteAvatar: (profile, change) =>
          avatarNotes.add((profile.username, profile.updated, change)),
    );
  });

  Future<Map<String, String>> stored() => db.syncStateDao.readAll();

  Future<UserSettings> storedSettings() async =>
      decodeUserSettings((await stored())[SyncStateKeys.userSettings]);

  Future<UserProfile?> storedProfile() async =>
      decodeUserProfile((await stored())[SyncStateKeys.userProfile]);

  final bumped = fakeProfileUpdated.add(const Duration(seconds: 1));

  group('watch', () {
    test('the defaults before anything is stored', () async {
      expect(await repository.watch().first, const AccountSettingsState());
    });

    test('what the sync stored, then every change', () async {
      final states = <AccountSettingsState>[];
      final subscription = repository.watch().listen(states.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(server.settings),
        SyncStateKeys.userProfile: encodeUserProfile(server.profile),
      });
      await pumpEventQueue();
      await db.syncStateDao.write({SyncStateKeys.lastSyncedAt: 'now'});
      await pumpEventQueue();
      await db.syncStateDao.write({SyncStateKeys.avatarProvider: 'marble'});
      await pumpEventQueue();

      expect(states, [
        const AccountSettingsState(),
        AccountSettingsState(
          settings: server.settings,
          profile: server.profile,
        ),
        AccountSettingsState(
          settings: server.settings,
          profile: server.profile,
          avatarProvider: AvatarProvider.marble,
        ),
      ]);
    });
  });

  group('update', () {
    test('sends only the changes, stores the answer at once and syncs '
        'quietly', () async {
      await repository.update(
        const UserSettingsChanges(
          discoverableByName: true,
          dateDisplay: SettingChange.set(DateDisplay.yearMonthDayDashed),
        ),
      );
      await pumpEventQueue();

      expect(
        server.requests.single,
        'update UserSettingsChanges(discoverableByName: true, '
        'dateDisplay: DateDisplay.yearMonthDayDashed)',
      );
      final settings = await storedSettings();
      expect(settings.discoverableByName, isTrue);
      expect(settings.dateDisplay, DateDisplay.yearMonthDayDashed);
      expect(settings.timezone, 'Europe/Berlin');
      expect(settings.weekStart, 1);
      expect((await storedProfile())?.updated, bumped);
      expect(names, ['Alice Example']);
      expect(avatarNotes, [('alice', bumped, OwnAvatarChange.unchanged)]);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a new name reaches the profile, the known people and the account '
        'list, and the avatar goes', () async {
      await repository.update(const UserSettingsChanges(name: 'Alice Renamed'));

      expect((await storedSettings()).name, 'Alice Renamed');
      expect((await storedProfile())?.name, 'Alice Renamed');
      expect((await db.usersDao.find(7))?.name, 'Alice Renamed');
      expect(names, ['Alice Renamed']);
      expect(avatarNotes, [('alice', bumped, OwnAvatarChange.changed)]);
    });

    test('clearing a setting stores it as unset', () async {
      server.settings = server.settings.copyWith(
        defaultProjectId: 12,
        timeFormat: TimeFormat.twelveHour,
      );

      await repository.update(
        const UserSettingsChanges(
          defaultProjectId: SettingChange.clear(),
          timeFormat: SettingChange.clear(),
        ),
      );

      final settings = await storedSettings();
      expect(settings.defaultProjectId, isNull);
      expect(settings.timeFormat, isNull);
    });

    test('empty changes send nothing', () async {
      await repository.update(const UserSettingsChanges());
      await pumpEventQueue();

      expect(server.requests, isEmpty);
      expect(await stored(), isEmpty);
      expect(sync.refreshAfterWriteCalls, 0);
    });

    test('a refusal changes nothing here and is thrown as it is', () async {
      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(server.settings),
      });
      const refusal = DomainError(400, code: 1025);
      server.failures['update'] = refusal;

      await expectLater(
        repository.update(const UserSettingsChanges(timezone: 'Mars/Phobos')),
        throwsA(same(refusal)),
      );
      await pumpEventQueue();

      expect((await storedSettings()).timezone, 'Europe/Berlin');
      expect((await stored()).containsKey(SyncStateKeys.userProfile), isFalse);
      expect(names, isEmpty);
      expect(avatarNotes, isEmpty);
      expect(sync.refreshAfterWriteCalls, 0);
    });

    test('offline it fails with the network failure', () async {
      server.failure = const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        repository.update(const UserSettingsChanges(weekStart: 0)),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  test('changes go one at a time, in order', () async {
    final first = Completer<void>();
    server.beforeRequest = (request) async {
      if (request.contains('weekStart: 3')) await first.future;
    };

    final one = repository.update(const UserSettingsChanges(weekStart: 3));
    final two = repository.setAvatarProvider(AvatarProvider.marble);
    final three = repository.update(const UserSettingsChanges(weekStart: 4));
    await pumpEventQueue();
    expect(server.requests, ['update UserSettingsChanges(weekStart: 3)']);

    first.complete();
    await Future.wait([one, two, three]);

    expect(server.requests, [
      'update UserSettingsChanges(weekStart: 3)',
      'setAvatarProvider marble',
      'update UserSettingsChanges(weekStart: 4)',
    ]);
    expect((await storedSettings()).weekStart, 4);
  });

  test('a failed change does not hold up the next one', () async {
    server.failures['update'] = const ServerFailure(500);
    final failed = repository.update(const UserSettingsChanges(weekStart: 3));
    final next = repository.setAvatarProvider(AvatarProvider.gravatar);

    await expectLater(failed, throwsA(isA<ServerFailure>()));
    await next;

    expect(server.provider, AvatarProvider.gravatar);
  });

  group('setAvatarProvider', () {
    test('stores the provider and the profile and drops the avatar', () async {
      await repository.setAvatarProvider(AvatarProvider.marble);
      await pumpEventQueue();

      expect(server.requests, ['setAvatarProvider marble']);
      expect((await stored())[SyncStateKeys.avatarProvider], 'marble');
      expect((await storedProfile())?.updated, bumped);
      expect(avatarNotes, [('alice', bumped, OwnAvatarChange.changed)]);
      expect(names, ['Alice Example']);
      expect(sync.refreshAfterWriteCalls, 1);
      expect(
        (await repository.watch().first).avatarProvider,
        AvatarProvider.marble,
      );
    });

    test(
      'upload and the sign-in providers are refused before any request',
      () async {
        for (final provider in [
          AvatarProvider.upload,
          AvatarProvider.ldap,
          AvatarProvider.openid,
        ]) {
          await expectLater(
            repository.setAvatarProvider(provider),
            throwsArgumentError,
            reason: '$provider',
          );
        }

        expect(server.requests, isEmpty);
        expect(server.provider, AvatarProvider.initials);
      },
    );

    test('a read-back that fails still counts: the provider is stored and '
        'the avatar goes', () async {
      await db.syncStateDao.write({
        SyncStateKeys.userProfile: encodeUserProfile(server.profile),
      });
      readFailure = const NetworkFailure(NetworkProblem.timeout);

      await repository.setAvatarProvider(AvatarProvider.defaultAvatar);
      await pumpEventQueue();

      expect((await stored())[SyncStateKeys.avatarProvider], 'default');
      expect((await storedProfile())?.updated, fakeProfileUpdated);
      expect(avatarNotes, [
        ('alice', fakeProfileUpdated, OwnAvatarChange.changed),
      ]);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a refusal changes nothing here', () async {
      server.failure = const DomainError(412, code: 1018);

      await expectLater(
        repository.setAvatarProvider(AvatarProvider.gravatar),
        throwsA(isA<DomainError>()),
      );

      expect(await stored(), isEmpty);
      expect(avatarNotes, isEmpty);
      expect(userReads, 0);
    });
  });

  group('uploadAvatar', () {
    late File image;

    setUp(() async {
      final directory = await Directory.systemTemp.createTemp('avatar');
      addTearDown(() => directory.delete(recursive: true));
      image = File('${directory.path}/cropped avatar.png');
      await image.writeAsBytes(List.generate(3000, (i) => i % 256));
    });

    test('sends the file with its name and length, then stores the upload '
        'provider and the profile', () async {
      await repository.uploadAvatar(image);
      await pumpEventQueue();

      expect(server.requests, ['uploadAvatar cropped avatar.png 3000']);
      expect(server.uploadedBytes.single, await image.readAsBytes());
      expect(server.uploadTimeouts, [uploadTimeoutFor(3000)]);
      expect((await stored())[SyncStateKeys.avatarProvider], 'upload');
      expect(avatarNotes, [('alice', bumped, OwnAvatarChange.changed)]);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a refused image changes nothing here', () async {
      server.failure = const DomainError(400, code: 4032);

      await expectLater(
        repository.uploadAvatar(image),
        throwsA(isA<DomainError>()),
      );

      expect(await stored(), isEmpty);
      expect(avatarNotes, isEmpty);
    });

    test('a file that is gone fails before any request', () async {
      await image.delete();

      await expectLater(
        repository.uploadAvatar(image),
        throwsA(isA<FileSystemException>()),
      );
      expect(server.requests, isEmpty);
    });
  });

  test('refresh stores the settings, the profile and the avatar provider '
      'without a sync', () async {
    server
      ..provider = AvatarProvider.gravatar
      ..profile = UserProfile(
        id: 7,
        username: 'alice',
        name: 'Alice Example',
        isLocalUser: false,
        authProvider: 'Company SSO',
        pendingEmail: 'new@example.org',
        updated: bumped,
      );

    await repository.refresh();
    await pumpEventQueue();

    expect(server.requests, ['avatarProvider']);
    expect(
      await repository.watch().first,
      AccountSettingsState(
        settings: server.settings,
        profile: server.profile,
        avatarProvider: AvatarProvider.gravatar,
      ),
    );
    expect(avatarNotes, [('alice', bumped, OwnAvatarChange.unknown)]);
    expect(names, ['Alice Example']);
    expect(sync.refreshAfterWriteCalls, 0);
  });
}
