import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/features/inbox/application/activity_sections.dart';
import 'package:vikunja_mobile/features/inbox/presentation/activity_texts.dart';

import '../../helpers/pump_app.dart';
import 'inbox_samples.dart';

void main() {
  final created = DateTime.utc(2026, 10, 13, 9);
  final anna = payloadUser(id: 2, username: 'anna', name: 'Anna');
  final ben = payloadUser(id: 3, username: 'ben');
  final me = payloadUser(id: 7, username: 'alice', name: 'Alice');
  final task = payloadTask(id: 40, title: 'Water the plants', index: 12);
  final project = {'id': 3, 'title': 'Garden'};

  ActivityItem item(String name, Map<String, Object?> payload) =>
      ActivityItem.fromNotification(
        inboxNotification(
          id: 1,
          name: name,
          created: created,
          payload: payload,
        ),
        userId: 7,
      );

  group('reads the payload', () {
    test('of a comment', () {
      final comment = item('task.comment', {
        'doer': anna,
        'task': task,
        'project': project,
        'comment': {'id': 9, 'comment': '<p>Looks <b>good</b>\n to me</p>'},
      });

      expect(comment.kind, ActivityKind.comment);
      expect(comment.doerName, 'Anna');
      expect(comment.taskId, 40);
      expect(comment.taskIdentifier, '#12');
      expect(comment.taskTitle, 'Water the plants');
      expect(comment.projectId, 3);
      expect(comment.projectTitle, 'Garden');
      expect(comment.comment, 'Looks good to me');
    });

    test('a prefixed identifier as the server sent it', () {
      final created = item('task.created', {
        'doer': anna,
        'task': payloadTask(
          id: 40,
          title: 'Water the plants',
          index: 12,
          identifier: 'HOME-12',
        ),
      });

      expect(created.taskIdentifier, 'HOME-12');
    });

    test('the username for a user without a name', () {
      expect(item('task.created', {'doer': ben}).doerName, 'ben');
    });

    test('the account’s own user as "you"', () {
      expect(item('task.assigned', {'assignee': me}).targetIsMe, isTrue);
      expect(item('task.assigned', {'assignee': ben}).targetIsMe, isFalse);
      expect(item('task.assigned', {'assignee': ben}).targetName, 'ben');
      expect(item('team.member.added', {'member': me}).targetIsMe, isTrue);
    });

    test('nothing from an empty or odd payload', () {
      final odd = item('migration.done', {
        'doer': 'anna',
        'task': [1, 2],
        'comment': {'comment': 5},
      });

      expect(odd.kind, ActivityKind.other);
      expect(odd.doerName, isNull);
      expect(odd.taskId, isNull);
      expect(odd.taskIdentifier, isNull);
      expect(odd.comment, isNull);
    });
  });

  group('describes', () {
    final cases = {
      'task.comment': (
        {'doer': anna, 'task': task},
        'Anna commented on #12',
        'Anna hat #12 kommentiert',
      ),
      'task.assigned to me': (
        {'doer': anna, 'task': task, 'assignee': me},
        'Anna assigned you to #12',
        'Anna hat dir #12 zugewiesen',
      ),
      'task.assigned to another': (
        {'doer': anna, 'task': task, 'assignee': ben},
        'Anna assigned ben to #12',
        'Anna hat ben #12 zugewiesen',
      ),
      'task.mentioned': (
        {'doer': anna, 'task': task, 'is_new': false},
        'Anna mentioned you on #12',
        'Anna hat dich in #12 erwähnt',
      ),
      'task.created': (
        {'doer': anna, 'task': task, 'project': project},
        'Anna created #12',
        'Anna hat #12 erstellt',
      ),
      'task.deleted': (
        {'doer': anna, 'task': task},
        'Anna deleted #12',
        'Anna hat #12 gelöscht',
      ),
      'project.created': (
        {'doer': anna, 'project': project},
        'Anna created Garden',
        'Anna hat Garden erstellt',
      ),
      'team.member.added me': (
        {
          'doer': anna,
          'member': me,
          'team': {'id': 1, 'name': 'Family'},
        },
        'Anna added you to the Family team',
        'Anna hat dich zum Team Family hinzugefügt',
      ),
      'team.member.added another': (
        {
          'doer': anna,
          'member': ben,
          'team': {'id': 1, 'name': 'Family'},
        },
        'Anna added ben to the Family team',
        'Anna hat ben zum Team Family hinzugefügt',
      ),
      'task.reminder': (
        {'task': task, 'project': project},
        'Reminder for #12',
        'Erinnerung an #12',
      ),
      'migration.done': (
        <String, Object?>{},
        'New notification',
        'Neue Benachrichtigung',
      ),
    };
    for (final MapEntry(key: label, value: (payload, english, german))
        in cases.entries) {
      test(label, () {
        final notification = item(label.split(' ').first, payload);
        expect(describeInboxRow(en, notification), english);
        expect(describeInboxRow(de, notification), german);
      });
    }

    test('a task without an identifier by its title, an unknown doer as '
        'someone', () {
      final notification = item('task.comment', {
        'task': {'id': 40, 'title': 'Water the plants'},
      });

      expect(
        describeInboxRow(en, notification),
        'Someone commented on Water the plants',
      );
    });
  });

  group('groups by day', () {
    final now = DateTime(2026, 10, 13, 15);

    ActivityItem at(int id, DateTime created) => ActivityItem.fromNotification(
      inboxNotification(id: id, name: 'task.created', created: created),
    );

    test('today, yesterday and earlier by the local calendar', () {
      final sections = groupActivityByDay([
        at(5, DateTime(2026, 10, 13, 14)),
        at(4, DateTime(2026, 10, 13)),
        at(3, DateTime(2026, 10, 12, 23, 59)),
        at(2, DateTime(2026, 10, 12)),
        at(1, DateTime(2026, 10, 11, 23, 59)),
      ], now);

      expect([for (final section in sections) section.day], ActivityDay.values);
      expect(
        {
          for (final section in sections)
            section.day: [for (final item in section.items) item.id],
        },
        {
          ActivityDay.today: [5, 4],
          ActivityDay.yesterday: [3, 2],
          ActivityDay.earlier: [1],
        },
      );
    });

    test('only the days that have notifications', () {
      final sections = groupActivityByDay([at(1, DateTime(2026, 9, 2))], now);

      expect(sections.single.day, ActivityDay.earlier);
      expect(groupActivityByDay(const [], now), isEmpty);
    });
  });
}
