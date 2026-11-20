import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/text/server_address_display.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/notifications/application/os_notification_capabilities.dart';
import 'package:vikunja_mobile/features/session/application/session_reminder_updates.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

// The shell's side: the real reminders over an in-memory database per
// account and the notification plugin faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // On a device on UTC, so that 60 h later falls in the day.
  final monday = DateTime.utc(2026, 11, 16, 1);
  const sixtyHours = Duration(hours: 60);
  late DateTime now;
  late AuthFakes auth;
  late FakeNotificationGateway gateway;
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    now = monday;
    auth = AuthFakes();
    gateway = FakeNotificationGateway();
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
        clockProvider.overrideWithValue(() => now),
        utcOffsetAtProvider.overrideWithValue((_) => Duration.zero),
        notificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> contact(RegisteredAccount entry, String key) => container
      .read(appDatabaseProvider(entry.id))
      .syncStateDao
      .write({key: now.toIso8601String()});

  /// Alice, synced just now, as the shell starts listening.
  Future<RegisteredAccount> aliceSynced() async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: monday),
    );
    await container.read(accountsProvider.future);
    await contact(alice, SyncStateKeys.lastSyncedAt);
    return alice;
  }

  DateTime? reminderOf(RegisteredAccount entry) =>
      gateway.pending[sessionReminderOsId(entry.id)]?.fireAt;

  Future<void> listen() async {
    container.listen(sessionReminderUpdatesProvider, (_, _) {});
    await pumpEventQueue();
  }

  test('every signed-in user account gets its reminder, a guest none; a '
      'completed sync or activity sync moves it', () async {
    final guest = await auth.seedGuest(
      fullServer280(root: 'https://other.example.org'),
      token: null,
      activate: false,
    );
    final alice = await aliceSynced();
    await contact(guest, SyncStateKeys.lastSyncedAt);

    await listen();

    expect(container.read(sessionReminderUpdatesProvider), {alice.id});
    expect(reminderOf(alice), monday.add(sixtyHours));
    expect(reminderOf(guest), isNull);

    now = monday.add(const Duration(hours: 3));
    await contact(alice, SyncStateKeys.lastSyncedAt);
    await pumpEventQueue();
    expect(reminderOf(alice), now.add(sixtyHours));

    now = monday.add(const Duration(hours: 6));
    await contact(alice, SyncStateKeys.activitySyncedAt);
    await pumpEventQueue();
    expect(reminderOf(alice), now.add(sixtyHours));
  });

  test('cancelled when the account needs a new sign-in', () async {
    final alice = await aliceSynced();
    await listen();
    expect(reminderOf(alice), isNotNull);

    await container.read(accountRegistryProvider).markNeedsReauth(alice.id);
    await pumpEventQueue();

    expect(reminderOf(alice), isNull);
    expect(gateway.cancelled, contains(sessionReminderOsId(alice.id)));
  });

  test('the Activity switch leaves it alone, as it leaves the "Sign in '
      'again" notice', () async {
    final alice = await aliceSynced();
    await listen();

    await container
        .read(notificationPreferencesStoreProvider)
        .write(alice.id, const NotificationPreferences(activity: false));
    await pumpEventQueue();
    expect(reminderOf(alice), monday.add(sixtyHours));

    now = monday.add(const Duration(hours: 2));
    await contact(alice, SyncStateKeys.lastSyncedAt);
    await pumpEventQueue();
    expect(reminderOf(alice), now.add(sixtyHours));
  });

  test('a change of the device language schedules it again in the new '
      'language', () async {
    final alice = await aliceSynced();
    await listen();
    expect(gateway.scheduledActivities, hasLength(1));

    await container.read(deviceAppLocalizationsProvider.notifier).follow(const [
      Locale('de'),
    ]);
    await pumpEventQueue();

    final de = lookupAppLocalizations(const Locale('de'));
    final reminder = gateway.scheduledActivities.last;
    expect(gateway.scheduledActivities, hasLength(2));
    expect(reminder.fireAt, monday.add(sixtyHours));
    expect(
      reminder.title,
      de.sessionReminderNotificationTitle(
        displayHost(alice.account.serverRoot),
      ),
    );
    expect(
      reminder.body,
      de.sessionReminderNotificationBody(alice.account.username),
    );
  });

  test('a permission granted in the app plans it at once', () async {
    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.notAsked,
      exactAlarms: true,
    );
    final alice = await aliceSynced();
    container.listen(osNotificationCapabilitiesProvider, (_, _) {});
    await listen();
    expect(reminderOf(alice), isNull);

    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: true,
    );
    await container
        .read(osNotificationCapabilitiesProvider.notifier)
        .requestPermission();
    await pumpEventQueue();

    expect(reminderOf(alice), monday.add(sixtyHours));
  });

  test(
    'a permission granted in the system settings is noticed on resume',
    () async {
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.denied,
        exactAlarms: true,
      );
      final alice = await aliceSynced();
      await listen();
      expect(reminderOf(alice), isNull);

      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.granted,
        exactAlarms: true,
      );
      WidgetsBinding.instance
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(reminderOf(alice), monday.add(sixtyHours));
    },
  );
}
