import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// Captured by tool/capture_trash_fixtures.dart, see trash_codec_test.dart:
// Water the plants (2) restored, Mow the lawn (4) deleted for good, Shed (5)
// restored, the writer's project (8) deleted for good.
const _v2 = '$testServerRoot/api/v2';
const _tasksPage = '$_v2/tasks/deleted?page=1&per_page=50';
const _projectsPage = '$_v2/projects/deleted?page=1&per_page=50';
const _v280 = ServerVersion(2, 8, 0);

TrashPort _port(
  Dio dio, {
  ServerVersion version = _v280,
  bool hasV2 = true,
  int perPage = 50,
}) => createTrashPort(
  dio: dio,
  connection: testConnection(
    version: version,
    hasV2: hasV2,
    maxItemsPerPage: perPage,
  ),
);

FakeRoute _captured(String name) => capturedFixture('trash/${name}_2.8.0');

Map<String, Object?> _body(String name) =>
    jsonDecode(fixtureJson('trash/${name}_2.8.0.json')['body']! as String)
        as Map<String, Object?>;

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

TypeMatcher<NotFound> _notFound(int code) =>
    isA<NotFound>().having((f) => f.code, 'code', code);

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

final Matcher _forbidden = isA<Forbidden>().having(
  (f) => f.code,
  'code',
  isNull,
);

final Matcher _routeAbsent = isA<NotFound>().having(
  (f) => f.routeAbsent,
  'routeAbsent',
  isTrue,
);

/// Answers one request with [route] and checks that nothing else was asked.
Future<void> _expectRefused(
  Future<Object?> Function(TrashPort port) call,
  String request,
  FakeRoute route,
  Matcher failure,
) async {
  final url = request.substring(request.indexOf(' ') + 1);
  final dio = fakeDio({url: route});

  await expectLater(call(_port(dio)), throwsA(failure));
  expect(_calls(dio), [request]);
}

void main() {
  group('tasks', () {
    test('every trashed task, newest deletion first', () async {
      final dio = fakeDio({_tasksPage: _captured('v2_tasks_deleted')});

      final trashed = await _port(dio).tasks();

      expect(_calls(dio), ['GET $_tasksPage']);
      expect(trashed.map((t) => t.task.id), [4, 3, 2]);
      expect(trashed.map((t) => t.deletedBy?.id), [2, -1, 1]);
    });

    test('page after page, the server limit as the page size', () async {
      final dio = fakeDio({
        for (final page in [1, 2])
          '$_v2/tasks/deleted?page=$page&per_page=2': _captured(
            'v2_tasks_deleted_page_$page',
          ),
      });

      final trashed = await _port(dio, perPage: 2).tasks();

      expect(_calls(dio), [
        'GET $_v2/tasks/deleted?page=1&per_page=2',
        'GET $_v2/tasks/deleted?page=2&per_page=2',
      ]);
      expect(trashed.map((t) => t.task.id), [4, 3, 2]);
    });

    test('at most 20 pages', () async {
      final listed =
          (_body('v2_tasks_deleted')['items']! as List<Object?>).first!
              as Map<String, Object?>;
      final dio = fakeDio({
        for (var page = 1; page <= 25; page++)
          '$_v2/tasks/deleted?page=$page&per_page=1': json({
            'items': [
              {...listed, 'id': 100 + page},
            ],
            'total': 25,
            'page': page,
            'per_page': 1,
            'total_pages': 25,
          }),
      });

      final trashed = await _port(dio, perPage: 1).tasks();

      expect(trashed, hasLength(20));
      expect(adapterOf(dio).requests, hasLength(20));
    });

    test('an empty trash, and one a reader sees', () async {
      for (final name in ['v2_tasks_deleted_none', 'v2_tasks_deleted_reader']) {
        final dio = fakeDio({_tasksPage: _captured(name)});

        expect(await _port(dio).tasks(), isEmpty, reason: name);
        expect(_calls(dio), ['GET $_tasksPage']);
      }
    });

    test('a link share is refused with code 1', () async {
      await _expectRefused(
        (port) => port.tasks(),
        'GET $_tasksPage',
        _captured('v2_tasks_deleted_link_share'),
        isA<Forbidden>().having((f) => f.code, 'code', 1),
      );
    });
  });

  group('projects', () {
    test('the topmost trashed projects with their subprojects', () async {
      final dio = fakeDio({_projectsPage: _captured('v2_projects_deleted')});

      final trashed = await _port(dio).projects();

      expect(_calls(dio), ['GET $_projectsPage']);
      expect(trashed.map((t) => t.project.id), [8, 5]);
      expect(trashed.last.subprojects.map((s) => (s.id, s.depth)), [
        (6, 1),
        (7, 2),
      ]);
    });

    test('page after page', () async {
      final page = _body('v2_projects_deleted');
      final items = page['items']! as List<Object?>;
      FakeRoute pageOf(int number) => json({
        ...page,
        'items': [items[number - 1]],
        'page': number,
        'per_page': 1,
        'total_pages': 2,
      });
      final dio = fakeDio({
        '$_v2/projects/deleted?page=1&per_page=1': pageOf(1),
        '$_v2/projects/deleted?page=2&per_page=1': pageOf(2),
      });

      final trashed = await _port(dio, perPage: 1).projects();

      expect(trashed.map((t) => t.project.id), [8, 5]);
      expect(adapterOf(dio).requests, hasLength(2));
    });

    test('an empty trash', () async {
      final dio = fakeDio({
        _projectsPage: _captured('v2_projects_deleted_none'),
      });

      expect(await _port(dio).projects(), isEmpty);
    });
  });

  group('counts', () {
    test('of tasks and of projects', () async {
      final dio = fakeDio({
        '$_v2/tasks/deleted/count': _captured('v2_tasks_deleted_count'),
        '$_v2/projects/deleted/count': _captured('v2_projects_deleted_count'),
      });
      final port = _port(dio);

      expect(await port.taskCount(), const TrashCount(total: 3, byOthers: 2));
      expect(
        await port.projectCount(),
        const TrashCount(total: 2, byOthers: 1),
      );
      expect(_calls(dio), [
        'GET $_v2/tasks/deleted/count',
        'GET $_v2/projects/deleted/count',
      ]);
    });
  });

  group('empty', () {
    test('with what others moved there, answered with 204', () async {
      final dio = fakeDio({
        '$_v2/tasks/deleted?include_others=true': status(204),
        '$_v2/projects/deleted?include_others=true': _captured(
          'v2_projects_empty',
        ),
      });
      final port = _port(dio);

      await port.emptyTasks();
      await port.emptyProjects();

      expect(_calls(dio), [
        'DELETE $_v2/tasks/deleted?include_others=true',
        'DELETE $_v2/projects/deleted?include_others=true',
      ]);
    });

    test('only what the user moved there', () async {
      final dio = fakeDio({
        '$_v2/tasks/deleted?include_others=false': _captured(
          'v2_tasks_empty_own',
        ),
        '$_v2/projects/deleted?include_others=false': status(204),
      });
      final port = _port(dio);

      await port.emptyTasks(includeOthers: false);
      await port.emptyProjects(includeOthers: false);

      expect(_calls(dio), [
        'DELETE $_v2/tasks/deleted?include_others=false',
        'DELETE $_v2/projects/deleted?include_others=false',
      ]);
    });
  });

  group('restoreTask', () {
    test('answers the task with its labels, assignees, reminders and '
        'relations', () async {
      final dio = fakeDio({
        '$_v2/tasks/2/restore': _captured('v2_task_restore'),
      });

      final task = await _port(dio).restoreTask(2);

      expect(_calls(dio), ['POST $_v2/tasks/2/restore']);
      expect(task.id, 2);
      expect(task.title, 'Water the plants');
      expect(task.labels.map((l) => l.id), [1]);
      expect(task.assignees.map((u) => u.username), ['fixturewriter']);
      expect(task.reminders, hasLength(1));
      expect(task.relatedTasks[TaskRelationKind.related], hasLength(1));
      expect(task.updated, DateTime.utc(2026, 11, 9, 11, 33, 47));
    });

    test('a task already live (4042) is read and answered, so a repeated '
        'restore succeeds', () async {
      final dio = fakeDio({
        '$_v2/tasks/2/restore': _captured('v2_task_restore_live'),
        '$_v2/tasks/2': _captured('v2_task_restore'),
      });

      final task = await _port(dio).restoreTask(2);

      expect(_calls(dio), ['POST $_v2/tasks/2/restore', 'GET $_v2/tasks/2']);
      expect(task.id, 2);
      expect(task.labels, hasLength(1));
    });

    test('when that read fails, its failure is thrown', () async {
      final dio = fakeDio({
        '$_v2/tasks/2/restore': _captured('v2_task_restore_live'),
        '$_v2/tasks/2': _captured('v2_task_restore_unknown'),
      });

      await expectLater(_port(dio).restoreTask(2), throwsA(_notFound(4002)));
      expect(_calls(dio), ['POST $_v2/tasks/2/restore', 'GET $_v2/tasks/2']);
    });

    test('refusals are not followed by a read', () async {
      for (final (fixture, failure) in [
        ('v2_task_restore_reader', _forbidden),
        ('v2_task_restore_unknown', _notFound(4002)),
        ('v2_task_restore_archived', _domainError(412, 3008)),
        (
          'v2_task_restore_project_trashed',
          _notFound(3018)
              .having((f) => f.trash?.trashedRootId, 'trashedRootId', 5),
        ),
      ]) {
        await _expectRefused(
          (port) => port.restoreTask(2),
          'POST $_v2/tasks/2/restore',
          _captured(fixture),
          failure,
        );
      }
    });
  });

  group('restoreProject', () {
    test('answers the project with its views and permission', () async {
      final dio = fakeDio({
        '$_v2/projects/5/restore': _captured('v2_project_restore'),
      });

      final project = await _port(dio).restoreProject(5);

      expect(_calls(dio), ['POST $_v2/projects/5/restore']);
      expect(project.id, 5);
      expect(project.title, 'Fixture shed');
      expect(project.views.map((v) => v.kind), [
        ProjectViewKind.list,
        ProjectViewKind.gantt,
        ProjectViewKind.table,
        ProjectViewKind.kanban,
      ]);
      expect(project.maxPermission, Permission.admin);
    });

    test('a 3001 for a live project is read and answered', () async {
      final dio = fakeDio({
        '$_v2/projects/5/restore': _captured('v2_project_restore_live'),
        '$_v2/projects/5': _captured('v2_project_restore'),
      });

      final project = await _port(dio).restoreProject(5);

      expect(_calls(dio), [
        'POST $_v2/projects/5/restore',
        'GET $_v2/projects/5',
      ]);
      expect(project.id, 5);
    });

    test('a 3001 stays when the read fails too', () async {
      for (final read in [
        _captured('v2_project_permanent_gone'),
        _captured('v2_project_restore_writer'),
        refused,
      ]) {
        final dio = fakeDio({
          '$_v2/projects/5/restore': _captured('v2_project_restore_live'),
          '$_v2/projects/5': read,
        });

        await expectLater(
          _port(dio).restoreProject(5),
          throwsA(
            _notFound(3001).having(
              (f) => f.message,
              'message',
              'This project does not exist.',
            ),
          ),
        );
        expect(_calls(dio), [
          'POST $_v2/projects/5/restore',
          'GET $_v2/projects/5',
        ]);
      }
    });

    test('refusals are not followed by a read', () async {
      for (final (fixture, failure) in [
        ('v2_project_restore_writer', _forbidden),
        ('v2_project_restore_parent_trashed', _domainError(412, 3019)),
        ('v2_project_restore_parent_archived', _domainError(412, 3016)),
      ]) {
        await _expectRefused(
          (port) => port.restoreProject(5),
          'POST $_v2/projects/5/restore',
          _captured(fixture),
          failure,
        );
      }
    });
  });

  group('delete forever', () {
    test('a task, answered with 204', () async {
      final dio = fakeDio({
        '$_v2/tasks/4/permanent': _captured('v2_task_permanent'),
      });

      await _port(dio).deleteTaskForever(4);

      expect(_calls(dio), ['DELETE $_v2/tasks/4/permanent']);
    });

    test('a project, answered with 204', () async {
      final dio = fakeDio({
        '$_v2/projects/8/permanent': _captured('v2_project_permanent'),
      });

      await _port(dio).deleteProjectForever(8);

      expect(_calls(dio), ['DELETE $_v2/projects/8/permanent']);
    });

    test('is refused, also for a live or gone item: not idempotent', () async {
      for (final (fixture, failure) in [
        ('v2_task_permanent_writer', _forbidden),
        ('v2_task_permanent_live', _notFound(4002)),
        ('v2_task_permanent_gone', _notFound(4002)),
      ]) {
        await _expectRefused(
          (port) => port.deleteTaskForever(4),
          'DELETE $_v2/tasks/4/permanent',
          _captured(fixture),
          failure,
        );
      }
      await _expectRefused(
        (port) => port.deleteProjectForever(8),
        'DELETE $_v2/projects/8/permanent',
        _captured('v2_project_permanent_gone'),
        _notFound(3001),
      );
    });
  });

  group('without the trash', () {
    final calls = <String, Future<Object?> Function(TrashPort port)>{
      'tasks': (port) => port.tasks(),
      'projects': (port) => port.projects(),
      'taskCount': (port) => port.taskCount(),
      'projectCount': (port) => port.projectCount(),
      'emptyTasks': (port) => port.emptyTasks(),
      'emptyProjects': (port) => port.emptyProjects(),
      'restoreTask': (port) => port.restoreTask(2),
      'restoreProject': (port) => port.restoreProject(5),
      'deleteTaskForever': (port) => port.deleteTaskForever(4),
      'deleteProjectForever': (port) => port.deleteProjectForever(8),
    };

    for (final (what, version, hasV2) in [
      ('2.7.0', const ServerVersion(2, 7, 0), true),
      ('2.7.1', const ServerVersion(2, 7, 1), true),
      ('2.8.0 without v2', _v280, false),
    ]) {
      test('$what: every call is a missing route, without a request', () async {
        final dio = fakeDio({});
        final port = _port(dio, version: version, hasV2: hasV2);

        for (final MapEntry(key: name, value: call) in calls.entries) {
          await expectLater(call(port), throwsA(_routeAbsent), reason: name);
        }
        expect(adapterOf(dio).requests, isEmpty);
      });
    }

    test('a development build has it', () async {
      final dio = fakeDio({_tasksPage: _captured('v2_tasks_deleted_none')});

      final port = _port(dio, version: const ServerVersion.development('dev'));

      expect(await port.tasks(), isEmpty);
      expect(_calls(dio), ['GET $_tasksPage']);
    });
  });
}
