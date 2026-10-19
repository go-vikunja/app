import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

// Captured by tool/capture_kanban_fixtures.dart: project 664 with the
// Kanban view 3706 (To-Do 2778 with three tasks, Doing 2779 limited to two
// with one, Done 2780 and Later 2781 empty), read two per bucket, and the
// filter-mode view 3707 (Open, Closed).
const _project = 664;
const _kanban = 3706;
const _byState = 3707;
const _toDo = 2778;
const _doing = 2779;
const _done = 2780;
const _later = 2781;

String _base(ApiVersion version) =>
    '$testServerRoot/api/${version.pathSegment}';

String _boardUrl(ApiVersion version, int viewId, {String query = ''}) =>
    switch (version) {
      ApiVersion.v2 =>
        '${_base(version)}/projects/$_project/views/$viewId/buckets/tasks'
            '$query',
      ApiVersion.v1 =>
        '${_base(version)}/projects/$_project/views/$viewId/tasks$query',
    };

BucketsPort _buckets(Dio dio, ApiVersion version, {int maxItemsPerPage = 50}) =>
    createReadClient(
      dio: dio,
      connection: testConnection(
        hasV2: version == ApiVersion.v2,
        maxItemsPerPage: maxItemsPerPage,
      ),
    ).buckets;

Future<List<BoardBucket>> _capturedBoard(ApiVersion version) {
  final dio = fakeDio({
    _boardUrl(version, _kanban, query: '?per_page=2'): capturedFixture(
      'read/${version.pathSegment}_board_2.7.0',
    ),
  });
  return _buckets(dio, version).board(_project, _kanban, perPage: 2);
}

FakeRoute _v1Bare(List<Object?> items, {int totalPages = 1}) =>
    (_) => ResponseBody.fromString(
      jsonEncode(items),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        'x-pagination-total-pages': ['$totalPages'],
      },
    );

void main() {
  for (final version in ApiVersion.values) {
    group('board over ${version.name}', () {
      test('reads the buckets in order with their counts and limits', () async {
        final board = await _capturedBoard(version);

        expect(
          [for (final column in board) column.bucket],
          const [
            Bucket(
              id: _toDo,
              viewId: _kanban,
              title: 'To-Do',
              position: 100,
              count: 3,
            ),
            Bucket(
              id: _doing,
              viewId: _kanban,
              title: 'Doing',
              position: 200,
              limit: 2,
              count: 1,
            ),
            Bucket(id: _done, viewId: _kanban, title: 'Done', position: 300),
            Bucket(id: _later, viewId: _kanban, title: 'Later', position: 400),
          ],
        );
      });

      test('reads the first page of every bucket in server order, each task '
          'with its position and its bucket', () async {
        final board = await _capturedBoard(version);

        expect(
          [
            for (final column in board)
              [
                for (final task in column.tasks)
                  (task.id, task.position, task.bucketId),
              ],
          ],
          [
            [(4411, 16384.0, _toDo), (4410, 32768.0, _toDo)],
            [(4412, 8192.0, _doing)],
            <(int, double, int)>[],
            <(int, double, int)>[],
          ],
        );
      });

      test('reads full tasks, with null collections as empty ones', () async {
        final board = await _capturedBoard(version);
        final milk = board.first.tasks[1];
        final bank = board.first.tasks[0];

        expect(milk.title, 'Buy milk');
        expect(milk.projectId, _project);
        expect([for (final label in milk.labels) label.title], ['home']);
        expect(milk.description, '<p>Oat, two litres</p>');
        expect(milk.priority, TaskPriority.high);
        expect(bank.labels, isEmpty);
        expect(bank.assignees, isEmpty);
        expect(bank.reminders, isEmpty);
      });

      test('asks for the page size and the filter zone', () async {
        final dio = fakeDio({
          _boardUrl(
            version,
            _kanban,
            query: '?per_page=50&filter_timezone=Europe%2FBerlin',
          ): switch (version) {
            ApiVersion.v2 => json({'items': <Object?>[], 'total': 0}),
            ApiVersion.v1 => _v1Bare(const []),
          },
        });

        final board = await _buckets(
          dio,
          version,
        ).board(_project, _kanban, filterTimezone: 'Europe/Berlin');

        expect(board, isEmpty);
        expect(adapterOf(dio).requests.single.method, 'GET');
      });

      test('reads the synthetic buckets of a filter-mode view', () async {
        final dio = fakeDio({
          _boardUrl(version, _byState, query: '?per_page=2'): capturedFixture(
            'read/${version.pathSegment}_board_filter_mode_2.7.0',
          ),
        });

        final board = await _buckets(
          dio,
          version,
        ).board(_project, _byState, perPage: 2);

        expect(
          [for (final column in board) column.bucket],
          const [
            Bucket(
              id: 0,
              viewId: _byState,
              title: 'Open',
              position: 0,
              count: 4,
            ),
            Bucket(
              id: 1,
              viewId: _byState,
              title: 'Closed',
              position: 1,
              count: 1,
            ),
          ],
        );
        expect(
          [
            for (final column in board)
              [for (final task in column.tasks) (task.id, task.bucketId)],
          ],
          [
            [(4409, 0), (4410, 0)],
            [(4411, 1)],
          ],
        );
      });

      test('refuses a bucket without its view', () async {
        final bucket = {'id': 1, 'title': 'To-Do', 'count': 0, 'position': 1};
        final dio = fakeDio({
          _boardUrl(version, _kanban, query: '?per_page=50'): switch (version) {
            ApiVersion.v2 => json({
              'items': [bucket],
              'total': 1,
            }),
            ApiVersion.v1 => _v1Bare([bucket]),
          },
        });

        await expectLater(
          _buckets(dio, version).board(_project, _kanban),
          throwsA(isA<UnexpectedResponse>()),
        );
      });
    });
  }

  group('board answers that are not a board', () {
    test('v1 answers the tasks of a view that is not a kanban view', () async {
      final dio = fakeDio({
        _boardUrl(ApiVersion.v1, 9, query: '?per_page=50'): _v1Bare([
          taskJson(1),
          taskJson(2),
        ]),
      });

      await expectLater(
        _buckets(dio, ApiVersion.v1).board(_project, 9),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('v2 refuses a view that is not a kanban view with a 400', () async {
      final dio = fakeDio({
        _boardUrl(ApiVersion.v2, 3705, query: '?per_page=50'): capturedFixture(
          'read/v2_board_list_view_2.7.0',
        ),
      });

      await expectLater(
        _buckets(dio, ApiVersion.v2).board(_project, 3705),
        throwsA(
          isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 400),
        ),
      );
    });

    test('v2 without items is not a board', () async {
      final dio = fakeDio({
        _boardUrl(ApiVersion.v2, _kanban, query: '?per_page=50'): json([]),
      });

      await expectLater(
        _buckets(dio, ApiVersion.v2).board(_project, _kanban),
        throwsA(isA<UnexpectedResponse>()),
      );
    });
  });

  for (final version in ApiVersion.values) {
    group('bucketTasks over ${version.name}', () {
      final nextPage =
          '${_base(version)}/projects/$_project/views/$_kanban/tasks'
          '?filter=bucket_id+%3D+$_toDo&sort_by=position&order_by=asc'
          '&page=2&per_page=2';

      test('reads the next page of one bucket, sorted by position', () async {
        final dio = fakeDio({
          nextPage: capturedFixture(
            'read/${version.pathSegment}_bucket_tasks_page_2.7.0',
          ),
        });

        final page = await _buckets(
          dio,
          version,
        ).bucketTasks(_project, _kanban, _toDo, page: 2, perPage: 2);

        expect([for (final task in page.items) task.id], [4409]);
        expect(page.items.single.position, 65536);
        expect(page.page, 2);
        expect(page.totalPages, 2);
        expect(page.hasMore, isFalse);
        expect(adapterOf(dio).requestedUrls, [nextPage]);
      });

      test('takes the bucket from the request, not from the tasks', () async {
        final dio = fakeDio({
          nextPage: capturedFixture(
            'read/${version.pathSegment}_bucket_tasks_page_2.7.0',
          ),
        });

        final page = await _buckets(
          dio,
          version,
        ).bucketTasks(_project, _kanban, _toDo, page: 2, perPage: 2);

        expect(page.items.single.bucketId, _toDo);
      });

      test('sends the filter zone', () async {
        final url =
            '${_base(version)}/projects/$_project/views/$_kanban/tasks'
            '?filter=bucket_id+%3D+$_doing&filter_timezone=Europe%2FBerlin'
            '&sort_by=position&order_by=asc&page=3&per_page=50';
        final dio = fakeDio({
          url: switch (version) {
            ApiVersion.v2 => json({
              'items': <Object?>[],
              'total': 100,
              'page': 3,
              'per_page': 50,
              'total_pages': 2,
            }),
            ApiVersion.v1 => _v1Bare(const [], totalPages: 0),
          },
        });

        final page = await _buckets(dio, version).bucketTasks(
          _project,
          _kanban,
          _doing,
          page: 3,
          filterTimezone: 'Europe/Berlin',
        );

        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      });
    });
  }

  test('v1 and v2 read the same board', () async {
    final v1 = await _capturedBoard(ApiVersion.v1);
    final v2 = await _capturedBoard(ApiVersion.v2);

    expect(
      [for (final column in v1) column.bucket],
      [for (final column in v2) column.bucket],
    );
    expect(
      [for (final column in v1) column.tasks],
      [for (final column in v2) column.tasks],
    );
  });
}
