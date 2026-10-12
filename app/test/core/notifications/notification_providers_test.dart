import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences_store.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 12, 9);
  final dueAt = now.add(const Duration(hours: 2));
  late AuthFakes auth;
  late FakeAccountDatabaseFiles files;
  late FakeNotificationGateway gateway;
  late ProviderContainer container;

  setUp(() {
    // One in-memory database per account is the point here.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    auth = AuthFakes();
    files = FakeAccountDatabaseFiles();
    gateway = FakeNotificationGateway();
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
        clockProvider.overrideWithValue(() => now),
        notificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Alice (active) and Bob (inactive), each with one due task of their
  /// own in their database.
  Future<(String alice, String bob)> twoAccounts() async {
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
    for (final (entry, userId) in [(alice, 7), (bob, 8)]) {
      final db = container.read(appDatabaseProvider(entry.id));
      await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Mine', projectId: 7, due: dueAt).copyWith(
          createdBy: User(id: userId, username: 'u$userId'),
        ),
      ], syncRunId: 'run');
    }
    return (alice.id, bob.id);
  }

  test('the window is 60 on iOS and 100 elsewhere', () {
    expect(notificationWindow(TargetPlatform.iOS), 60);
    expect(notificationWindow(TargetPlatform.android), 100);
  });

  test('every signed-in account gets a scheduler while the shell listens; '
      'signing one out cancels its notifications, forgets its preferences '
      'and drops it', () async {
    final (alice, bob) = await twoAccounts();
    final aliceDue = notificationOsIdFor(alice, '1:due');
    final bobDue = notificationOsIdFor(bob, '1:due');
    final preferences = container.read(notificationPreferencesStoreProvider);
    await preferences.write(
      alice,
      const NotificationPreferences(reminders: false),
    );
    await preferences.write(
      bob,
      const NotificationPreferences(reminders: false),
    );

    final schedulers = container.listen(
      accountNotificationSchedulersProvider,
      (_, _) {},
    );
    await pumpEventQueue();

    expect(schedulers.read(), {alice, bob});
    expect(gateway.pending.keys, unorderedEquals([aliceDue, bobDue]));
    final registry = container.read(notificationSchedulersProvider);
    expect(registry.find(alice), isNotNull);
    expect(registry.find(bob), isNotNull);

    await container.read(signOutProvider).call(alice);
    await pumpEventQueue();

    expect(gateway.cancelled, [aliceDue]);
    expect(gateway.pending.keys, [bobDue]);
    expect(schedulers.read(), {bob});
    expect(registry.find(alice), isNull);
    expect(files.deleted, [alice]);
    expect(
      auth.preferences.values.containsKey(
        StoredNotificationPreferences.keyFor(alice),
      ),
      isFalse,
    );
    expect(
      auth.preferences.values.containsKey(
        StoredNotificationPreferences.keyFor(bob),
      ),
      isTrue,
    );
  });

  test('coming back to the front reconciles every scheduler', () async {
    await twoAccounts();
    container.listen(accountNotificationSchedulersProvider, (_, _) {});
    await pumpEventQueue();
    gateway.calls.clear();

    TestWidgetsFlutterBinding.instance
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(gateway.calls.where((c) => c == 'capabilities').length, 2);
    expect(gateway.calls.where((c) => c.startsWith('schedule')), isEmpty);
  });

  test('a scheduler built from the provider keeps the same os ids across '
      'a rebuild', () async {
    final (alice, _) = await twoAccounts();
    final aliceDue = notificationOsIdFor(alice, '1:due');
    await container.read(notificationSchedulerProvider(alice))!.reconcile();
    expect(gateway.pending.keys, [aliceDue]);
    gateway.calls.clear();

    container.invalidate(notificationSchedulerProvider(alice));
    await container.read(notificationSchedulerProvider(alice))!.reconcile();

    expect(gateway.pending.keys, [aliceDue]);
    expect(gateway.calls.where((c) => c.startsWith('schedule')), isEmpty);
    expect(gateway.cancelled, isEmpty);
  });
}
