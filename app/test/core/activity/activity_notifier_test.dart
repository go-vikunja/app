import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/core/activity/activity_notification_texts.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations de = lookupAppLocalizations(const Locale('de'));

void main() {
  const me = 5;
  final account = Account(
    id: 'acc',
    serverRoot: Uri.parse('https://tasks.example.com'),
    userId: me,
    username: 'ben',
    displayName: 'Ben',
    addedAt: DateTime.utc(2026, 10),
  );
  const ben = {'id': me, 'username': 'ben', 'name': 'Ben'};
  const carl = {'id': 6, 'username': 'carl', 'name': ''};
  late AppDatabase db;
  late FakeNotificationGateway gateway;
  late FakeNotificationPreferencesStore preferences;
  late MemoryPreferencesStore store;
  late ActivityNotifier notifier;

  setUp(() async {
    db = testDatabase();
    gateway = FakeNotificationGateway();
    preferences = FakeNotificationPreferencesStore();
    addTearDown(preferences.dispose);
    store = MemoryPreferencesStore();
    notifier = ActivityNotifier(
      gateway: gateway,
      preferences: preferences,
      store: store,
      l10n: en,
    );
  });

  Future<List<ServerNotification>> stored(
    List<ServerNotification> notifications,
  ) async {
    await db.serverNotificationsDao.upsertAll(notifications, handled: false);
    return await db.serverNotificationsDao.unhandledUnread();
  }

  group('show', () {
    test('every shown kind on the activity channel, with a payload that '
        'finds the task, then marked handled', () async {
      final fresh = await stored([
        sampleNotification(id: 1, extra: {'assignee': ben}),
        sampleNotification(id: 2, name: 'task.reminder'),
        sampleNotification(id: 3, name: 'project.created', taskId: null),
        sampleNotification(id: 4, name: 'data.export.ready', taskId: null),
      ]);

      expect(await notifier.show(account: account, db: db, fresh: fresh), 2);

      expect(gateway.activities.map((a) => a.osId), [
        notificationOsIdFor('acc', 'activity:1'),
        notificationOsIdFor('acc', 'activity:3'),
      ]);
      final first = gateway.activities.first;
      expect(first.title, 'Water the plants');
      expect(first.body, 'Anna assigned you');
      expect(jsonDecode(first.payload), {
        'account': 'acc',
        'task': 1,
        'key': 'activity:1',
      });
      expect(jsonDecode(gateway.activities.last.payload), {
        'account': 'acc',
        'task': 0,
        'key': 'activity:3',
      });
      expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
    });

    test('never twice', () async {
      final fresh = await stored([sampleNotification(id: 1)]);
      await notifier.show(account: account, db: db, fresh: fresh);

      await notifier.show(
        account: account,
        db: db,
        fresh: await db.serverNotificationsDao.unhandledUnread(),
      );

      expect(gateway.activities, hasLength(1));
    });

    test('nothing with the activity preference off, all handled', () async {
      preferences.values['acc'] = const NotificationPreferences(
        activity: false,
      );
      final fresh = await stored([sampleNotification(id: 1)]);

      expect(await notifier.show(account: account, db: db, fresh: fresh), 0);

      expect(gateway.activities, isEmpty);
      expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
    });

    test('nothing without the notification permission, all handled', () async {
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.denied,
        exactAlarms: true,
      );
      final fresh = await stored([sampleNotification(id: 1)]);

      await notifier.show(account: account, db: db, fresh: fresh);

      expect(gateway.activities, isEmpty);
      expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
    });

    test('a deleted task cannot be opened: its tap opens the inbox', () async {
      final fresh = await stored([
        sampleNotification(id: 1, name: 'task.deleted'),
      ]);

      await notifier.show(account: account, db: db, fresh: fresh);

      expect(jsonDecode(gateway.activities.single.payload), {
        'account': 'acc',
        'task': 0,
        'key': 'activity:1',
      });
    });

    test(
      'of many new ones in a run the newest five come one by one, one '
      "more notification stands for the rest, all in the account's group",
      () async {
        final fresh = await stored([
          for (var id = 1; id <= 8; id++) sampleNotification(id: id),
        ]);

        expect(await notifier.show(account: account, db: db, fresh: fresh), 5);

        expect(gateway.activities.map((a) => a.osId), [
          for (var id = 4; id <= 8; id++)
            notificationOsIdFor('acc', 'activity:$id'),
          notificationOsIdFor('acc', 'inbox:acc'),
        ]);
        final more = gateway.activities.last;
        expect(more.title, 'More activity');
        expect(more.body, '3 more new notifications');
        expect(jsonDecode(more.payload), {
          'account': 'acc',
          'task': 0,
          'key': 'inbox:acc',
        });
        expect(gateway.activities.map((a) => a.group).toSet(), {
          'activity:acc',
        });
        expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
      },
    );

    test('the account keeps its ten newest in the tray, the oldest go; '
        "another account's stay", () async {
      gateway.tray[12345] = jsonEncode({
        'account': 'other',
        'task': 1,
        'key': 'activity:1',
      });
      for (var id = 1; id <= 3; id++) {
        final fresh = await stored([
          for (var n = 1; n <= 5; n++) sampleNotification(id: id * 10 + n),
        ]);
        await notifier.show(account: account, db: db, fresh: fresh);
      }

      expect(gateway.tray.keys.toSet(), {
        for (final id in [21, 22, 23, 24, 25, 31, 32, 33, 34, 35])
          notificationOsIdFor('acc', 'activity:$id'),
        12345,
      });
    });

    test('with several accounts signed in each names its account', () async {
      final fresh = await stored([sampleNotification(id: 1)]);

      await notifier.show(
        account: account,
        db: db,
        fresh: fresh,
        labelled: true,
      );

      expect(gateway.activities.single.subtitle, '@ben · tasks.example.com');
    });

    test('a single account goes without the label', () async {
      final fresh = await stored([sampleNotification(id: 1)]);

      await notifier.show(account: account, db: db, fresh: fresh);

      expect(gateway.activities.single.subtitle, isNull);
    });

    test(
      'a gateway failure leaves the ones not shown yet to the next run',
      () async {
        final fresh = await stored([
          sampleNotification(id: 1),
          sampleNotification(id: 2),
        ]);
        final secondId = notificationOsIdFor('acc', 'activity:2');
        gateway.beforeCall = (call) async {
          if (call == 'showActivity $secondId') throw StateError('plugin');
        };

        await expectLater(
          notifier.show(account: account, db: db, fresh: fresh),
          throwsStateError,
        );

        expect(gateway.activities, hasLength(1));
        expect(
          (await db.serverNotificationsDao.unhandledUnread()).map((n) => n.id),
          [2],
        );
      },
    );
  });

  test('the os id of a notification is the same in every isolate and run', () {
    expect(
      notificationOsIdFor('acc', ActivityTray.activityKey(41)),
      notificationOsIdFor('acc', 'activity:41'),
    );
    expect(
      notificationOsIdFor('acc', 'activity:41'),
      isNot(notificationOsIdFor('other', 'activity:41')),
    );
  });

  group('texts', () {
    ({String title, String body})? describeOrNull(
      ServerNotification notification, [
      AppLocalizations? l10n,
    ]) => describeActivity(
      ActivityItem.fromNotification(notification, userId: me),
      l10n: l10n ?? en,
    );

    ({String title, String body}) describe(
      ServerNotification notification, [
      AppLocalizations? l10n,
    ]) => describeOrNull(notification, l10n)!;

    final comment = sampleNotification(
      id: 1,
      name: 'task.comment',
      extra: {
        'comment': {
          'id': 2,
          'comment':
              '<p>Please check the <strong>pots</strong> '
              '<mention-user data-id="ben">@ben</mention-user> &amp; the '
              'window boxes, too.</p>',
        },
        'mentioned': true,
      },
    );

    test('per kind, in English and German', () {
      final cases = <ServerNotification, (String, String, String)>{
        comment: (
          'Water the plants',
          'Anna commented: Please check the pots @ben & the window boxes, '
              'too.',
          'Anna hat kommentiert: Please check the pots @ben & the window '
              'boxes, too.',
        ),
        sampleNotification(id: 2, extra: {'assignee': ben}): (
          'Water the plants',
          'Anna assigned you',
          'Anna hat dir diese Aufgabe zugewiesen',
        ),
        sampleNotification(id: 3, extra: {'assignee': carl}): (
          'Water the plants',
          'Anna assigned carl',
          'Anna hat diese Aufgabe carl zugewiesen',
        ),
        sampleNotification(id: 4, name: 'task.mentioned'): (
          'Water the plants',
          'Anna mentioned you',
          'Anna hat dich erwähnt',
        ),
        sampleNotification(id: 5, name: 'task.created'): (
          'Water the plants',
          'Anna created this task in Garden',
          'Anna hat diese Aufgabe in Garden erstellt',
        ),
        sampleNotification(id: 6, name: 'task.deleted'): (
          'Water the plants',
          'Anna deleted this task',
          'Anna hat diese Aufgabe gelöscht',
        ),
        sampleNotification(
          id: 7,
          name: 'project.created',
          taskId: null,
          projectTitle: 'Balcony',
        ): (
          'Balcony',
          'Anna created the project Balcony',
          'Anna hat das Projekt Balcony erstellt',
        ),
        sampleNotification(
          id: 8,
          name: 'team.member.added',
          taskId: null,
          extra: {
            'member': ben,
            'team': {'id': 1, 'name': 'Gardeners'},
          },
        ): (
          'Gardeners',
          'Anna added you to the team Gardeners',
          'Anna hat dich zum Team Gardeners hinzugefügt',
        ),
        sampleNotification(
          id: 9,
          name: 'team.member.added',
          taskId: null,
          extra: {
            'member': carl,
            'team': {'id': 1, 'name': 'Gardeners'},
          },
        ): (
          'Gardeners',
          'Anna added carl to the team Gardeners',
          'Anna hat carl zum Team Gardeners hinzugefügt',
        ),
      };
      for (final MapEntry(key: notification, value: (title, english, german))
          in cases.entries) {
        expect(describe(notification).title, title, reason: notification.name);
        expect(describe(notification).body, english, reason: notification.name);
        expect(describe(notification, de).body, german);
      }
    });

    test('the username stands in for an empty display name', () {
      final text = describe(
        sampleNotification(
          id: 1,
          name: 'task.mentioned',
          doer: const User(id: 6, username: 'carl'),
        ),
      );

      expect(text.body, 'carl mentioned you');
    });

    test(
      'a long comment is cut at 80 characters, an empty one is left out',
      () {
        final long = describe(
          sampleNotification(
            id: 1,
            name: 'task.comment',
            extra: {
              'comment': {'comment': '<p>${'word ' * 40}</p>'},
            },
          ),
        ).body;
        expect(long, startsWith('Anna commented: word word'));
        expect(long, endsWith('…'));
        expect(
          long.substring('Anna commented: '.length).characters.length,
          lessThanOrEqualTo(activityCommentLength),
        );

        final empty = describe(
          sampleNotification(
            id: 2,
            name: 'task.comment',
            extra: {
              'comment': {'comment': '<p> </p>'},
            },
          ),
        );
        expect(empty.body, 'Anna commented');
      },
    );

    test('the cut never splits what the user sees as one character', () {
      final family = '👨‍👩‍👧' * 100;
      final body = describe(
        sampleNotification(
          id: 1,
          name: 'task.comment',
          extra: {
            'comment': {'comment': '<p>$family</p>'},
          },
        ),
      ).body;

      final quoted = body.substring('Anna commented: '.length);
      expect(quoted.characters.length, activityCommentLength);
      expect(quoted.characters.take(79).every((c) => c == '👨‍👩‍👧'), isTrue);
    });

    test('a checklist reads as it does in the inbox', () {
      expect(
        describe(
          sampleNotification(
            id: 1,
            name: 'task.comment',
            extra: {
              'comment': {
                'comment':
                    '<ul data-type="taskList"><li data-checked="false"> '
                    '<p>buy soil</p></li></ul>',
              },
            },
          ),
        ).body,
        'Anna commented: ☐ buy soil',
      );
    });

    test('a name the payload lacks gets generic wording, never a blank', () {
      final noDoer = ServerNotification(
        id: 1,
        name: 'task.mentioned',
        payload: const {
          'task': {'id': 1, 'title': 'Water the plants'},
        },
        created: DateTime.utc(2026, 10, 13),
      );
      expect(describe(noDoer).body, 'Someone mentioned you');
      expect(
        describe(sampleNotification(id: 2, extra: {'assignee': const {}})).body,
        'Anna assigned someone to this task',
      );
      expect(
        describe(
          sampleNotification(
            id: 3,
            name: 'team.member.added',
            taskId: null,
            extra: {
              'member': const {'id': 6},
              'team': const {'id': 1},
            },
          ),
          de,
        ).body,
        'Anna hat jemanden zum Team ohne Namen hinzugefügt',
      );
      expect(
        describe(
          ServerNotification(
            id: 4,
            name: 'project.created',
            payload: const {
              'doer': {'id': 9, 'username': 'anna', 'name': 'Anna'},
              'project': {'id': 7},
            },
            created: DateTime.utc(2026, 10, 13),
          ),
        ),
        (title: 'Vikunja', body: 'Anna created the project unnamed'),
      );
    });

    test('task.reminder and unknown kinds have none', () {
      expect(
        describeOrNull(sampleNotification(id: 1, name: 'task.reminder')),
        isNull,
      );
      expect(
        describeOrNull(sampleNotification(id: 2, name: 'data.export.ready')),
        isNull,
      );
    });
  });

  group('session ended', () {
    test(
      'notifies once per ended session, again after a new sign-in',
      () async {
        await notifier.sessionEnded(account);
        await notifier.sessionEnded(account);

        expect(gateway.activities, hasLength(1));
        final notice = gateway.activities.single;
        expect(notice.osId, notificationOsIdFor('acc', 'session:acc'));
        expect(notice.title, 'Sign in again to tasks.example.com');
        expect(notice.body, contains('ben'));
        expect(jsonDecode(notice.payload), {
          'account': 'acc',
          'task': 0,
          'key': 'session:acc',
        });

        await notifier.sessionRestored('acc');
        expect(gateway.cancelled, [notificationOsIdFor('acc', 'session:acc')]);
        expect(gateway.tray, isEmpty);
        await notifier.sessionEnded(account);
        expect(gateway.activities, hasLength(2));
      },
    );

    test('names the port of a server on a non-default one', () async {
      await notifier.sessionEnded(
        Account(
          id: 'acc',
          serverRoot: Uri.parse('http://localhost:34527'),
          userId: me,
          username: 'ben',
          displayName: 'Ben',
          addedAt: DateTime.utc(2026, 10),
        ),
      );

      expect(
        gateway.activities.single.title,
        'Sign in again to localhost:34527',
      );
    });

    test('tells a guest to open the link again, by its name and never its '
        'made-up username', () async {
      Account guest({String? shareName}) => Account.linkShare(
        id: 'g${shareName ?? ''}',
        serverRoot: Uri.parse('https://tasks.example.com'),
        shareId: 84,
        projectId: 1378,
        shareName: shareName,
        displayName: 'Garden',
        addedAt: DateTime.utc(2026, 10),
      );

      await notifier.sessionEnded(guest());
      await notifier.sessionEnded(guest(shareName: 'Helper'));

      expect(gateway.activities.map((a) => a.title), [
        en.guestAccessEndedNotificationTitle('Garden'),
        en.guestAccessEndedNotificationTitle('Helper'),
      ]);
      expect(
        gateway.activities.first.body,
        en.guestAccessEndedNotificationBody('tasks.example.com'),
      );
      for (final notice in gateway.activities) {
        expect('${notice.title} ${notice.body}', isNot(contains('link-share')));
      }
    });

    test('waits for the permission without remembering anything', () async {
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.denied,
        exactAlarms: true,
      );
      await notifier.sessionEnded(account);
      expect(gateway.activities, isEmpty);

      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.granted,
        exactAlarms: true,
      );
      await notifier.sessionEnded(account);
      expect(gateway.activities, hasLength(1));
    });
  });
}
