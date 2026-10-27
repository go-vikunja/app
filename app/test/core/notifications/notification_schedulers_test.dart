import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/notifications/notification_texts.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_en.dart';

import '../../helpers/fake_timers.dart';
import '../../helpers/notification_fakes.dart';
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

  NotificationScheduler scheduler(String accountId) {
    final db = testDatabase();
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

  test('cancelAll forgets the account; a later reconcileAll skips '
      'it', () async {
    registry.register(scheduler('a1'));

    await registry.cancelAll('a1');
    registry.reconcileAll();
    await pumpEventQueue();

    expect(registry.find('a1'), isNull);
    expect(reconciles(), 0);
  });
}
