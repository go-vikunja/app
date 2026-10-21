import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _missing = 999999999;
const _mention =
    '<mention-user data-id="fixtureuser" data-label="Fixture User" '
    'data-mention-suggestion-char="@"></mention-user>';
const _author = User(id: 22, username: 'fixtureuser');

CommentsWritePort _comments(Dio dio, {bool hasV2 = true}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).comments;

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

// The answers were captured from 2.7.0 by
// tool/capture_comment_fixtures.dart.
void main() {
  group('create', () {
    for (final (hasV2, method, base, id) in [
      (true, 'POST', _v2, 57),
      (false, 'PUT', _v1, 56),
    ]) {
      final version = hasV2 ? 'v2' : 'v1';

      test(
        '$version ${method}s the body and returns the stored comment',
        () async {
          final dio = fakeDio({
            '$base/tasks/21/comments': capturedFixture(
              'write/${version}_comment_create_2.7.0',
            ),
          });
          final html = '<p>Hello $_mention, from $version</p>';

          final comment = await _comments(dio, hasV2: hasV2).create(21, html);

          expect(_calls(dio), ['$method $base/tasks/21/comments']);
          expect(adapterOf(dio).decodedBodies.single, {'comment': html});
          expect(comment.id, id);
          expect(comment.html, html);
          expect(comment.author, _author);
          expect(comment.created, isNotNull);
          expect(comment.reactions, isEmpty);
          // The answer's times are nanoseconds apart.
          expect(comment.updated!.isAfter(comment.created!), isTrue);
          expect(comment.isEdited, isFalse);
        },
      );

      test('$version: an empty body is refused with 2002', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments': capturedFixture(
            'write/${version}_comment_create_empty_2.7.0',
          ),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).create(21, ''),
          throwsA(
            isA<ValidationFailed>().having((f) => f.code, 'code', 2002).having(
              (f) => f.fieldErrors.keys,
              'fields',
              ['comment'],
            ),
          ),
        );
      });

      test('$version: a missing task and an archived project', () async {
        final dio = fakeDio({
          '$base/tasks/$_missing/comments': capturedFixture(
            'write/${version}_comment_create_unknown_task_2.7.0',
          ),
          '$base/tasks/22/comments': capturedFixture(
            'write/${version}_comment_create_archived_2.7.0',
          ),
        });
        final comments = _comments(dio, hasV2: hasV2);

        await expectLater(
          comments.create(_missing, '<p>x</p>'),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
        await expectLater(
          comments.create(22, '<p>x</p>'),
          throwsA(
            isA<DomainError>()
                .having((f) => f.statusCode, 'status', 412)
                .having((f) => f.code, 'code', 3008),
          ),
        );
      });

      test('$version: a read share is forbidden', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments': errorFixture(
            '${version}_403_project_2.7.0',
          ),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).create(21, '<p>x</p>'),
          throwsA(isA<Forbidden>()),
        );
      });
    }

    // v1 refuses a body above its limit by quoting all of it.
    test('the echo of a body that is too long is not kept', () async {
      final long = '<p>${'x' * 300}</p>';
      final dio = fakeDio({
        '$_v1/tasks/21/comments': json({
          'code': 2002,
          'message': 'Invalid Data',
          'invalid_fields': [
            'comment: $long does not validate as dbtext',
            'other: reason',
          ],
        }, status: 412),
      });

      await expectLater(
        _comments(dio, hasV2: false).create(21, long),
        throwsA(
          isA<ValidationFailed>().having((f) => f.code, 'code', 2002).having(
            (f) => f.fieldErrors,
            'fields',
            {
              'comment': <String>[],
              'other': ['reason'],
            },
          ),
        ),
      );
    });

    test('v2: a body above the request limit', () async {
      final dio = fakeDio({
        '$_v2/tasks/21/comments': json({
          'title': 'Request Entity Too Large',
          'status': 413,
          'detail': 'request body is too large limit=1048576 bytes',
        }, status: 413),
      });

      await expectLater(
        _comments(dio).create(21, '<p>x</p>'),
        throwsA(
          isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 413),
        ),
      );
    });
  });

  group('update', () {
    test('v2 merge-patches the body and returns the stored comment', () async {
      final dio = fakeDio({
        '$_v2/tasks/21/comments/57': capturedFixture(
          'write/v2_comment_patch_2.7.0',
        ),
      });

      final comment = await _comments(dio)
          .update(21, 57, '<p>Edited on v2</p>');

      expect(_calls(dio), ['PATCH $_v2/tasks/21/comments/57']);
      final request = adapterOf(dio).requests.single;
      expect(request.contentType, 'application/merge-patch+json');
      expect(adapterOf(dio).decodedBodies.single, {
        'comment': '<p>Edited on v2</p>',
      });
      expect(comment.id, 57);
      expect(comment.html, '<p>Edited on v2</p>');
      expect(comment.author, _author);
      expect(comment.created, DateTime.utc(2026, 10, 21, 14, 9, 18));
      expect(comment.updated, DateTime.parse('2026-10-21T14:09:20.915803Z'));
      expect(comment.reactions, isEmpty);
    });

    test('v2: an unchanged body answers 304 and the comment is read', () async {
      final dio = fakeDio({
        '$_v2/tasks/21/comments/57': _byMethod({
          'PATCH': capturedFixture('write/v2_comment_patch_unchanged_2.7.0'),
          'GET': capturedFixture('write/v2_comment_read_2.7.0'),
        }),
      });

      final comment = await _comments(dio)
          .update(21, 57, '<p>Edited on v2</p>');

      expect(_calls(dio), [
        'PATCH $_v2/tasks/21/comments/57',
        'GET $_v2/tasks/21/comments/57',
      ]);
      expect(comment.html, '<p>Edited on v2</p>');
      expect(comment.author, _author);
      expect(comment.updated, DateTime.utc(2026, 10, 21, 14, 9, 20));
    });

    test('v1 reads the comment, posts the body and keeps the author and '
        'created the echo lacks', () async {
      final dio = fakeDio({
        '$_v1/tasks/21/comments/56': _byMethod({
          'GET': capturedFixture('write/v1_comment_read_2.7.0'),
          'POST': capturedFixture('write/v1_comment_update_2.7.0'),
        }),
      });

      final comment = await _comments(
        dio,
        hasV2: false,
      ).update(21, 56, '<p>Edited on v1</p>');

      expect(_calls(dio), [
        'GET $_v1/tasks/21/comments/56',
        'POST $_v1/tasks/21/comments/56',
      ]);
      expect(adapterOf(dio).decodedBodies.last, {
        'comment': '<p>Edited on v1</p>',
      });
      expect(comment.id, 56);
      expect(comment.html, '<p>Edited on v1</p>');
      expect(comment.author, _author);
      expect(comment.created, DateTime.utc(2026, 10, 21, 14, 9, 8));
      expect(comment.updated, DateTime.parse('2026-10-21T14:09:10.773171Z'));
      expect(comment.reactions, isEmpty);
    });

    for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
      final version = hasV2 ? 'v2' : 'v1';

      test('$version: a comment that does not exist', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments/$_missing': _byMethod({
            'GET': capturedFixture(
              'write/${version}_comment_read_unknown_2.7.0',
            ),
            'PATCH': capturedFixture('write/v2_comment_patch_unknown_2.7.0'),
          }),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).update(21, _missing, '<p>x</p>'),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4015)),
        );
      });

      test('$version: a write the server did not apply although the comment '
          'is still there', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments/56': _byMethod({
            'GET': capturedFixture('write/v1_comment_read_2.7.0'),
            'POST': capturedFixture('write/v1_comment_read_unknown_2.7.0'),
            'PATCH': capturedFixture('write/v2_comment_patch_unknown_2.7.0'),
          }),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).update(21, 56, '<p>x</p>'),
          throwsA(
            isA<ServerFailure>()
                .having((f) => f.statusCode, 'status', 404)
                .having((f) => f.code, 'code', isNull),
          ),
        );
        expect(_calls(dio).last, 'GET $base/tasks/21/comments/56');
      });

      test('$version: an archived project', () async {
        final dio = fakeDio({
          '$base/tasks/22/comments/55': _byMethod({
            'GET': capturedFixture('write/v1_comment_read_2.7.0'),
            'POST': capturedFixture('write/v1_comment_update_archived_2.7.0'),
            'PATCH': capturedFixture('write/v2_comment_patch_archived_2.7.0'),
          }),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).update(22, 55, '<p>x</p>'),
          throwsA(isA<DomainError>().having((f) => f.code, 'code', 3008)),
        );
      });

      test('$version: only the author may change a comment', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments/56': _byMethod({
            'GET': capturedFixture('write/v1_comment_read_2.7.0'),
            'POST': errorFixture('v1_403_project_2.7.0'),
            'PATCH': errorFixture('v2_403_project_2.7.0'),
          }),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).update(21, 56, '<p>x</p>'),
          throwsA(isA<Forbidden>()),
        );
      });

      test('$version: an empty body', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments/56': _byMethod({
            'GET': capturedFixture('write/v1_comment_read_2.7.0'),
            'POST': capturedFixture('write/v1_comment_create_empty_2.7.0'),
            'PATCH': capturedFixture('write/v2_comment_create_empty_2.7.0'),
          }),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).update(21, 56, ''),
          throwsA(isA<ValidationFailed>().having((f) => f.code, 'code', 2002)),
        );
      });
    }
  });

  group('delete', () {
    for (final (hasV2, base, id) in [(true, _v2, 57), (false, _v1, 56)]) {
      final version = hasV2 ? 'v2' : 'v1';

      test('$version deletes the comment', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments/$id': capturedFixture(
            'write/${version}_comment_delete_2.7.0',
          ),
        });

        await _comments(dio, hasV2: hasV2).delete(21, id);

        expect(_calls(dio), ['DELETE $base/tasks/21/comments/$id']);
        expect(adapterOf(dio).requestBodies.single, isNull);
      });

      test('$version: one that is gone counts as deleted once a read '
          'confirms it', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments/$id': _byMethod({
            'DELETE': capturedFixture(
              'write/${version}_comment_delete_unknown_2.7.0',
            ),
            'GET': capturedFixture(
              'write/${version}_comment_read_unknown_2.7.0',
            ),
          }),
        });

        await _comments(dio, hasV2: hasV2).delete(21, id);

        expect(_calls(dio), [
          'DELETE $base/tasks/21/comments/$id',
          'GET $base/tasks/21/comments/$id',
        ]);
      });

      test('$version: a delete the server did not apply', () async {
        final dio = fakeDio({
          '$base/tasks/21/comments/$id': _byMethod({
            'DELETE': capturedFixture(
              'write/${version}_comment_delete_unknown_2.7.0',
            ),
            'GET': capturedFixture('write/${version}_comment_read_2.7.0'),
          }),
        });

        await expectLater(
          _comments(dio, hasV2: hasV2).delete(21, id),
          throwsA(
            isA<ServerFailure>().having((f) => f.statusCode, 'status', 404),
          ),
        );
      });

      test('$version: an archived project and other failures', () async {
        final dio = fakeDio({
          '$base/tasks/22/comments/55': capturedFixture(
            'write/${version}_comment_delete_archived_2.7.0',
          ),
          '$base/tasks/21/comments/1': errorFixture(
            '${version}_403_project_2.7.0',
          ),
          '$base/tasks/$_missing/comments/1': json({
            'code': 4002,
            'message': 'This task does not exist',
          }, status: 404),
          '$base/tasks/21/comments/2': _byMethod({
            'DELETE': capturedFixture(
              'write/${version}_comment_delete_unknown_2.7.0',
            ),
            'GET': errorFixture('${version}_403_project_2.7.0'),
          }),
        });
        final comments = _comments(dio, hasV2: hasV2);

        await expectLater(
          comments.delete(22, 55),
          throwsA(isA<DomainError>().having((f) => f.code, 'code', 3008)),
        );
        await expectLater(comments.delete(21, 1), throwsA(isA<Forbidden>()));
        await expectLater(
          comments.delete(_missing, 1),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
        // The read that should confirm the delete fails itself.
        await expectLater(comments.delete(21, 2), throwsA(isA<Forbidden>()));
        await expectLater(
          _comments(fakeDio({}), hasV2: hasV2).delete(21, 1),
          throwsA(isA<NetworkFailure>()),
        );
      });
    }

    test('comments switched off: the route is absent', () async {
      final dio = fakeDio({
        '$_v2/tasks/21/comments/5': errorFixture('v2_404_route_2.7.0'),
      });

      await expectLater(
        _comments(dio).delete(21, 5),
        throwsA(
          isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', isTrue),
        ),
      );
    });
  });

  test('a cancelled request rethrows its DioException', () async {
    final dio = fakeDio({
      '$_v2/tasks/21/comments': failsWith(
        (request) => DioException.requestCancelled(
          requestOptions: request,
          reason: 'closed',
        ),
      ),
    });

    await expectLater(
      _comments(dio).create(21, '<p>x</p>'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });
}
