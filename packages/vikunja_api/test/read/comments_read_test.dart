import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

CommentsPort _comments(Dio dio, {bool hasV2 = true}) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).comments;

Map<String, Object?> _commentJson(
  int id,
  String created, {
  String? updated,
  Object? reactions,
}) => {
  'id': id,
  'comment': '<p>Comment $id</p>',
  'author': userJson(3, 'alice'),
  'reactions': reactions,
  'created': created,
  'updated': updated ?? created,
};

void main() {
  group('the captured 2.7.0 pages', () {
    for (final version in ApiVersion.values) {
      test(version.pathSegment, () async {
        final base = '$testServerRoot/api/${version.pathSegment}';
        final dio = fakeDio({
          '$base/tasks/17/comments?page=1&per_page=3&order_by=asc':
              capturedFixture(
                'read/${version.pathSegment}_comments_page_2.7.0',
              ),
        });

        final page = await _comments(
          dio,
          hasV2: version == ApiVersion.v2,
        ).list(17, perPage: 3);

        expect(page.items.map((c) => c.id), [71, 72, 73]);
        expect(page.page, 1);
        expect(page.perPage, 3);
        expect(page.totalPages, 3);
        expect(page.hasMore, isTrue);
        expect(page.total, version == ApiVersion.v2 ? 7 : isNull);
        final first = page.items.first;
        expect(first.html, '<p>A comment 0</p>');
        expect(first.author.username, 'p10a941d3a');
        expect(first.created, DateTime.utc(2026, 10, 19, 6, 22, 57));
        expect(first.isEdited, isFalse);
        expect(first.reactions.keys, ['ok']);
        expect(first.reactions['ok']!.single.username, 'p10bb8325b');
        expect(page.items[1].reactions, isEmpty);
      });
    }
  });

  for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
    group(hasV2 ? 'v2' : 'v1', () {
      List<Object?> items() => [
        _commentJson(132, '2026-10-19T06:30:04Z'),
        _commentJson(130, '2026-10-19T06:30:03Z'),
        _commentJson(
          131,
          '2026-10-19T06:30:04Z',
          updated: '2026-10-19T07:00:00Z',
        ),
        _commentJson(129, '2026-10-19T06:30:03Z'),
      ];

      test('a page sorted by created, then id, either way', () async {
        final route = hasV2
            ? json({
                'items': items(),
                'total': 8,
                'page': 2,
                'per_page': 4,
                'total_pages': 2,
              })
            : _jsonWithHeaders(items(), {'x-pagination-total-pages': '2'});
        final dio = fakeDio({
          '$base/tasks/5/comments?page=2&per_page=4&order_by=asc': route,
          '$base/tasks/5/comments?page=2&per_page=4&order_by=desc': route,
        });
        final comments = _comments(dio, hasV2: hasV2);

        final oldest = await comments.list(5, page: 2, perPage: 4);
        final newest = await comments.list(
          5,
          page: 2,
          perPage: 4,
          newestFirst: true,
        );

        expect(oldest.items.map((c) => c.id), [129, 130, 131, 132]);
        expect(newest.items.map((c) => c.id), [132, 131, 130, 129]);
        expect(oldest.page, 2);
        expect(oldest.totalPages, 2);
        expect(oldest.items[2].isEdited, isTrue);
      });

      test('the server default page size when none is asked for', () async {
        final dio = fakeDio({
          '$base/tasks/5/comments?page=1&order_by=asc': hasV2
              ? json({
                  'items': <Object?>[],
                  'total': 0,
                  'page': 1,
                  'per_page': 50,
                  'total_pages': 0,
                })
              : _jsonWithHeaders(const [], {'x-pagination-total-pages': '0'}),
        });

        final page = await _comments(dio, hasV2: hasV2).list(5);

        expect(page.items, isEmpty);
        expect(page.perPage, 50);
        expect(page.hasMore, isFalse);
      });

      test('an author the client cannot read', () async {
        final dio = fakeDio({
          '$base/tasks/5/comments?page=1&order_by=asc': hasV2
              ? json({
                  'items': [
                    {
                      ..._commentJson(1, '2026-10-19T06:30:03Z'),
                      'author': null,
                    },
                  ],
                  'total': 1,
                  'page': 1,
                  'per_page': 50,
                  'total_pages': 1,
                })
              : _jsonWithHeaders(
                  [
                    {
                      ..._commentJson(1, '2026-10-19T06:30:03Z'),
                      'author': null,
                    },
                  ],
                  {'x-pagination-total-pages': '1'},
                ),
        });

        final page = await _comments(dio, hasV2: hasV2).list(5);

        expect(page.items.single.author, const User(id: 0, username: ''));
      });

      test('comments disabled or the task gone: NotFound', () async {
        final dio = fakeDio({
          '$base/tasks/5/comments?page=1&order_by=asc': json({
            'message': 'Not Found',
          }, status: 404),
          '$base/tasks/6/comments?page=1&order_by=asc': json({
            'code': 1,
            'message': "You're not allowed to do this.",
          }, status: 403),
        });
        final comments = _comments(dio, hasV2: hasV2);

        await expectLater(comments.list(5), throwsA(isA<NotFound>()));
        await expectLater(comments.list(6), throwsA(isA<Forbidden>()));
      });

      test('a comment without an id is unexpected', () async {
        final dio = fakeDio({
          '$base/tasks/5/comments?page=1&order_by=asc': hasV2
              ? json({
                  'items': [
                    {'comment': 'x'},
                  ],
                  'total': 1,
                  'page': 1,
                  'per_page': 50,
                  'total_pages': 1,
                })
              : _jsonWithHeaders([
                  {'comment': 'x'},
                ], const {}),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).list(5),
          throwsA(isA<UnexpectedResponse>()),
        );
      });
    });
  }
}

FakeRoute _jsonWithHeaders(Object? body, Map<String, String> headers) =>
    (request) async {
      final response = await json(body)(request);
      return ResponseBody(
        response.stream,
        200,
        headers: {
          ...response.headers,
          for (final MapEntry(:key, :value) in headers.entries) key: [value],
        },
      );
    };
