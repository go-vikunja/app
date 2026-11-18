import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/notifications/notification_texts.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_en.dart';

import '../../helpers/fake_timers.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late FakeNotificationGateway gateway;
  late FakeNotificationPreferencesStore preferences;
  late NotificationSchedulers registry;

  setUp(() {
    gateway = FakeNotificationGateway();
    preferences = FakeNotificationPreferencesStore();
    addTearDown(preferences.dispose);
    registry = NotificationSchedulers();
  });

  NotificationScheduler scheduler(String accountId, {AppDatabase? database}) {
    final db = database ?? testDatabase();
    final scheduler = NotificationScheduler(
      accountId: accountId,
      userId: 7,
      db: db,
      gateway: gateway,
      preferences: preferences,
      presentation: () async => (
        describe: describeNotificationsWith(AppLocalizationsEn()),
        privacy: const NotificationPrivacy(),
      ),
      window: 100,
      now: () => DateTime.utc(2026, 10, 12, 9),
      createTimer: FakeTimers().create,
    );
    addTearDown(scheduler.dispose);
    return scheduler;
  }

  int reconciles() => gateway.calls.where((c) => c == 'capabilities').length;

  test('reconcileAll makes every registered account look again', () async {
    registry
      ..register(scheduler('a1'))
      ..register(scheduler('a2'));
    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: true,
    );

    registry.reconcileAll();
    await pumpEventQueue();

    expect(reconciles(), 2);
  });

  test('registering again disposes the earlier scheduler of the account, '
      'which then stays quiet', () async {
    final first = scheduler('a1');
    final second = scheduler('a1');
    registry
      ..register(first)
      ..register(second);

    await first.reconcile();
    await second.reconcile();

    expect(reconciles(), 1);
    expect(registry.find('a1'), same(second));
  });

  test('a re-arm is due for the first scheduler of an account, and for the '
      'next one only while the earlier was disposed before its re-arm '
      'reached the OS', () async {
    expect(registry.register(scheduler('a1')), isTrue);
    expect(registry.register(scheduler('a1')), isFalse);

    final done = scheduler('a2');
    registry.register(done);
    await done.reconcile(rearm: true);
    expect(done.rearmPending, isFalse);
    expect(registry.register(scheduler('a2')), isFalse);

    final cut = scheduler('a3');
    registry.register(cut);
    unawaited(cut.reconcile(rearm: true));
    expect(registry.register(scheduler('a3')), isTrue);
    await pumpEventQueue();
    expect(cut.rearmPending, isTrue);
  });

  test('cancelAll forgets the account; a later reconcileAll skips '
      'it', () async {
    registry.register(scheduler('a1'));

    await registry.cancelAll('a1');
    registry.reconcileAll();
    await pumpEventQueue();

    expect(registry.find('a1'), isNull);
    expect(reconciles(), 0);
  });

  test('cancelAll during a run lets it stop and cancels what it scheduled, '
      'so nothing of the account is left planned', () async {
    final monday = DateTime.utc(2026, 10, 12, 9);
    final db = testDatabase();
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([
      sampleTask(
        id: 1,
        title: 'Water the plants',
        projectId: 7,
        due: monday.add(const Duration(hours: 2)),
        reminders: [
          TaskReminder(reminder: monday.add(const Duration(hours: 1))),
        ],
      ).copyWith(createdBy: const User(id: 7, username: 'alice')),
    ], syncRunId: 'run');
    final a1 = scheduler('a1', database: db);
    registry.register(a1);
    final scheduling = Completer<void>();
    final release = Completer<void>();
    gateway.beforeCall = (call) async {
      if (!call.startsWith('schedule ')) return;
      if (!scheduling.isCompleted) scheduling.complete();
      await release.future;
    };
    final running = a1.reconcile();
    await scheduling.future;

    final cancelling = registry.cancelAll('a1');
    await pumpEventQueue();
    release.complete();
    await running;
    await cancelling;

    expect(gateway.scheduled, hasLength(1));
    expect(gateway.pending, isEmpty);
    expect(registry.find('a1'), isNull);
  });
}
