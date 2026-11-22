import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/support/session_end_log.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/features/accounts/application/https_twins.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_hosts.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/guest_fakes.dart';
import '../helpers/notification_fakes.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/task_details_fakes.dart';
import '../helpers/widget_fakes.dart';

/// Every function in lib that makes a stored name of an account id, and
/// how this test covers it. A new one fails the inventory test until it is
/// listed here, filled by `fill` and removed by the wipe.
const _accountNames = <String, String>{
  'core/activity/activity_notifier.dart sessionEndedKey':
      'preferences, filled by fill',
  'core/activity/activity_tray.dart sessionKey': 'the tray, filled by fill',
  'core/activity/activity_tray.dart moreKey': 'the tray, filled by fill',
  'core/attachments/attachment_downloads.dart _checked':
      'stores nothing: checks the id before it becomes a folder name',
  'core/auth/link_share_store.dart hashKey': 'secure storage, a guest',
  'core/auth/link_share_store.dart tokenKey': 'secure storage, a guest',
  'core/auth/link_share_store.dart passwordKey': 'secure storage, a guest',
  'core/auth/server_clock_offsets.dart storageKey':
      'preferences, filled by fill',
  'core/auth/session_diagnostics.dart endKey': 'preferences, filled by fill',
  'core/auth/session_diagnostics.dart refreshInFlightKey':
      'preferences, filled by fill',
  'core/auth/session_diagnostics.dart unreadableSinceKey':
      'preferences, filled by fill',
  'core/auth/token_store.dart refreshTokenKey': 'secure storage, seedAccount',
  'core/auth/token_store.dart accessTokenKey': 'secure storage, seedAccount',
  'core/background/background_run_log.dart lastRunAtKey':
      'preferences, filled by fill',
  'core/background/background_run_log.dart lastAttemptAtKey':
      'preferences, filled by fill',
  'core/background/background_run_log.dart lastOutcomeKey':
      'preferences, filled by fill',
  'core/db/open_account_database.dart accountDatabasePortName':
      "stores nothing: the database isolate's port, gone with the isolate",
  'core/db/open_account_database.dart _databaseName':
      "stores nothing: drift's name; the file is under accounts/<id>/",
  'core/notifications/notification_preferences_store.dart keyFor':
      'preferences, filled by fill',
  'core/notifications/session_reminders.dart key':
      'a scheduled notification, filled by fill',
  'core/storage/comment_drafts.dart keyFor': 'the drafts, filled by fill',
  'core/support/session_end_log.dart keyFor': 'preferences, filled by fill',
  'core/widgets/widget_config.dart snapshotKey':
      'the widget host, filled by fill',
};

final _accountNameBuilder = RegExp(
  r'String (\w+)\(\s*String (?:accountId|account)\b',
);

Set<String> _scanAccountNames(Directory lib) => {
  for (final file in lib.listSync(recursive: true))
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.endsWith('.g.dart') &&
        !p.split(file.path).contains('generated'))
      for (final match in _accountNameBuilder.allMatches(
        file.readAsStringSync(),
      ))
        '${_libPath(file, lib)} ${match[1]}',
};

String _libPath(File file, Directory lib) =>
    p.posix.joinAll(p.split(p.relative(file.path, from: lib.path)));

/// Each store's entries as text, by store.
typedef _Stores = Map<String, Map<String, String>>;

/// Only the stores that hold something of [id], with what they hold.
_Stores _mentioning(_Stores stores, String id) => {
  for (final MapEntry(key: store, value: entries) in stores.entries)
    if ({
          for (final MapEntry(:key, :value) in entries.entries)
            if (key.contains(id) || value.contains(id)) key: value,
        }
        case final mentions when mentions.isNotEmpty)
      store: mentions,
};

Map<String, String> _filesUnder(Directory root) => {
  for (final entity in root.listSync(recursive: true))
    p.relative(entity.path, from: root.path): entity is File
        ? latin1.decode(entity.readAsBytesSync())
        : '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 12, 9);
  late Directory root;
  late AuthFakes auth;
  late FakeNotificationGateway gateway;
  late FakeWidgetHost host;
  late PathProviderAccountDatabaseFiles files;
  late AttachmentDownloads downloads;
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    root = Directory.systemTemp.createTempSync('account_wipe');
    addTearDown(() => root.deleteSync(recursive: true));
    final cache = Directory(p.join(root.path, 'cache'));
    auth = AuthFakes()
      ..imageCacheRoot = () async =>
          Directory(p.join(cache.path, ImageDiskCache.folder));
    files = PathProviderAccountDatabaseFiles(
      supportDirectory: () async => Directory(p.join(root.path, 'support')),
    );
    downloads = AttachmentDownloads(() async => cache);
    gateway = FakeNotificationGateway();
    host = FakeWidgetHost();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        // The schema in memory; the files are placed by _fill.
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) => AppDatabase(NativeDatabase.memory()),
          ),
        ),
        attachmentDownloadsProvider.overrideWithValue(downloads),
        clockProvider.overrideWithValue(() => now),
        notificationGatewayProvider.overrideWithValue(gateway),
        widgetHostProvider.overrideWithValue(host),
      ],
    );
    addTearDown(container.dispose);
  });

  _Stores stores() => {
    'preferences': Map.of(auth.preferences.values),
    'secure storage': Map.of(auth.secureStore.values),
    'drafts': Map.of(auth.drafts.values),
    'files': _filesUnder(root),
    'widgets': {
      for (final MapEntry(:key, :value) in host.snapshots.entries)
        'snapshot $key': value,
      for (final MapEntry(:key, :value) in host.catalogs.entries)
        'catalog $key': value,
      for (final tap in host.actions) 'tap ${tap.id}': tap.accountId,
      for (final MapEntry(:key, :value) in host.placed.entries)
        'config $key': '${value?.key}',
    },
    'notifications': {
      for (final MapEntry(:key, :value) in gateway.pending.entries)
        'pending $key': value.payload,
      for (final MapEntry(:key, :value) in gateway.tray.entries)
        'tray $key': value ?? '',
    },
  };

  /// What a user account keeps besides its registry entry and tokens:
  /// everything a wipe has to remove, filled through the stores' own code.
  Future<void> fill(
    RegisteredAccount entry, {
    required int userId,
    required int widgetId,
  }) async {
    final id = entry.id;
    final preferences = auth.preferences;
    await ServerClockOffsets(preferences).write(id, const Duration(minutes: 2));
    final diagnostics = SessionDiagnostics(preferences);
    await diagnostics.recordEnd(
      id,
      SessionEndDiagnosis(
        at: now,
        cause: SessionEndCause.refreshRejected,
        part: AppPart.app,
      ),
    );
    await diagnostics.refreshSent(
      id,
      token: 'refresh-$id',
      part: AppPart.app,
      at: now,
    );
    await diagnostics.noteUnreadable(id, now);
    await SessionEndLog(preferences)
        .record(id, SessionEndReason.expired, part: AppPart.app);
    final runs = BackgroundRunLog(preferences);
    await runs.recordAccountRun(id, now);
    await runs.recordAttempt(id, now);
    await runs.recordAccountOutcome(
      id,
      BackgroundAccountOutcome.synced,
      at: now,
    );
    await preferences.setString(
      ActivityNotifier.sessionEndedKey(id),
      now.toIso8601String(),
    );
    await container
        .read(notificationPreferencesStoreProvider)
        .write(id, const NotificationPreferences(activity: false));
    await ConfirmedSignInHosts(preferences).signedIn(
      id,
      otherSignInHost(
        accountPagesServer270(
          frontendUrl: Uri.parse('https://auth.example.org/'),
        ),
      ),
    );
    await KeptHttpTwins(preferences).keep(
      id,
      unsent: 1,
      accountIds: {
        for (final other in container.read(accountsProvider).value!.accounts)
          other.id,
      },
    );

    await container
        .read(commentDraftsProvider)
        .save(const CommentComposerDraft(text: 'Half'), account: id, taskId: 1);
    await container
        .read(descriptionDraftsProvider)
        .save(
          const DescriptionDraft(html: '<p>Half</p>', base: ''),
          account: id,
          target: const TaskDescriptionTarget(1),
        );

    final database = await files.pathFor(id);
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      File('$database$suffix').writeAsStringSync('database of $id');
    }
    final uploads = await files.uploadsDirectoryFor(id);
    File(p.join(uploads.path, 'queued.png')).createSync(recursive: true);
    final images = container.read(accountImageDiskCacheProvider(id));
    await images.write('avatar-ab-32', samplePngImage);
    await images.flush();
    (await downloads.fileFor(id, 1, sampleAttachment(id: 2)))
      ..createSync(recursive: true)
      ..writeAsStringSync('attachment of $id');

    final db = container.read(appDatabaseProvider(id));
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([
      sampleTask(
        id: 1,
        title: 'Mine',
        projectId: 7,
        due: now.add(const Duration(hours: 2)),
      ).copyWith(
        createdBy: User(id: userId, username: 'u$userId'),
      ),
    ], syncRunId: 'run');
    await db.syncStateDao.write({
      SyncStateKeys.lastSyncedAt: now.toIso8601String(),
    });
    await container.read(sessionRemindersProvider).update(id);
    for (final key in [ActivityTray.sessionKey(id), ActivityTray.moreKey(id)]) {
      await gateway.showActivity(
        osId: notificationOsIdFor(id, key),
        title: 'Vikunja',
        body: 'Activity',
        payload: NotificationPayload(
          accountId: id,
          taskId: 0,
          key: key,
        ).toJson(),
      );
    }

    final config = WidgetConfig(accountId: id, kind: const TodayKind());
    host
      ..placed[widgetId] = config
      ..snapshots[config.key] = jsonEncode({'account': id, 'rows': 'Mine'})
      ..catalogs[id] = jsonEncode({'account': id, 'projects': 'Work'})
      ..actions.add(
        WidgetDoneTap(
          id: 'tap-$widgetId',
          accountId: id,
          taskId: 1,
          createdAt: now,
        ),
      );
  }

  void expectOnlyOwnLeft(
    _Stores before,
    _Stores after, {
    required String kept,
    required String signedOut,
  }) {
    final keptBefore = _mentioning(before, kept);
    final keptAfter = _mentioning(after, kept);
    for (final MapEntry(key: store, value: entries) in keptBefore.entries) {
      for (final MapEntry(:key, :value) in entries.entries) {
        final shared = key.contains(signedOut) || value.contains(signedOut);
        expect(
          keptAfter[store] ?? const {},
          contains(key),
          reason: "$store: the other account's $key",
        );
        if (!shared) {
          expect(
            keptAfter[store]?[key],
            value,
            reason: "$store: the other account's $key",
          );
        }
      }
    }
  }

  test('after a sign-out nothing of the account is left on the device '
      'besides its widgets\' "Account removed", and all of the other '
      "account's stays", () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    await container.read(accountsProvider.future);
    await fill(alice, userId: 7, widgetId: 1);
    await fill(bob, userId: 8, widgetId: 2);
    container.listen(accountNotificationSchedulersProvider, (_, _) {});
    await pumpEventQueue();
    final before = stores();
    for (final account in [alice.id, bob.id]) {
      expect(_mentioning(before, account).keys, before.keys);
    }
    expect(
      before['notifications']!.values.where(
        (payload) => payload.contains(alice.id),
      ),
      hasLength(4),
      reason: 'the due date, the session reminder and two in the tray',
    );

    await container.read(signOutProvider).call(alice.id);
    await pumpEventQueue();
    final after = stores();

    // The configs and the tombstones stay until the user removes the widgets,
    // so they say why they are empty (decision log: Security and privacy).
    final tombstone = host.snapshot('${alice.id}.today')!;
    expect(tombstone.state, WidgetSnapshotState.accountRemoved);
    expect(tombstone.rows, isEmpty);
    expect(host.calls, contains('deleteForAccount ${alice.id}'));
    final left = _mentioning(after, alice.id);
    expect(left.remove('widgets')!.keys, {
      'snapshot ${alice.id}.today',
      'config 1',
    });
    expect(left, isEmpty);
    expectOnlyOwnLeft(before, after, kept: bob.id, signedOut: alice.id);
  });

  test("after a guest's sign-out nothing of it is left, its share's hash, "
      "token and password included, and the user account's stays", () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final guest = await auth.seedGuest(
      fullServer270(),
      token: issueLinkShareToken(issuedAt: now),
      activate: false,
    );
    await auth.linkShareStore.writePassword(guest.id, 'secret');
    await container.read(accountsProvider.future);
    await fill(alice, userId: 7, widgetId: 1);
    final before = stores();
    expect(
      before['secure storage']!.keys.where((key) => key.contains(guest.id)),
      hasLength(3),
    );

    await container.read(signOutProvider).call(guest.id);
    await pumpEventQueue();
    final after = stores();

    expect(_mentioning(after, guest.id), isEmpty);
    expectOnlyOwnLeft(before, after, kept: alice.id, signedOut: guest.id);
  });

  test('every name made of an account id is in the inventory, with how it '
      'is covered', () {
    final found = _scanAccountNames(Directory('lib'));

    expect(
      found.difference(_accountNames.keys.toSet()),
      isEmpty,
      reason:
          'a new per-account name: fill it in this test, remove it in '
          'accountDataWiper or SignOut, and list it in _accountNames',
    );
    expect(
      _accountNames.keys.toSet().difference(found),
      isEmpty,
      reason: 'entries of no function in lib: remove or rename them',
    );
  });
}
