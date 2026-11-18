import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../../helpers/notification_fakes.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  // On a device on UTC (utcOffsetAt), so that 60 h later falls in the day.
  final monday = DateTime.utc(2026, 11, 16, 1);
  const sixtyHours = Duration(hours: 60);
  late DateTime now;
  late FakeNotificationGateway gateway;
  late Duration Function(DateTime utc) utcOffsetAt;
  late Map<String, Account> accounts;
  late Map<String, DateTime?> contacts;
  late SessionReminders reminders;

  Account user(String id, {bool needsReauth = false}) => Account(
    id: id,
    serverRoot: Uri.parse('https://tasks.example.com'),
    userId: 7,
    username: 'anna',
    displayName: 'Anna',
    addedAt: monday,
    needsReauth: needsReauth,
  );

  final reminderId = sessionReminderOsId('a');

  setUp(() {
    now = monday;
    gateway = FakeNotificationGateway();
    utcOffsetAt = (_) => Duration.zero;
    accounts = {'a': user('a')};
    contacts = {'a': monday};
    reminders = SessionReminders(
      gateway: gateway,
      account: (accountId) async => accounts[accountId],
      lastContact: (accountId) async => contacts[accountId],
      l10n: () => en,
      linkKey: () async => 'link-key',
      now: () => now,
      utcOffsetAt: (utc) => utcOffsetAt(utc),
    );
  });

  test('planned 60 h after the last contact on the activity channel, '
      'naming the server and the user; its payload opens the app', () async {
    await reminders.update('a');

    final reminder = gateway.scheduledActivities.single;
    expect(reminder.osId, reminderId);
    expect(reminder.fireAt, monday.add(sixtyHours));
    expect(
      reminder.title,
      en.sessionReminderNotificationTitle('tasks.example.com'),
    );
    expect(reminder.body, en.sessionReminderNotificationBody('anna'));
    final payload = NotificationPayload.fromJson(reminder.payload);
    expect(payload.accountId, 'a');
    expect(payload.taskId, 0);
    expect(SessionReminders.isKey(payload.key), isTrue);
    expect(payload.linkKey, 'link-key');
    // Not on the reminders channel, and what the tray showed went first.
    expect(gateway.scheduled, isEmpty);
    expect(gateway.calls.where((c) => c.endsWith('$reminderId')), [
      'cancel $reminderId',
      'scheduleActivity $reminderId',
    ]);
  });

  test('a new contact moves it; a move within the step changes nothing '
      'unless forced', () async {
    await reminders.update('a');

    now = contacts['a'] = monday.add(const Duration(minutes: 30));
    await reminders.update('a');
    expect(gateway.scheduledActivities, hasLength(1));

    now = contacts['a'] = monday.add(const Duration(hours: 2));
    await reminders.update('a');
    expect(gateway.scheduledActivities, hasLength(2));
    expect(
      gateway.pending[reminderId]!.fireAt,
      monday.add(const Duration(hours: 2)).add(sixtyHours),
    );

    await reminders.update('a', force: true);
    expect(gateway.scheduledActivities, hasLength(3));
  });

  test(
    'cancelled once the account needs a new sign-in, and only once',
    () async {
      await reminders.update('a');
      gateway.calls.clear();

      accounts['a'] = user('a', needsReauth: true);
      await reminders.update('a');
      await reminders.update('a');

      expect(gateway.pending, isEmpty);
      expect(gateway.calls, ['cancel $reminderId']);
    },
  );

  test('cancelled for an account that is gone', () async {
    await reminders.update('a');
    accounts.remove('a');

    await reminders.update('a');

    expect(gateway.pending, isEmpty);
  });

  test('cancel on sign-out waits for a run in progress, which then cannot '
      'schedule it again', () async {
    final scheduling = Completer<void>();
    gateway.beforeCall = (call) => call.startsWith('scheduleActivity')
        ? scheduling.future
        : Future.value();
    final running = reminders.update('a');
    await pumpEventQueue();

    final cancelling = reminders.cancel('a');
    scheduling.complete();
    await running;
    await cancelling;

    expect(gateway.pending, isEmpty);
    expect(gateway.calls.last, 'cancel $reminderId');
  });

  test('a sign-out in another isolate whose cancel came before this '
      "isolate's schedule does not leave it behind", () async {
    gateway.beforeCall = (call) async {
      if (!call.startsWith('scheduleActivity')) return;
      // The other isolate removes the account and cancels the reminder
      // while this one is about to schedule it.
      accounts.remove('a');
      await gateway.cancel(reminderId);
    };

    await reminders.update('a');

    expect(gateway.pending, isEmpty);
    expect(gateway.calls.last, 'cancel $reminderId');
  });

  test('never for a link-share guest', () async {
    accounts['g'] = Account.linkShare(
      id: 'g',
      serverRoot: Uri.parse('https://tasks.example.com'),
      shareId: 3,
      projectId: 7,
      displayName: 'Garden',
      addedAt: monday,
    );
    contacts['g'] = monday;

    await reminders.update('g', force: true);

    expect(gateway.calls, isEmpty);
  });

  test(
    'not without the notification permission, and the pending one goes',
    () async {
      await reminders.update('a');
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.denied,
        exactAlarms: true,
      );

      await reminders.update('a', force: true);

      expect(gateway.pending, isEmpty);
      expect(gateway.scheduledActivities, hasLength(1));
    },
  );

  test('nothing before the first contact', () async {
    contacts['a'] = null;

    await reminders.update('a');

    expect(gateway.scheduledActivities, isEmpty);
  });

  test('a reminder time that has passed leaves the OS alone: the tray keeps '
      'what it shows until a contact moves it', () async {
    now = monday.add(const Duration(hours: 61));

    await reminders.update('a', force: true);

    expect(gateway.calls, isEmpty);
  });

  test('a contact the device clock puts ahead counts as now', () async {
    contacts['a'] = monday.add(const Duration(hours: 5));

    await reminders.update('a');

    expect(gateway.scheduledActivities.single.fireAt, monday.add(sixtyHours));
  });

  test('a failed schedule is tried again by the next update', () async {
    gateway.beforeCall = (call) async {
      if (call.startsWith('scheduleActivity')) throw StateError('plugin');
    };
    await expectLater(reminders.update('a'), throwsStateError);

    gateway.beforeCall = null;
    await reminders.update('a');

    expect(gateway.pending.keys, [reminderId]);
  });

  test(
    'calls during a run make it look once more, with force if any asked',
    () async {
      final scheduling = Completer<void>();
      gateway.beforeCall = (call) => call.startsWith('scheduleActivity')
          ? scheduling.future
          : Future.value();
      final first = reminders.update('a');
      await pumpEventQueue();
      final second = reminders.update('a');
      final third = reminders.update('a', force: true);
      expect(identical(second, third), isTrue);
      gateway.beforeCall = null;
      scheduling.complete();
      await first;

      expect(gateway.scheduledActivities, hasLength(2));
    },
  );

  group('a reminder that would ring in the night', () {
    Future<DateTime> reminderFor(DateTime contact) async {
      now = contacts['a'] = contact;
      await reminders.update('a');
      return gateway.pending[reminderId]!.fireAt;
    }

    test('rings at 21:00 the evening before, also across midnight; one in '
        'the day stays', () async {
      // Each contact, when 60 h later falls, and when the reminder rings.
      final cases = [
        // Thursday 03:00.
        (DateTime.utc(2026, 11, 16, 15), DateTime.utc(2026, 11, 18, 21)),
        // Thursday 07:59.
        (DateTime.utc(2026, 11, 16, 19, 59), DateTime.utc(2026, 11, 18, 21)),
        // Thursday 08:00.
        (DateTime.utc(2026, 11, 16, 20), DateTime.utc(2026, 11, 19, 8)),
        // Wednesday 23:30.
        (DateTime.utc(2026, 11, 16, 11, 30), DateTime.utc(2026, 11, 18, 21)),
        // Wednesday 14:00.
        (DateTime.utc(2026, 11, 16, 2), DateTime.utc(2026, 11, 18, 14)),
      ];
      for (final (contact, ringsAt) in cases) {
        expect(await reminderFor(contact), ringsAt, reason: '$contact');
      }
    });

    test('by the local time', () async {
      utcOffsetAt = (_) => const Duration(hours: -5);

      // Wednesday 19:00 local, midnight UTC.
      expect(
        await reminderFor(DateTime.utc(2026, 11, 16, 12)),
        DateTime.utc(2026, 11, 19),
      );
      // Friday 03:00 local: Thursday 21:00 local.
      expect(
        await reminderFor(DateTime.utc(2026, 11, 17, 20)),
        DateTime.utc(2026, 11, 20, 2),
      );
    });

    test('at 21:00 on the evening before a change to or from summer time in '
        'the night', () async {
      // Central Europe: summer time ends on 2026-10-25 and starts on
      // 2027-03-28, at 01:00 UTC.
      utcOffsetAt = (utc) =>
          utc.isBefore(DateTime.utc(2026, 10, 25, 1)) ||
              !utc.isBefore(DateTime.utc(2027, 3, 28, 1))
          ? const Duration(hours: 2)
          : const Duration(hours: 1);

      // 05:00 winter time: 21:00 summer time, nine hours earlier.
      expect(
        await reminderFor(DateTime.utc(2026, 10, 22, 16)),
        DateTime.utc(2026, 10, 24, 19),
      );
      // 05:00 summer time: 21:00 winter time, seven hours earlier.
      expect(
        await reminderFor(DateTime.utc(2027, 3, 25, 15)),
        DateTime.utc(2027, 3, 27, 20),
      );
    });

    test('once that evening has come it counts as due: a run in the night '
        'neither takes it from the tray nor rings it again', () async {
      expect(
        await reminderFor(DateTime.utc(2026, 11, 16, 15)),
        DateTime.utc(2026, 11, 18, 21),
      );
      gateway.calls.clear();
      now = DateTime.utc(2026, 11, 18, 23);
      final backgroundRun = SessionReminders(
        gateway: gateway,
        account: (accountId) async => accounts[accountId],
        lastContact: (accountId) async => contacts[accountId],
        l10n: () => en,
        now: () => now,
        utcOffsetAt: (_) => Duration.zero,
      );

      await backgroundRun.update('a');
      await reminders.update('a', force: true);

      expect(gateway.calls, isEmpty);
    });
  });

  group('ids', () {
    test('in a range of their own: negative, below the test notification '
        'and every hashed id', () {
      expect(NotificationOsIds.sessionRemindersLast, lessThan(0));
      expect(
        NotificationOsIds.sessionRemindersLast,
        lessThan(NotificationOsIds.testNotification),
      );
      expect(
        NotificationOsIds.testNotification,
        lessThan(NotificationOsIds.first),
      );
      for (var i = 0; i < 2000; i++) {
        final accountId = 'account-$i';
        final id = sessionReminderOsId(accountId);
        expect(
          id,
          inInclusiveRange(
            NotificationOsIds.sessionRemindersFirst,
            NotificationOsIds.sessionRemindersLast,
          ),
        );
        for (final key in ['$i:due', '$i:reminder:0', 'activity:$i']) {
          expect(notificationOsIdFor(accountId, key), isNot(id));
          expect(
            notificationOsIdFor(accountId, key),
            greaterThanOrEqualTo(NotificationOsIds.first),
          );
        }
      }
      // Probing upwards wraps round to the first hashed id, never below.
      expect(
        nextFreeNotificationOsId(NotificationOsIds.last, {
          NotificationOsIds.last,
        }),
        NotificationOsIds.first,
      );
    });

    test('the same in every isolate, one per account', () {
      expect(sessionReminderOsId('a'), sessionReminderOsId('a'));
      expect(sessionReminderOsId('a'), isNot(sessionReminderOsId('b')));
    });
  });

  group('lastServerContact', () {
    final synced = DateTime.utc(2026, 11, 16, 8);
    final activity = DateTime.utc(2026, 11, 16, 9);

    test('the later of the sync and the activity sync', () {
      expect(
        lastServerContact({
          SyncStateKeys.lastSyncedAt: synced.toIso8601String(),
          SyncStateKeys.activitySyncedAt: activity.toIso8601String(),
        }),
        activity,
      );
      expect(
        lastServerContact({
          SyncStateKeys.lastSyncedAt: activity.toIso8601String(),
          SyncStateKeys.activitySyncedAt: synced.toIso8601String(),
        }),
        activity,
      );
    });

    test('either alone, and none before both or from what cannot be read', () {
      expect(
        lastServerContact({
          SyncStateKeys.lastSyncedAt: synced.toIso8601String(),
        }),
        synced,
      );
      expect(
        lastServerContact({
          SyncStateKeys.activitySyncedAt: activity.toIso8601String(),
          SyncStateKeys.lastSyncedAt: 'yesterday',
        }),
        activity,
      );
      expect(lastServerContact({}), isNull);
    });
  });
}
