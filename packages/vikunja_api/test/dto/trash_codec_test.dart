import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/trash_codec.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// Captured by tool/capture_trash_fixtures.dart. In Garden (4) the owner (1)
// deleted Water the plants (2), the link share (1) Rake the leaves (3) and
// the writer (2) Mow the lawn (4). The owner deleted Shed (5) with Tools (6)
// and Screws (7), the writer the project it administers (8).
const _owner = User(id: 1, username: 'fixtureowner');
const _writer = User(id: 2, username: 'fixturewriter');
const _linkShare = User(
  id: -1,
  username: 'link-share-1',
  name: 'Fixture helper (Link Share)',
);

Map<String, Object?> _body(String name) =>
    jsonDecode(fixtureJson('trash/${name}_2.8.0.json')['body']! as String)
        as Map<String, Object?>;

List<Object?> _items(String name) => _body(name)['items']! as List<Object?>;

List<TrashedTask> _tasks(String name) =>
    _items(name).map(parseTrashedTask).toList();

List<TrashedProject> _projects(String name) =>
    _items(name).map(parseTrashedProject).toList();

Map<String, Object?> _firstItemWith(void Function(Map<String, Object?>) edit) {
  final item = {..._items('v2_tasks_deleted').first! as Map<String, Object?>};
  edit(item);
  return item;
}

void main() {
  group('trashed tasks', () {
    test('every field of the task, and when and by whom it was deleted', () {
      final trashed = _tasks('v2_tasks_deleted')
          .singleWhere((trashed) => trashed.task.id == 2);
      final task = trashed.task;

      expect(trashed.deletedAt, DateTime.utc(2026, 11, 9, 11, 33, 45));
      expect(trashed.deletedAt.isUtc, isTrue);
      expect(trashed.deletedBy, _owner);
      expect(trashed.canDeletePermanently, isTrue);

      expect(task.title, 'Water the plants');
      expect(task.projectId, 4);
      expect(task.description, '<p>Every pot</p>');
      expect(task.dueDate, DateTime.utc(2030, 6, 1, 10));
      expect(task.priority, TaskPriority.high);
      expect(task.hexColor, 'e8445a');
      expect(task.identifier, '#2');
      expect(task.index, 2);
      expect(task.labels, [
        Label(
          id: 1,
          title: 'Fixture label',
          hexColor: '1973ff',
          updated: DateTime.utc(2026, 11, 9, 11, 33, 40),
        ),
      ]);
      expect(task.assignees, [_writer]);
      expect(task.reminders, [
        TaskReminder(reminder: DateTime.utc(2030, 6, 1, 9)),
      ]);
      expect(task.relatedTasks[TaskRelationKind.related]!.map((t) => t.title), [
        'Buy soil',
      ]);
      expect(task.createdBy, _owner);
      expect(task.created, DateTime.utc(2026, 11, 9, 11, 33, 42));
      expect(task.updated, DateTime.utc(2026, 11, 9, 11, 33, 44));
      expect(task.bucketId, 0);
      expect(task.position, 0);
    });

    test('newest deletion first, by the writer, a link share with a '
        'negative id and the owner', () {
      final trashed = _tasks('v2_tasks_deleted');

      expect(trashed.map((t) => t.task.id), [4, 3, 2]);
      expect(trashed.map((t) => t.deletedBy), [_writer, _linkShare, _owner]);
      expect(trashed.every((t) => t.canDeletePermanently), isTrue);
    });

    test('without a deleter the server knows: the link share is gone', () {
      final trashed = _tasks('v2_tasks_deleted_deleter_gone');

      expect(trashed.map((t) => t.task.id), [5, 3]);
      expect(trashed.first.deletedBy, _owner);
      expect(trashed.last.deletedBy, isNull);
      expect(trashed.last.deletedAt, DateTime.utc(2026, 11, 9, 11, 33, 46));
    });

    test('the writer sees the same tasks and may delete none for good', () {
      final trashed = _tasks('v2_tasks_deleted_writer');

      expect(trashed.map((t) => t.task.id), [4, 3, 2]);
      expect(trashed.map((t) => t.canDeletePermanently), everyElement(false));
    });

    test('a deleter is never read with an email', () {
      final trashed = parseTrashedTask(
        _firstItemWith(
          (item) => item['deleted_by'] = {
            'id': 2,
            'username': 'fixturewriter',
            'email': 'fixturewriter@example.invalid',
          },
        ),
      );

      expect(trashed.deletedBy, _writer);
    });

    test('a task without deleted_at, or with the zero date, is malformed', () {
      for (final item in [
        _firstItemWith((item) => item.remove('deleted_at')),
        _firstItemWith((item) => item['deleted_at'] = zeroDate),
        _firstItemWith((item) => item['deleted_at'] = null),
      ]) {
        expect(() => parseTrashedTask(item), throwsA(isA<MalformedJson>()));
      }
    });

    test('a list item without deleted_at fails the read through the port as '
        'an unexpected answer', () async {
      final page = _body('v2_tasks_deleted');
      final items = [...page['items']! as List<Object?>];
      items[1] = {...items[1]! as Map<String, Object?>}..remove('deleted_at');
      final dio = fakeDio({
        '$testServerRoot/api/v2/tasks/deleted?page=1&per_page=50': json({
          ...page,
          'items': items,
        }),
      });
      final port = createTrashPort(
        dio: dio,
        connection: testConnection(version: const ServerVersion(2, 8, 0)),
      );

      await expectLater(
        port.tasks(),
        throwsA(
          isA<UnexpectedResponse>()
              .having((f) => f.statusCode, 'status', 200)
              .having((f) => f.message, 'message', contains('deleted_at')),
        ),
      );
    });
  });

  group('trashed projects', () {
    test('the topmost project with its subprojects, shallowest first', () {
      final trashed = _projects('v2_projects_deleted');

      expect(trashed.map((t) => t.project.id), [8, 5]);
      final shed = trashed.last;
      expect(shed.project.title, 'Fixture shed');
      expect(shed.project.parentProjectId, 0);
      expect(shed.project.isArchived, isFalse);
      expect(shed.project.owner, _owner);
      expect(shed.project.position, 327680);
      expect(shed.project.views, isEmpty);
      expect(shed.project.maxPermission, isNull);
      expect(shed.deletedAt, DateTime.utc(2026, 11, 9, 11, 33, 55));
      expect(shed.deletedBy, _owner);
      expect(shed.subprojects, const [
        TrashedSubproject(
          id: 6,
          title: 'Fixture tools',
          parentProjectId: 5,
          depth: 1,
        ),
        TrashedSubproject(
          id: 7,
          title: 'Fixture screws',
          parentProjectId: 6,
          depth: 2,
        ),
      ]);
    });

    test('a project deleted by someone else, without subprojects', () {
      final handedOver = _projects('v2_projects_deleted').first;

      expect(handedOver.project.title, 'Fixture hand-over');
      expect(handedOver.deletedBy, _writer);
      expect(handedOver.subprojects, isEmpty);
    });

    test('null subprojects are none, entries without an id are skipped', () {
      final shed = {
        ..._items('v2_projects_deleted').last! as Map<String, Object?>,
      };

      expect(
        parseTrashedProject({...shed, 'trashed_sub_projects': null})
            .subprojects,
        isEmpty,
      );
      expect(
        parseTrashedProject({
          ...shed,
          'trashed_sub_projects': [
            {'title': 'No id', 'depth': 1},
            'Tools',
            {'id': 6, 'title': 'Fixture tools'},
          ],
        }).subprojects,
        const [
          TrashedSubproject(
            id: 6,
            title: 'Fixture tools',
            parentProjectId: 0,
            depth: 1,
          ),
        ],
      );
    });

    test('a project without deleted_at is malformed', () {
      final shed = {
        ..._items('v2_projects_deleted').last! as Map<String, Object?>,
      }..remove('deleted_at');

      expect(() => parseTrashedProject(shed), throwsA(isA<MalformedJson>()));
    });
  });

  group('counts', () {
    test('the owner: what emptying deletes, and how much others moved', () {
      expect(
        parseTrashCount(_body('v2_tasks_deleted_count')),
        const TrashCount(total: 3, byOthers: 2),
      );
      expect(
        parseTrashCount(_body('v2_projects_deleted_count')),
        const TrashCount(total: 2, byOthers: 1),
      );
    });

    test('the writer may write but delete nothing for good', () {
      for (final name in [
        'v2_tasks_deleted_count_writer',
        'v2_projects_deleted_count_writer',
      ]) {
        expect(
          parseTrashCount(_body(name)),
          const TrashCount(total: 0, byOthers: 0),
        );
      }
    });

    test('without a total the count is malformed', () {
      expect(
        () => parseTrashCount({'by_others': 1}),
        throwsA(isA<MalformedJson>()),
      );
      expect(
        parseTrashCount({'total': 4}),
        const TrashCount(total: 4, byOthers: 0),
      );
    });
  });

  group('details of a 404', () {
    test('a task below a trashed root', () {
      final details = parseTrashDetails(
        _body('v2_task_restore_project_trashed')['details'],
      );

      expect(
        details,
        TrashDetails(
          id: 7,
          deletedAt: DateTime.utc(2026, 11, 9, 11, 33, 55),
          deletedBy: _owner,
          trashedRootId: 5,
          canRestoreRoot: true,
        ),
      );
    });

    test('anything but an object with an int id is none', () {
      for (final json in <Object?>[
        null,
        3,
        'details',
        const <Object?>[],
        const <String, Object?>{},
        const {'id': null},
        const {'id': '7'},
      ]) {
        expect(parseTrashDetails(json), isNull, reason: '$json');
      }
    });
  });
}
