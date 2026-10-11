import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _zeroDate = '0001-01-01T00:00:00Z';

VikunjaReadClient _client(
  Dio dio, {
  bool hasV2 = true,
  int maxItemsPerPage = 50,
}) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2, maxItemsPerPage: maxItemsPerPage),
);

/// A v1 list: bare array plus the pagination headers.
FakeRoute _v1List(List<Object?> items, {int? totalPages}) =>
    (_) => ResponseBody.fromString(
      jsonEncode(items),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=UTF-8'],
        if (totalPages != null) 'x-pagination-total-pages': ['$totalPages'],
        'x-pagination-result-count': ['${items.length}'],
      },
    );

Map<String, Object?> _v2Page(
  List<Object?> items, {
  required int totalPages,
  int page = 1,
  int perPage = 50,
  int? total,
}) => {
  'items': items,
  'total': total ?? items.length,
  'page': page,
  'per_page': perPage,
  'total_pages': totalPages,
};

Map<String, Object?> _user(int id, String username) => {
  'id': id,
  'name': '',
  'username': username,
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
};

Map<String, Object?> _project(
  int id, {
  String? title,
  int parent = 0,
  List<Object?>? views,
  bool favorite = false,
}) => {
  'id': id,
  'title': title ?? 'Project $id',
  'description': '',
  'identifier': id > 0 ? 'P$id' : '',
  'hex_color': '',
  'parent_project_id': parent,
  'owner': _user(1, 'alice'),
  'is_archived': false,
  'background_information': null,
  'background_blur_hash': '',
  'is_favorite': favorite,
  'position': id * 65536.0,
  'views': views,
  'max_permission': null,
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
};

Map<String, Object?> _view(
  int id,
  String kind, {
  int projectId = 7,
  Map<String, Object?>? filter,
}) => {
  'id': id,
  'title': kind,
  'project_id': projectId,
  'view_kind': kind,
  'filter': filter,
  'position': id * 100.0,
  'bucket_configuration_mode': kind == 'kanban' ? 'manual' : 'none',
  'bucket_configuration': null,
  'default_bucket_id': kind == 'kanban' ? 30 : 0,
  'done_bucket_id': kind == 'kanban' ? 32 : 0,
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
};

Map<String, Object?> _label(int id, String title, {String hexColor = ''}) => {
  'id': id,
  'title': title,
  'description': '',
  'hex_color': hexColor,
  'created_by': _user(1, 'alice'),
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
};

/// A task as 2.7.0 sends it: empty collections are null.
Map<String, Object?> _task(
  int id, {
  Map<String, Object?> overrides = const {},
}) => {
  'id': id,
  'title': 'Task $id',
  'description': '',
  'done': false,
  'done_at': _zeroDate,
  'due_date': _zeroDate,
  'reminders': null,
  'project_id': 7,
  'repeat_after': 0,
  'repeat_mode': 0,
  'priority': 0,
  'start_date': _zeroDate,
  'end_date': _zeroDate,
  'assignees': null,
  'labels': null,
  'hex_color': '',
  'percent_done': 0,
  'identifier': 'P7-$id',
  'index': id,
  'related_tasks': <String, Object?>{},
  'attachments': null,
  'cover_image_attachment_id': 0,
  'is_favorite': false,
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
  'bucket_id': 0,
  'position': 0,
  'reactions': null,
  'created_by': _user(1, 'alice'),
  ...overrides,
};

void main() {
  group('projects', () {
    test('v2 list parses the envelope', () async {
      final dio = fakeDio({
        '$_v2/projects?page=1': json(
          _v2Page([_project(1), _project(2)], totalPages: 2, total: 3),
        ),
      });

      final page = await _client(dio).projects.list();

      expect(page.items.map((p) => p.id), [1, 2]);
      expect(page.items.first.title, 'Project 1');
      expect(page.items.first.identifier, 'P1');
      expect(page.items.first.owner, const User(id: 1, username: 'alice'));
      expect(page.page, 1);
      expect(page.perPage, 50);
      expect(page.totalPages, 2);
      expect(page.total, 3);
      expect(page.hasMore, isTrue);
      expect(adapterOf(dio).requests.single.method, 'GET');
      expect(
        adapterOf(dio).requests.single.headers['Accept'],
        'application/json',
      );
    });

    test(
      'v1 list parses the pagination headers and reports no total',
      () async {
        final dio = fakeDio({
          '$_v1/projects?page=2&per_page=100': _v1List([
            _project(3),
          ], totalPages: 2),
        });

        final page = await _client(
          dio,
          hasV2: false,
        ).projects.list(page: 2, perPage: 100);

        expect(page.items.map((p) => p.id), [3]);
        expect(page.page, 2);
        // The server caps per_page at max_items_per_page.
        expect(page.perPage, 50);
        expect(page.totalPages, 2);
        expect(page.total, isNull);
        expect(page.hasMore, isFalse);
      },
    );

    test('v1 list without a page size uses the server default', () async {
      final dio = fakeDio({
        '$_v1/projects?page=1': _v1List([_project(1)], totalPages: 1),
      });

      final page = await _client(
        dio,
        hasV2: false,
        maxItemsPerPage: 25,
      ).projects.list();

      expect(page.perPage, 25);
    });

    test('v1 list without the total-pages header is a single page', () async {
      final dio = fakeDio({
        '$_v1/projects?page=1': _v1List([_project(1)]),
      });

      final page = await _client(dio, hasV2: false).projects.list();

      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('v1 empty list', () async {
      final dio = fakeDio({'$_v1/projects?page=1': _v1List([], totalPages: 0)});

      final page = await _client(dio, hasV2: false).projects.list();

      expect(page.items, isEmpty);
      expect(page.totalPages, 0);
      expect(page.hasMore, isFalse);
    });

    for (final (hasV2, url) in [
      (true, '$_v2/projects?is_archived=true&q=foo+bar&page=1&per_page=10'),
      (false, '$_v1/projects?is_archived=true&s=foo+bar&page=1&per_page=10'),
    ]) {
      test('archived and search parameters: $url', () async {
        final dio = fakeDio({
          url: hasV2
              ? json(_v2Page([], totalPages: 0))
              : _v1List([], totalPages: 0),
        });

        await _client(
          dio,
          hasV2: hasV2,
        ).projects.list(includeArchived: true, search: 'foo bar', perPage: 10);

        expect(adapterOf(dio).requestedUrls, [url]);
      });
    }

    for (final hasV2 in [true, false]) {
      test('listAll walks every page and de-duplicates pseudo projects '
          '(${hasV2 ? 'v2' : 'v1'})', () async {
        final favorites = _project(-1, title: 'Favorites', favorite: true);
        final filter = _project(-2, title: 'My Open Tasks');
        final base = hasV2 ? _v2 : _v1;
        FakeRoute page(List<Object?> items, int number) => hasV2
            ? json(_v2Page(items, page: number, totalPages: 2, total: 3))
            : _v1List(items, totalPages: 2);
        final dio = fakeDio({
          '$base/projects?page=1': page([_project(1), favorites, filter], 1),
          '$base/projects?page=2': page([_project(2), favorites, filter], 2),
        });

        final projects = await _client(dio, hasV2: hasV2).projects.listAll();

        expect(projects.map((p) => p.id), [1, -1, -2, 2]);
        expect(projects.where((p) => p.isPseudo).length, 2);
        expect(projects.singleWhere((p) => p.id == -2).savedFilterId, 1);
        expect(adapterOf(dio).requestedUrls, [
          '$base/projects?page=1',
          '$base/projects?page=2',
        ]);
      });
    }

    test('listAll passes includeArchived on', () async {
      final dio = fakeDio({
        '$_v2/projects?is_archived=true&page=1': json(
          _v2Page([_project(1)], totalPages: 1),
        ),
      });

      await _client(dio).projects.listAll(includeArchived: true);

      expect(
        adapterOf(dio).requestedUrls.single,
        endsWith('is_archived=true&page=1'),
      );
    });

    test('read includes the views with their filters', () async {
      final dio = fakeDio({
        '$_v2/projects/7': json(
          _project(
            7,
            parent: 3,
            views: [
              _view(
                21,
                'list',
                filter: {
                  'filter': 'done = false',
                  's': '',
                  'sort_by': ['position'],
                  'order_by': ['asc'],
                  'filter_include_nulls': false,
                },
              ),
              _view(22, 'gantt'),
              _view(23, 'table'),
              _view(24, 'kanban'),
              _view(25, 'timeline'),
            ],
          ),
        ),
      });

      final project = await _client(dio).projects.read(7);

      expect(project.id, 7);
      expect(project.parentProjectId, 3);
      expect(project.isTopLevel, isFalse);
      expect(project.views.map((v) => v.kind), [
        ProjectViewKind.list,
        ProjectViewKind.gantt,
        ProjectViewKind.table,
        ProjectViewKind.kanban,
      ]);
      final list = project.views.first;
      expect(list.id, 21);
      expect(list.projectId, 7);
      expect(list.filter?.filter, 'done = false');
      expect(list.filter?.sortBy, ['position']);
      expect(list.filter?.orderBy, ['asc']);
      expect(list.filter?.includeNulls, isFalse);
      expect(list.bucketConfigurationMode, BucketConfigurationMode.none);
      final kanban = project.views.last;
      expect(kanban.filter, isNull);
      expect(kanban.bucketConfigurationMode, BucketConfigurationMode.manual);
      expect(kanban.defaultBucketId, 30);
      expect(kanban.doneBucketId, 32);
    });

    test('a project without views has none', () async {
      final dio = fakeDio({'$_v2/projects/7': json(_project(7))});

      expect((await _client(dio).projects.read(7)).views, isEmpty);
    });

    test('a project without id is unexpected', () async {
      final dio = fakeDio({
        '$_v2/projects/7': json({'title': 'no id'}),
      });

      await expectLater(
        _client(dio).projects.read(7),
        throwsA(
          isA<UnexpectedResponse>()
              .having((f) => f.statusCode, 'statusCode', 200)
              .having((f) => f.message, 'message', 'project without id'),
        ),
      );
    });

    test('a list item without id fails the page', () async {
      final dio = fakeDio({
        '$_v2/projects?page=1': json(
          _v2Page([
            _project(1),
            {'title': 'no id'},
          ], totalPages: 1),
        ),
      });

      await expectLater(
        _client(dio).projects.list(),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('a v2 list without the envelope is unexpected', () async {
      final dio = fakeDio({
        '$_v2/projects?page=1': json([_project(1)]),
      });

      await expectLater(
        _client(dio).projects.list(),
        throwsA(
          isA<UnexpectedResponse>().having(
            (f) => f.message,
            'message',
            'not a page',
          ),
        ),
      );
    });

    test('a v1 list that is not an array is unexpected', () async {
      final dio = fakeDio({
        '$_v1/projects?page=1': json(_v2Page([_project(1)], totalPages: 1)),
      });

      await expectLater(
        _client(dio, hasV2: false).projects.list(),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('errors are normalized', () async {
      final dio = fakeDio({
        '$_v1/projects/99999999': errorFixture('v1_404_project_2.7.0'),
        '$_v1/projects/5': errorFixture('v1_403_project_2.7.0'),
        '$_v1/projects?page=1': errorFixture('v1_401_code11_missing_2.7.0'),
      });
      final projects = _client(dio, hasV2: false).projects;

      await expectLater(
        projects.read(99999999),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      await expectLater(projects.read(5), throwsA(isA<Forbidden>()));
      await expectLater(projects.list(), throwsA(isA<TokenRejected>()));
    });

    test('network failures are normalized', () async {
      await expectLater(
        _client(fakeDio({})).projects.listAll(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a cancelled request rethrows its DioException', () async {
      final dio = fakeDio({
        '$_v2/projects/7': failsWith(
          (request) => DioException.requestCancelled(
            requestOptions: request,
            reason: 'closed',
          ),
        ),
      });

      await expectLater(
        _client(dio).projects.read(7),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });
  });

  group('labels', () {
    test('list parses colours without the hash', () async {
      final dio = fakeDio({
        '$_v2/labels?q=urg&page=1': json(
          _v2Page([
            _label(1, 'urgent', hexColor: 'e8323c'),
            _label(2, 'home', hexColor: '#4CAF50'),
          ], totalPages: 1),
        ),
      });

      final page = await _client(dio).labels.list(search: 'urg');

      expect(page.items.map((l) => (l.id, l.title, l.hexColor)), [
        (1, 'urgent', 'e8323c'),
        (2, 'home', '4caf50'),
      ]);
      expect(page.items.first.createdBy, const User(id: 1, username: 'alice'));
      expect(page.items.first.created, DateTime.utc(2026, 10, 9, 8, 17, 58));
    });

    test('listAll walks the pages on v1', () async {
      final dio = fakeDio({
        '$_v1/labels?page=1': _v1List([_label(1, 'a')], totalPages: 2),
        '$_v1/labels?page=2': _v1List([_label(2, 'b')], totalPages: 2),
      });

      final labels = await _client(dio, hasV2: false).labels.listAll();

      expect(labels.map((l) => l.title), ['a', 'b']);
    });

    test('a label without title is unexpected', () async {
      final dio = fakeDio({
        '$_v2/labels?page=1': json(
          _v2Page([
            {'id': 1},
          ], totalPages: 1),
        ),
      });

      await expectLater(
        _client(dio).labels.list(),
        throwsA(isA<UnexpectedResponse>()),
      );
    });
  });

  group('tasks', () {
    const overview = TaskQuery(
      filter: "done = false && due_date < 'now/d+1d'",
      sort: TaskQuery.dueDateSort,
      expand: {TaskExpand.commentCount, TaskExpand.isUnread},
    );
    const overviewQuery =
        'filter=done+%3D+false+%26%26+due_date+%3C+%27now%2Fd%2B1d%27'
        '&sort_by=due_date&sort_by=id&order_by=asc&order_by=desc'
        '&expand=comment_count&expand=is_unread&page=1';

    test('encodes the query once with repeated list parameters', () async {
      final dio = fakeDio({
        '$_v2/tasks?$overviewQuery': json(_v2Page([_task(1)], totalPages: 1)),
      });

      final page = await _client(dio).tasks.list(overview);

      expect(page.items.single.id, 1);
      final uri = adapterOf(dio).requests.single.uri;
      expect(uri.query, overviewQuery);
      expect(uri.queryParametersAll, {
        'filter': ["done = false && due_date < 'now/d+1d'"],
        'sort_by': ['due_date', 'id'],
        'order_by': ['asc', 'desc'],
        'expand': ['comment_count', 'is_unread'],
        'page': ['1'],
      });
    });

    test('v1 sends the search as s', () async {
      final dio = fakeDio({
        '$_v1/tasks?s=milk&page=1': _v1List([], totalPages: 0),
      });

      await _client(
        dio,
        hasV2: false,
      ).tasks.list(const TaskQuery(search: 'milk'));

      expect(adapterOf(dio).requestedUrls, ['$_v1/tasks?s=milk&page=1']);
    });

    test('timezone, include-nulls and paging', () async {
      const url =
          '$_v2/tasks?filter=due_date+%3C+now%2B7d&filter_timezone=Europe%2FBerlin'
          '&filter_include_nulls=true&page=3&per_page=25';
      final dio = fakeDio({
        url: json(_v2Page([], page: 3, perPage: 25, totalPages: 3)),
      });

      final page = await _client(dio).tasks.list(
        const TaskQuery(
          filter: 'due_date < now+7d',
          filterTimezone: 'Europe/Berlin',
          includeNulls: true,
          page: 3,
          perPage: 25,
        ),
      );

      expect(adapterOf(dio).requestedUrls, [url]);
      expect(page.page, 3);
      expect(page.perPage, 25);
    });

    test(
      'listInProject drops the position sort, listInView keeps it',
      () async {
        const inProject =
            '$_v2/projects/5/tasks?sort_by=id&order_by=desc&page=1';
        const inView =
            '$_v2/projects/5/views/9/tasks?sort_by=position&sort_by=id'
            '&order_by=asc&order_by=desc&page=1';
        final dio = fakeDio({
          inProject: json(_v2Page([], totalPages: 0)),
          inView: json(_v2Page([], totalPages: 0)),
        });
        const query = TaskQuery(sort: TaskQuery.defaultSort);

        await _client(dio).tasks.listInProject(5, query);
        await _client(dio).tasks.listInView(5, 9, query);

        expect(adapterOf(dio).requestedUrls, [inProject, inView]);
      },
    );

    test('read sends the expands', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(_task(42)),
        '$_v2/tasks/42?expand=comment_count&expand=is_unread': json(
          _task(42, overrides: {'comment_count': 3, 'is_unread': true}),
        ),
      });
      final tasks = _client(dio).tasks;

      final plain = await tasks.read(42);
      final expanded = await tasks.read(
        42,
        expand: {TaskExpand.commentCount, TaskExpand.isUnread},
      );

      expect(plain.commentCount, isNull);
      expect(plain.isUnread, isNull);
      expect(expanded.commentCount, 3);
      expect(expanded.isUnread, isTrue);
    });

    test('zero dates are null and null collections are empty', () async {
      final dio = fakeDio({'$_v2/tasks/1': json(_task(1))});

      final task = await _client(dio).tasks.read(1);

      expect(task.dueDate, isNull);
      expect(task.startDate, isNull);
      expect(task.endDate, isNull);
      expect(task.doneAt, isNull);
      expect(task.labels, isEmpty);
      expect(task.assignees, isEmpty);
      expect(task.reminders, isEmpty);
      expect(task.relatedTasks, isEmpty);
      expect(task.repeatAfter, Duration.zero);
      expect(task.repeats, isFalse);
      expect(task.priority, TaskPriority.unset);
      expect(task.identifier, 'P7-1');
      expect(task.displayIdentifier, 'P7-1');
      expect(task.createdBy, const User(id: 1, username: 'alice'));
      expect(task.created, DateTime.utc(2026, 10, 9, 8, 17, 58));
    });

    test('dates keep the server offset as UTC', () async {
      final dio = fakeDio({
        '$_v2/tasks/1': json(
          _task(
            1,
            overrides: {
              'done': true,
              'done_at': '2026-10-08T16:30:00+02:00',
              'due_date': '2026-10-09T00:00:00+02:00',
              'start_date': '2026-10-01T08:00:00Z',
              'end_date': '2026-10-02T08:00:00-05:00',
            },
          ),
        ),
      });

      final task = await _client(dio).tasks.read(1);

      expect(task.done, isTrue);
      expect(task.doneAt, DateTime.utc(2026, 10, 8, 14, 30));
      expect(task.dueDate, DateTime.utc(2026, 10, 8, 22));
      expect(task.startDate, DateTime.utc(2026, 10, 1, 8));
      expect(task.endDate, DateTime.utc(2026, 10, 2, 13));
      expect(task.dueDate!.isUtc, isTrue);
    });

    test('scalar fields map to the domain types', () async {
      final dio = fakeDio({
        '$_v2/tasks/1': json(
          _task(
            1,
            overrides: {
              'priority': 5,
              'percent_done': 0.5,
              'hex_color': '#FF00AA',
              'repeat_after': 86400,
              'repeat_mode': 1,
              'identifier': '-1',
              'index': 1,
              'is_favorite': true,
              'position': 65536,
              'bucket_id': 12,
              'description': '<p>Hello</p>',
            },
          ),
        ),
      });

      final task = await _client(dio).tasks.read(1);

      expect(task.priority, TaskPriority.doNow);
      expect(task.percentDone, 0.5);
      expect(task.hexColor, 'ff00aa');
      expect(task.repeatAfter, const Duration(days: 1));
      expect(task.repeatMode, RepeatMode.monthly);
      expect(task.repeats, isTrue);
      expect(task.displayIdentifier, '#1');
      expect(task.isFavorite, isTrue);
      expect(task.position, 65536.0);
      expect(task.bucketId, 12);
      expect(task.description, '<p>Hello</p>');
    });

    test('labels, assignees and reminders', () async {
      final dio = fakeDio({
        '$_v2/tasks/1': json(
          _task(
            1,
            overrides: {
              'due_date': '2026-10-10T10:00:00Z',
              'labels': [
                _label(1, 'urgent', hexColor: 'e8323c'),
                _label(2, 'home'),
              ],
              'assignees': [
                _user(2, 'bob'),
                {'name': 'no id'},
              ],
              'reminders': [
                {
                  'reminder': '2026-10-10T09:00:00Z',
                  'relative_period': -3600,
                  'relative_to': 'due_date',
                },
                {
                  'reminder': '2026-10-09T18:00:00Z',
                  'relative_period': 0,
                  'relative_to': '',
                },
                {
                  'reminder': _zeroDate,
                  'relative_period': 600,
                  'relative_to': 'start_date',
                },
              ],
            },
          ),
        ),
      });

      final task = await _client(dio).tasks.read(1);

      expect(task.labels.map((l) => l.title), ['urgent', 'home']);
      expect(task.labels.first.hexColor, 'e8323c');
      expect(task.assignees, [const User(id: 2, username: 'bob')]);
      expect(task.reminders, [
        TaskReminder(
          reminder: DateTime.utc(2026, 10, 10, 9),
          relativePeriod: const Duration(hours: -1),
          relativeTo: ReminderRelativeTo.dueDate,
        ),
        TaskReminder(reminder: DateTime.utc(2026, 10, 9, 18)),
        const TaskReminder(
          relativePeriod: Duration(minutes: 10),
          relativeTo: ReminderRelativeTo.startDate,
        ),
      ]);
      expect(task.reminders.map((r) => r.isRelative), [true, false, true]);
    });

    test('related tasks are grouped by kind; nested ones carry none', () async {
      final dio = fakeDio({
        '$_v2/tasks/1': json(
          _task(
            1,
            overrides: {
              'related_tasks': {
                'subtask': [
                  _task(2, overrides: {'related_tasks': null}),
                  _task(3, overrides: {'related_tasks': null}),
                ],
                'parenttask': [
                  _task(4, overrides: {'related_tasks': null}),
                ],
                'frobnicates': [
                  _task(5, overrides: {'related_tasks': null}),
                ],
              },
            },
          ),
        ),
      });

      final task = await _client(dio).tasks.read(1);

      expect(task.relatedTasks.keys, [
        TaskRelationKind.subtask,
        TaskRelationKind.parentTask,
      ]);
      expect(task.subtasks.map((t) => t.id), [2, 3]);
      expect(task.parentTasks.map((t) => t.id), [4]);
      expect(task.subtasks.first.relatedTasks, isEmpty);
      expect(task.subtasks.first.subtasks, isEmpty);
    });

    test('unknown keys are ignored everywhere', () async {
      final dio = fakeDio({
        '$_v2/tasks/1': json(
          _task(
            1,
            overrides: {
              r'$schema': 'http://x/schemas/Task.json',
              'max_permission': 2,
              'subscription': {'id': 1, 'entity': 'task'},
              'time_entries_count': 4,
              'frobnicate': true,
              'labels': [
                {..._label(1, 'a'), 'frobnicate': 1},
              ],
              'created_by': {..._user(1, 'alice'), 'frobnicate': 1},
              'reminders': [
                {
                  'reminder': _zeroDate,
                  'relative_period': 0,
                  'relative_to': '',
                  'frobnicate': 1,
                },
              ],
            },
          ),
        ),
        '$_v2/projects/7': json({
          ..._project(
            7,
            views: [
              {..._view(21, 'list'), 'frobnicate': 1},
            ],
          ),
          r'$schema': 'x',
          'frobnicate': 1,
        }),
      });
      final client = _client(dio);

      final task = await client.tasks.read(1);
      final project = await client.projects.read(7);

      expect(task.id, 1);
      expect(task.labels.single.title, 'a');
      expect(task.reminders, hasLength(1));
      expect(project.views.single.kind, ProjectViewKind.list);
    });

    for (final (missing, message) in [
      ('id', 'task without id'),
      ('title', 'task without title'),
      ('project_id', 'task without project_id'),
    ]) {
      test('a task without $missing is unexpected', () async {
        final dio = fakeDio({'$_v2/tasks/1': json(_task(1)..remove(missing))});

        await expectLater(
          _client(dio).tasks.read(1),
          throwsA(
            isA<UnexpectedResponse>().having(
              (f) => f.message,
              'message',
              message,
            ),
          ),
        );
      });
    }

    test('v1 and v2 produce equal tasks from the same entity JSON', () async {
      final body = _task(
        1,
        overrides: {
          'due_date': '2026-10-10T10:00:00Z',
          'labels': [_label(1, 'a')],
          'priority': 3,
        },
      );
      final dio = fakeDio({
        '$_v1/tasks?page=1': _v1List([body], totalPages: 1),
        '$_v2/tasks?page=1': json(_v2Page([body], totalPages: 1)),
      });

      final v1 = await _client(dio, hasV2: false).tasks.list(const TaskQuery());
      final v2 = await _client(dio).tasks.list(const TaskQuery());

      expect(v1.items, v2.items);
      expect(v1.items.single.labels, v2.items.single.labels);
      expect(v1.total, isNull);
      expect(v2.total, 1);
    });

    test('errors are normalized', () async {
      final dio = fakeDio({
        '$_v2/tasks?page=1': errorFixture('v2_401_code11_missing_2.7.0'),
        '$_v2/tasks/1': errorFixture('v2_404_route_2.7.0'),
      });
      final tasks = _client(dio).tasks;

      await expectLater(
        tasks.list(const TaskQuery()),
        throwsA(isA<TokenRejected>()),
      );
      await expectLater(
        tasks.read(1),
        throwsA(
          isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', isTrue),
        ),
      );
    });
  });

  group('users', () {
    final alice = _user(1, 'alice');
    final bob = {..._user(2, 'bob'), 'name': 'Bob Builder'};

    test('v2 lists every user with access without a query', () async {
      final dio = fakeDio({
        '$_v2/projects/7/users/search': json(
          _v2Page([alice, bob], totalPages: 1),
        ),
      });

      final users = await _client(dio).users.searchProjectUsers(7);

      final request = adapterOf(dio).requests.single;
      expect(request.method, 'GET');
      expect(request.uri.queryParameters, isEmpty);
      expect(request.headers['Accept'], 'application/json');
      expect(users, const [
        User(id: 1, username: 'alice'),
        User(id: 2, username: 'bob', name: 'Bob Builder'),
      ]);
    });

    test('v2 searches with q', () async {
      final dio = fakeDio({
        '$_v2/projects/7/users/search?q=bo': json(
          _v2Page([bob], totalPages: 1),
        ),
      });

      final users = await _client(dio).users.searchProjectUsers(7, query: 'bo');

      expect(users.single.displayName, 'Bob Builder');
    });

    test('v1 lists every user with access without a query', () async {
      final dio = fakeDio({
        '$_v1/projects/7/projectusers': _v1List([alice, bob]),
      });

      final users = await _client(
        dio,
        hasV2: false,
      ).users.searchProjectUsers(7);

      expect(adapterOf(dio).requests.single.uri.queryParameters, isEmpty);
      expect(users.map((u) => u.username), ['alice', 'bob']);
    });

    test('v1 searches with s', () async {
      final dio = fakeDio({
        '$_v1/projects/7/projectusers?s=bo': _v1List([bob]),
      });

      final users = await _client(
        dio,
        hasV2: false,
      ).users.searchProjectUsers(7, query: 'bo');

      expect(users.map((u) => u.id), [2]);
    });

    test('a query is trimmed, a blank one is left out', () async {
      final dio = fakeDio({
        '$_v2/projects/7/users/search?q=bo': json(
          _v2Page([bob], totalPages: 1),
        ),
        '$_v2/projects/7/users/search': json(
          _v2Page([alice, bob], totalPages: 1),
        ),
      });
      final users = _client(dio).users;

      expect(await users.searchProjectUsers(7, query: '  bo '), hasLength(1));
      expect(await users.searchProjectUsers(7, query: '   '), hasLength(2));
    });

    // v1 answers a search without matches with `null`.
    test('no match is an empty list on both versions', () async {
      final dio = fakeDio({
        '$_v2/projects/7/users/search?q=zz': json({
          'items': <Object?>[],
          'total': 0,
          'page': 1,
          'per_page': 0,
          'total_pages': 0,
        }),
        '$_v1/projects/7/projectusers?s=zz': json(null),
      });

      expect(
        await _client(dio).users.searchProjectUsers(7, query: 'zz'),
        isEmpty,
      );
      expect(
        await _client(
          dio,
          hasV2: false,
        ).users.searchProjectUsers(7, query: 'zz'),
        isEmpty,
      );
    });

    test('entries that are not users are skipped', () async {
      final dio = fakeDio({
        '$_v1/projects/7/projectusers': _v1List([
          alice,
          {'id': 3},
          'carol',
        ]),
      });

      final users = await _client(
        dio,
        hasV2: false,
      ).users.searchProjectUsers(7);

      expect(users.map((u) => u.id), [1]);
    });

    test('a body that is not a user list is unexpected', () async {
      final dio = fakeDio({
        '$_v2/projects/7/users/search': json([alice]),
        '$_v1/projects/7/projectusers': json({'items': <Object?>[]}),
      });

      await expectLater(
        _client(dio).users.searchProjectUsers(7),
        throwsA(isA<UnexpectedResponse>()),
      );
      await expectLater(
        _client(dio, hasV2: false).users.searchProjectUsers(7),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('errors are normalized', () async {
      final dio = fakeDio({
        '$_v2/projects/7/users/search': errorFixture('v2_403_project_2.7.0'),
        '$_v1/projects/7/projectusers': errorFixture('v1_404_project_2.7.0'),
      });

      await expectLater(
        _client(dio).users.searchProjectUsers(7),
        throwsA(isA<Forbidden>()),
      );
      await expectLater(
        _client(dio, hasV2: false).users.searchProjectUsers(7),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
    });
  });
}
