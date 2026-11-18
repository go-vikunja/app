import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/widget_fakes.dart';

// The start after a sign-out that the app did not live to finish: the
// registry has forgotten the account and lists it to delete, its database
// and the notifications it scheduled are still there, and this process
// has built no scheduler for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 18, 9);
  late AuthFakes auth;
  late FakeAccountDatabaseFiles files;
  late FakeNotificationGateway gateway;
  late ProviderContainer container;
  late Map<String, AppDatabase> left;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    auth = AuthFakes();
    files = FakeAccountDatabaseFiles();
    gateway = FakeNotificationGateway();
    left = {};
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (accountId, _) =>
                left[accountId] ??= AppDatabase(NativeDatabase.memory()),
          ),
        ),
        notificationGatewayProvider.overrideWithValue(gateway),
        widgetHostProvider.overrideWithValue(FakeWidgetHost()),
      ],
    );
    addTearDown(container.dispose);
  });

  ScheduledNotificationRow row(String key, int osId) =>
      ScheduledNotificationRow(
        key: key,
        osId: osId,
        taskId: 1,
        kind: 'reminder',
        fireAt: now.add(const Duration(hours: 1)),
        title: 'Water the plants',
        body: 'Reminder · Home',
        exact: true,
        hiddenOnLockScreen: false,
        doneNeedsUnlock: false,
      );

  test('deletes the files and cancels the notifications its table '
      'names, then takes it off the list', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final database = left[alice.id] = AppDatabase(NativeDatabase.memory());
    await database.scheduledNotificationsDao.upsert(row('1:reminder:0', 101));
    await database.scheduledNotificationsDao.upsert(row('1:due', 102));
    await auth.registry.remove(alice.id);
    await container.read(accountsProvider.future);

    expect(await container.read(accountDeletionsProvider).finishAll(), isTrue);

    expect(files.deleted, [alice.id]);
    expect(gateway.cancelled, containsAll([101, 102]));
    expect(gateway.cancelled, contains(sessionReminderOsId(alice.id)));
    expect(await auth.registry.accountsToDelete(), isEmpty);
  });

  test('nothing to do without accounts to delete', () async {
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));

    expect(await container.read(accountDeletionsProvider).finishAll(), isTrue);

    expect(files.deleted, isEmpty);
    expect(gateway.cancelled, isEmpty);
    expect(left, isEmpty);
  });
}
