import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  final created = DateTime.utc(2026, 10, 13, 11, 9, 56);

  ServerNotification notification({
    int id = 368,
    String name = 'task.assigned',
    Map<String, Object?> payload = const {},
    DateTime? readAt,
  }) => ServerNotification(
    id: id,
    name: name,
    payload: payload,
    created: created,
    readAt: readAt,
  );

  group('isRead', () {
    test('false without a read date, true with one', () {
      expect(notification().isRead, isFalse);
      expect(notification(readAt: created).isRead, isTrue);
    });
  });

  group('taskId and projectId', () {
    test('read the ids of a task kind', () {
      final assigned = notification(
        payload: {
          'doer': {'id': 2, 'username': 'bob'},
          'task': {
            'id': 11204,
            'title': 'Water the plants',
            'project_id': 1071,
          },
          'assignee': {'id': 1, 'username': 'alice'},
          'project': {'id': 1071, 'title': 'Garden'},
        },
      );

      expect(assigned.taskId, 11204);
      expect(assigned.projectId, 1071);
    });

    test('a deleted task has no project', () {
      final deleted = notification(
        name: 'task.deleted',
        payload: {
          'doer': {'id': 2, 'username': 'bob'},
          'task': {'id': 11206, 'title': 'Short-lived'},
        },
      );

      expect(deleted.taskId, 11206);
      expect(deleted.projectId, isNull);
    });

    test('a project creation names the new project and no task', () {
      final project = notification(
        name: 'project.created',
        payload: {
          'doer': {'id': 2, 'username': 'bob'},
          'project': {
            'id': 1072,
            'title': 'Balcony',
            'parent_project_id': 1071,
          },
        },
      );

      expect(project.taskId, isNull);
      expect(project.projectId, 1072);
    });

    test('a team membership has neither', () {
      final team = notification(
        name: 'team.member.added',
        payload: {
          'member': {'id': 1, 'username': 'alice'},
          'doer': {'id': 2, 'username': 'bob'},
          'team': {'id': 1, 'name': 'Gardeners'},
        },
      );

      expect(team.taskId, isNull);
      expect(team.projectId, isNull);
    });

    test('are null for an empty payload or ids that are not integers', () {
      expect(notification().taskId, isNull);
      expect(notification().projectId, isNull);

      final odd = notification(
        payload: {
          'task': {'id': '42'},
          'project': 7,
        },
      );
      expect(odd.taskId, isNull);
      expect(odd.projectId, isNull);

      final noIds = notification(
        payload: {
          'task': {'title': 'No id'},
          'project': <String, Object?>{},
        },
      );
      expect(noIds.taskId, isNull);
      expect(noIds.projectId, isNull);
    });

    test('read nested maps of any value type, as JSON decoding gives', () {
      final decoded = notification(
        payload: {
          'task': <String, dynamic>{'id': 42},
          'project': <dynamic, dynamic>{'id': 7},
        },
      );

      expect(decoded.taskId, 42);
      expect(decoded.projectId, 7);
    });
  });

  group('equality', () {
    test('by id, name, created and read date; the payload is ignored', () {
      final a = notification(
        payload: {
          'task': {'id': 1},
        },
      );
      final b = notification(
        payload: {
          'task': {'id': 2},
        },
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(notification(id: 369)));
      expect(a, isNot(notification(name: 'task.comment')));
      expect(a, isNot(notification(readAt: created)));
      expect(
        a,
        isNot(
          ServerNotification(
            id: 368,
            name: 'task.assigned',
            payload: const {},
            created: created.add(const Duration(seconds: 1)),
          ),
        ),
      );
    });
  });
}
