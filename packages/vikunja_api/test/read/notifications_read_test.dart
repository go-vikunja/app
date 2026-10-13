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

NotificationsPort _notifications(
  Dio dio, {
  bool hasV2 = true,
  int maxItemsPerPage = 50,
}) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2, maxItemsPerPage: maxItemsPerPage),
).notifications;

FakeRoute _v1List(List<Object?> items, {int? totalPages}) =>
    (_) => ResponseBody.fromString(
      jsonEncode(items),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (totalPages != null) 'x-pagination-total-pages': ['$totalPages'],
        'x-pagination-result-count': ['${items.length}'],
      },
    );

Map<String, Object?> _v2Page(
  List<Object?> items, {
  int page = 1,
  int perPage = 50,
  int totalPages = 1,
  int? total,
}) => {
  r'$schema': '$_v2/schemas/PaginatedDatabaseNotification.json',
  'items': items,
  'total': total ?? items.length,
  'page': page,
  'per_page': perPage,
  'total_pages': totalPages,
};

Map<String, Object?> _notification(
  int id, {
  String name = 'task.assigned',
  Object? payload = const {
    'doer': {'id': 2, 'username': 'bob'},
    'task': {'id': 42, 'title': 'Water the plants', 'project_id': 7},
    'project': {'id': 7, 'title': 'Garden'},
  },
  Object? readAt = _zeroDate,
  Object? created = '2026-10-13T11:09:56Z',
}) => {
  'id': id,
  'notification': payload,
  'name': name,
  'read_at': readAt,
  'created': created,
};

void main() {
  // Captured by tool/capture_notification_fixtures.dart: the reader was
  // assigned, mentioned in a comment and in a description, subscribed to a
  // project in which a task and a child project were created, and added to
  // a team.
  group('captured 2.7.0 pages', () {
    for (final version in ApiVersion.values) {
      final base = '$testServerRoot/api/${version.pathSegment}';

      Future<Page<ServerNotification>> read() => _notifications(
        fakeDio({
          '$base/notifications?page=1': capturedFixture(
            'read/${version.pathSegment}_notifications_page_2.7.0',
          ),
        }),
        hasV2: version == ApiVersion.v2,
      ).list();

      test(
        '${version.pathSegment}: every kind, newest first, unread',
        () async {
          final page = await read();

          expect(page.items.map((n) => (n.id, n.name)), [
            (373, 'team.member.added'),
            (372, 'project.created'),
            (371, 'task.created'),
            (370, 'task.mentioned'),
            (369, 'task.comment'),
            (368, 'task.assigned'),
            (367, 'task.created'),
          ]);
          expect(page.items.map((n) => n.readAt), everyElement(isNull));
          expect(page.items.map((n) => n.isRead), everyElement(isFalse));
          expect(
            page.items.first.created,
            DateTime.utc(2026, 10, 13, 11, 9, 58),
          );
          expect(page.page, 1);
          expect(page.perPage, 50);
          expect(page.totalPages, 1);
          expect(page.total, version == ApiVersion.v2 ? 7 : isNull);
        },
      );

      test('${version.pathSegment}: payloads as sent', () async {
        final byId = {for (final n in (await read()).items) n.id: n};

        final assigned = byId[368]!;
        expect(assigned.taskId, 11204);
        expect(assigned.projectId, 1071);
        expect(
          assigned.payload['doer'],
          containsPair('username', 'fixturedoer'),
        );
        expect(
          assigned.payload['assignee'],
          containsPair('username', 'fixturereader'),
        );
        expect(
          assigned.payload['task'],
          allOf(
            containsPair('title', 'Water the plants'),
            containsPair('identifier', '#1'),
            containsPair('index', 1),
            containsPair('project_id', 1071),
          ),
        );

        final comment = byId[369]!;
        expect(comment.taskId, 11204);
        expect(comment.payload['mentioned'], isTrue);
        expect(
          (comment.payload['comment']! as Map<String, Object?>)['comment'],
          startsWith('<p>Please check the <strong>pots</strong>'),
        );

        final mentioned = byId[370]!;
        expect(mentioned.taskId, 11205);
        expect(mentioned.payload['is_new'], isTrue);

        final created = byId[371]!;
        expect(created.taskId, 11206);
        expect(created.projectId, 1071);

        final project = byId[372]!;
        expect(project.taskId, isNull);
        expect(project.projectId, 1072);
        expect(project.payload['project'], containsPair('title', 'Balcony'));

        final team = byId[373]!;
        expect(team.taskId, isNull);
        expect(team.projectId, isNull);
        expect(team.payload['team'], containsPair('name', 'Gardeners'));
        expect(team.payload['member'], containsPair('id', 374));
      });
    }

    test('v1 and v2 produce the same notifications', () async {
      Future<List<ServerNotification>> read(ApiVersion version) async {
        final base = '$testServerRoot/api/${version.pathSegment}';
        final page = await _notifications(
          fakeDio({
            '$base/notifications?page=1': capturedFixture(
              'read/${version.pathSegment}_notifications_page_2.7.0',
            ),
          }),
          hasV2: version == ApiVersion.v2,
        ).list();
        return page.items;
      }

      final v1 = await read(ApiVersion.v1);
      final v2 = await read(ApiVersion.v2);

      expect(v1, v2);
      expect(v1.map((n) => n.payload), v2.map((n) => n.payload));
    });
  });

  group('paging', () {
    test('v2 sends page and per_page and reads the envelope', () async {
      final dio = fakeDio({
        '$_v2/notifications?page=2&per_page=10': json(
          _v2Page(
            [_notification(5)],
            page: 2,
            perPage: 10,
            totalPages: 3,
            total: 21,
          ),
        ),
      });

      final page = await _notifications(dio).list(page: 2, perPage: 10);

      final request = adapterOf(dio).requests.single;
      expect(request.method, 'GET');
      expect(request.headers['Accept'], 'application/json');
      expect(page.items.single.id, 5);
      expect(page.page, 2);
      expect(page.perPage, 10);
      expect(page.totalPages, 3);
      expect(page.total, 21);
      expect(page.hasMore, isTrue);
    });

    test('v1 reads the pagination headers and caps per_page', () async {
      final dio = fakeDio({
        '$_v1/notifications?page=2&per_page=100': _v1List([
          _notification(5),
        ], totalPages: 2),
      });

      final page = await _notifications(
        dio,
        hasV2: false,
        maxItemsPerPage: 30,
      ).list(page: 2, perPage: 100);

      expect(page.items.single.id, 5);
      expect(page.page, 2);
      expect(page.perPage, 30);
      expect(page.totalPages, 2);
      expect(page.total, isNull);
      expect(page.hasMore, isFalse);
    });

    test('v1 without the total-pages header is a single page', () async {
      final dio = fakeDio({
        '$_v1/notifications?page=1': _v1List([_notification(5)]),
      });

      final page = await _notifications(dio, hasV2: false).list();

      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('an empty list on both versions', () async {
      final dio = fakeDio({
        '$_v2/notifications?page=1': json(
          _v2Page([], perPage: 0, totalPages: 0),
        ),
        '$_v1/notifications?page=1': _v1List([], totalPages: 0),
      });

      expect((await _notifications(dio).list()).items, isEmpty);
      expect((await _notifications(dio, hasV2: false).list()).items, isEmpty);
    });
  });

  group('parsing', () {
    Future<List<ServerNotification>> parse(List<Object?> items) async {
      final dio = fakeDio({'$_v2/notifications?page=1': json(_v2Page(items))});
      return (await _notifications(dio).list()).items;
    }

    test('the zero date is unread, a read date is UTC', () async {
      final items = await parse([
        _notification(1),
        _notification(2, readAt: '2026-10-13T13:09:59.005984918+02:00'),
        _notification(3, readAt: null),
      ]);

      expect(items[0].readAt, isNull);
      expect(items[0].isRead, isFalse);
      expect(items[1].readAt, DateTime.utc(2026, 10, 13, 11, 9, 59, 5, 984));
      expect(items[1].readAt!.isUtc, isTrue);
      expect(items[1].isRead, isTrue);
      expect(items[2].readAt, isNull);
    });

    test('created keeps the server offset as UTC', () async {
      final items = await parse([
        _notification(1, created: '2026-10-13T13:09:56+02:00'),
      ]);

      expect(items.single.created, DateTime.utc(2026, 10, 13, 11, 9, 56));
    });

    test('a payload that is not an object is empty', () async {
      final items = await parse([
        _notification(1, payload: null),
        _notification(2, payload: 'task.assigned'),
        _notification(3, payload: [1, 2]),
      ]);

      expect(items.map((n) => n.payload), everyElement(isEmpty));
      expect(items.map((n) => n.taskId), everyElement(isNull));
      expect(items.map((n) => n.projectId), everyElement(isNull));
    });

    test('an unknown kind is kept with its payload', () async {
      final items = await parse([
        _notification(
          1,
          name: 'migration.done',
          payload: {'migrator_name': 'todoist'},
        ),
      ]);

      expect(items.single.name, 'migration.done');
      expect(items.single.payload, {'migrator_name': 'todoist'});
    });

    test('the payload cannot be changed', () async {
      final items = await parse([_notification(1)]);

      expect(() => items.single.payload['doer'] = null, throwsUnsupportedError);
    });

    for (final (missing, item) in [
      ('id', {..._notification(1)}..remove('id')),
      ('name', {..._notification(1)}..remove('name')),
      ('created', {..._notification(1)}..remove('created')),
      ('a created date', _notification(1, created: _zeroDate)),
    ]) {
      test('an item without $missing fails the page', () async {
        await expectLater(
          parse([_notification(2), item]),
          throwsA(
            isA<UnexpectedResponse>().having(
              (f) => f.statusCode,
              'statusCode',
              200,
            ),
          ),
        );
      });
    }
  });

  group('errors', () {
    test('a v2 list without the envelope is unexpected', () async {
      final dio = fakeDio({
        '$_v2/notifications?page=1': json([_notification(1)]),
      });

      await expectLater(
        _notifications(dio).list(),
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
        '$_v1/notifications?page=1': json(_v2Page([_notification(1)])),
      });

      await expectLater(
        _notifications(dio, hasV2: false).list(),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('are normalized on both versions', () async {
      final dio = fakeDio({
        '$_v2/notifications?page=1': errorFixture(
          'v2_401_code11_missing_2.7.0',
        ),
        '$_v1/notifications?page=1': errorFixture(
          'v1_401_code11_missing_2.7.0',
        ),
      });

      await expectLater(
        _notifications(dio).list(),
        throwsA(isA<TokenRejected>()),
      );
      await expectLater(
        _notifications(dio, hasV2: false).list(),
        throwsA(isA<TokenRejected>()),
      );
    });

    test('network failures are normalized', () async {
      await expectLater(
        _notifications(fakeDio({})).list(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a cancelled request rethrows its DioException', () async {
      final dio = fakeDio({
        '$_v2/notifications?page=1': failsWith(
          (request) => DioException.requestCancelled(
            requestOptions: request,
            reason: 'closed',
          ),
        ),
      });

      await expectLater(
        _notifications(dio).list(),
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
}
