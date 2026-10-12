import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

// The real scheduler over an in-memory database under the shell, through
// the sign-out's wiper: the registry change disposes the scheduler's
// provider and closes the database before the wipe runs.
void main() {
  testWidgets("signing out cancels the account's notifications and forgets "
      'its preferences', (tester) async {
    final auth = AuthFakes();
    final now = DateTime.now().toUtc();
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final db = AppDatabase(NativeDatabase.memory());
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([
      sampleTask(
        id: 1,
        title: 'Water the plants',
        projectId: 7,
        reminders: [TaskReminder(reminder: now.add(const Duration(hours: 1)))],
      ).copyWith(createdBy: const User(id: 7, username: 'alice')),
    ], syncRunId: 'run');
    final notifications = NotificationFakes(schedulers: true);
    notifications.preferences.values[entry.id] = const NotificationPreferences(
      dueDates: false,
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: SyncFakes(now: now),
      notifications: notifications,
      overrides: [
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(FakeAccountDatabaseFiles(), open: (_, _) => db),
        ),
      ],
    );
    final reminderId = notificationOsIdFor(entry.id, '1:reminder:0');
    expect(notifications.gateway.pending.keys, [reminderId]);
    final registry = containerOf(tester).read(notificationSchedulersProvider);
    expect(registry.find(entry.id), isNotNull);

    await containerOf(tester)
        .read(signOutControllerProvider.notifier)
        .signOut(entry.id);
    await tester.pumpAndSettle();

    expect(notifications.gateway.calls, contains('cancel $reminderId'));
    expect(notifications.gateway.pending, isEmpty);
    expect(registry.find(entry.id), isNull);
    expect(notifications.preferences.values.containsKey(entry.id), isFalse);
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });
}
