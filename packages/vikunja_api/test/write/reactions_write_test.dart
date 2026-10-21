import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _missing = 999999999;

ReactionsWritePort _reactions(Dio dio, {bool hasV2 = true}) =>
    createWriteClient(
      dio: dio,
      connection: testConnection(hasV2: hasV2),
    ).reactions;

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

// The answers were captured from 2.7.0 by
// tool/capture_comment_fixtures.dart.
void main() {
  for (final (hasV2, create, base, commentId) in [
    (true, 'POST', _v2, 57),
    (false, 'PUT', _v1, 56),
  ]) {
    final version = hasV2 ? 'v2' : 'v1';

    group(version, () {
      test('adds to a task and to a comment', () async {
        final dio = fakeDio({
          '$base/tasks/21/reactions': capturedFixture(
            'write/${version}_reaction_add_task_2.7.0',
          ),
          '$base/comments/$commentId/reactions': capturedFixture(
            'write/${version}_reaction_add_comment_2.7.0',
          ),
        });
        final reactions = _reactions(dio, hasV2: hasV2);

        await reactions.add(ReactionEntity.task, 21, '👍');
        await reactions.add(ReactionEntity.comment, commentId, '🎉');

        expect(_calls(dio), [
          '$create $base/tasks/21/reactions',
          '$create $base/comments/$commentId/reactions',
        ]);
        expect(adapterOf(dio).decodedBodies, [
          {'value': '👍'},
          {'value': '🎉'},
        ]);
      });

      test('adding the same value again is no failure', () async {
        final dio = fakeDio({
          '$base/tasks/21/reactions': capturedFixture(
            'write/${version}_reaction_add_task_again_2.7.0',
          ),
        });

        await expectLater(
          _reactions(dio, hasV2: hasV2).add(ReactionEntity.task, 21, '👍'),
          completes,
        );
      });

      test('removes with a post on both versions, also a value never '
          'added', () async {
        final dio = fakeDio({
          '$base/tasks/21/reactions/delete': sequence([
            capturedFixture('write/${version}_reaction_remove_task_2.7.0'),
            capturedFixture('write/${version}_reaction_remove_absent_2.7.0'),
          ]),
          '$base/comments/$commentId/reactions/delete': capturedFixture(
            'write/${version}_reaction_remove_task_2.7.0',
          ),
        });
        final reactions = _reactions(dio, hasV2: hasV2);

        await reactions.remove(ReactionEntity.task, 21, '👍');
        await reactions.remove(ReactionEntity.task, 21, '🚀');
        await reactions.remove(ReactionEntity.comment, commentId, '🎉');

        expect(_calls(dio), [
          'POST $base/tasks/21/reactions/delete',
          'POST $base/tasks/21/reactions/delete',
          'POST $base/comments/$commentId/reactions/delete',
        ]);
        expect(adapterOf(dio).decodedBodies, [
          {'value': '👍'},
          {'value': '🚀'},
          {'value': '🎉'},
        ]);
      });

      test('a missing task or comment and an archived project', () async {
        final dio = fakeDio({
          '$base/tasks/$_missing/reactions': capturedFixture(
            'write/${version}_reaction_add_unknown_task_2.7.0',
          ),
          '$base/comments/$_missing/reactions': capturedFixture(
            'write/${version}_reaction_add_unknown_comment_2.7.0',
          ),
          '$base/tasks/22/reactions': capturedFixture(
            'write/${version}_reaction_add_archived_2.7.0',
          ),
        });
        final reactions = _reactions(dio, hasV2: hasV2);

        await expectLater(
          reactions.add(ReactionEntity.task, _missing, '👍'),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
        await expectLater(
          reactions.add(ReactionEntity.comment, _missing, '👍'),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4015)),
        );
        await expectLater(
          reactions.add(ReactionEntity.task, 22, '👍'),
          throwsA(isA<DomainError>().having((f) => f.code, 'code', 3008)),
        );
      });

      test('a read share is forbidden', () async {
        final dio = fakeDio({
          '$base/tasks/21/reactions': errorFixture(
            '${version}_403_project_2.7.0',
          ),
          '$base/tasks/21/reactions/delete': errorFixture(
            '${version}_403_project_2.7.0',
          ),
        });
        final reactions = _reactions(dio, hasV2: hasV2);

        await expectLater(
          reactions.add(ReactionEntity.task, 21, '👍'),
          throwsA(isA<Forbidden>()),
        );
        await expectLater(
          reactions.remove(ReactionEntity.task, 21, '👍'),
          throwsA(isA<Forbidden>()),
        );
      });

      test('an empty value to remove is for the server to refuse', () async {
        final dio = fakeDio({
          '$base/tasks/21/reactions/delete': capturedFixture(
            'write/${version}_reaction_add_empty_2.7.0',
          ),
        });

        await expectLater(
          _reactions(dio, hasV2: hasV2).remove(ReactionEntity.task, 21, ''),
          throwsA(isA<ValidationFailed>().having((f) => f.code, 'code', 2002)),
        );
      });
    });
  }

  group('values', () {
    test('up to 20 code points are sent as they are', () async {
      final dio = fakeDio({
        '$_v2/tasks/21/reactions': capturedFixture(
          'write/v2_reaction_add_task_2.7.0',
        ),
      });
      final reactions = _reactions(dio);
      final values = ['😀' * 20, 'ä' * 20, '👨‍👩‍👧‍👦', ' 👍', '❤️', 'x'];

      for (final value in values) {
        await reactions.add(ReactionEntity.task, 21, value);
      }

      expect(adapterOf(dio).decodedBodies, [
        for (final value in values) {'value': value},
      ]);
    });

    test('an empty value or more than 20 code points is refused before '
        'any request', () async {
      final dio = fakeDio({});
      final reactions = _reactions(dio, hasV2: false);

      for (final value in ['', '😀' * 21, 'x' * 21]) {
        await expectLater(
          reactions.add(ReactionEntity.task, 21, value),
          throwsArgumentError,
          reason: value,
        );
      }
      expect(adapterOf(dio).requests, isEmpty);
    });

    test('v1 stores a longer value that v2 refuses to remove', () async {
      final dio = fakeDio({
        '$_v1/tasks/21/reactions/delete': capturedFixture(
          'write/v1_reaction_remove_21_2.7.0',
        ),
        '$_v2/tasks/21/reactions/delete': capturedFixture(
          'write/v2_reaction_remove_21_2.7.0',
        ),
      });

      await expectLater(
        _reactions(
          dio,
          hasV2: false,
        ).remove(ReactionEntity.task, 21, '😀' * 21),
        completes,
      );
      await expectLater(
        _reactions(dio).remove(ReactionEntity.task, 21, '😀' * 21),
        throwsA(
          isA<ValidationFailed>().having((f) => f.code, 'code', isNull).having(
            (f) => f.fieldErrors.keys,
            'fields',
            ['value'],
          ),
        ),
      );
    });

    // Recorded to document what the client keeps the user from.
    test('the captures of 21 code points', () {
      expect(fixtureJson('write/v1_reaction_add_21_2.7.0.json')['status'], 201);
      expect(fixtureJson('write/v2_reaction_add_21_2.7.0.json')['status'], 422);
    });
  });

  test('errors are normalized', () async {
    final dio = fakeDio({
      '$_v2/tasks/1/reactions': errorFixture('v2_401_code11_missing_2.7.0'),
      '$_v2/tasks/2/reactions': json({'message': 'boom'}, status: 500),
    });
    final reactions = _reactions(dio);

    await expectLater(
      reactions.add(ReactionEntity.task, 1, '👍'),
      throwsA(isA<TokenRejected>()),
    );
    await expectLater(
      reactions.add(ReactionEntity.task, 2, '👍'),
      throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'status', 500)),
    );
    await expectLater(
      _reactions(fakeDio({})).remove(ReactionEntity.comment, 1, '👍'),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
