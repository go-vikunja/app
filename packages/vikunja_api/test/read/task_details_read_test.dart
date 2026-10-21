import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

TasksPort _tasks(Dio dio, ApiVersion version) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: version == ApiVersion.v2),
).tasks;

String _detailsUrl(ApiVersion version, int id) =>
    '$testServerRoot/api/${version.pathSegment}/tasks/$id'
    '?expand=reactions&expand=comment_count&expand=is_unread';

void main() {
  for (final version in ApiVersion.values) {
    group(version.pathSegment, () {
      test('a 2.7.0 single read with attachments, reactions, comments, '
          'unread and a subscription', () async {
        final dio = fakeDio({
          _detailsUrl(version, 17): capturedFixture(
            'read/${version.pathSegment}_task_details_2.7.0',
          ),
        });

        final details = await _tasks(dio, version).readDetails(17);

        expect(details.attachments, const [
          TaskAttachment(
            id: 14,
            taskId: 17,
            name: 'pic.png',
            mime: 'image/png',
            size: 82185,
          ),
          TaskAttachment(
            id: 15,
            taskId: 17,
            name: 'notes.txt',
            mime: 'text/plain; charset=utf-8',
            size: 37,
          ),
          TaskAttachment(
            id: 16,
            taskId: 17,
            name: 'vector.svg',
            mime: 'image/svg+xml',
            size: 124,
          ),
          TaskAttachment(
            id: 17,
            taskId: 17,
            name: 'spoof.png',
            mime: 'text/plain; charset=utf-8',
            size: 37,
          ),
        ]);
        final first = details.attachments.first;
        expect(first.created, DateTime.utc(2026, 10, 19, 6, 24, 31));
        expect(first.createdBy?.username, 'p10a941d3a');
        expect(details.coverImageAttachmentId, 14);
        expect(
          details.reactions.map(
            (value, users) => MapEntry(value, [for (final u in users) u.id]),
          ),
          {
            'xxxxxxxxxxxxxxxxxxxxx': [3],
            '👍': [3, 4],
            '🚀': [4],
          },
        );
        expect(details.reactions.keys, ['xxxxxxxxxxxxxxxxxxxxx', '👍', '🚀']);
        expect(details.commentCount, 7);
        expect(details.isUnread, isTrue);
        expect(
          details.subscription,
          const Subscription(entity: SubscriptionEntity.task, entityId: 17),
        );
        // v2 in the body, v1 in the `x-max-permission` header.
        expect(details.maxPermission, Permission.admin);
        final request = adapterOf(dio).requests.single;
        expect(request.method, 'GET');
      });

      test('max_permission of a read and a write share, and an unknown '
          'value', () async {
        final dio = fakeDio({
          for (final (id, permission) in [(1, 0), (2, 1), (3, 7), (4, '1')])
            _detailsUrl(version, id): json(
              taskJson(id, overrides: {'max_permission': permission}),
            ),
        });
        final tasks = _tasks(dio, version);

        expect((await tasks.readDetails(1)).maxPermission, Permission.read);
        expect((await tasks.readDetails(2)).maxPermission, Permission.write);
        expect((await tasks.readDetails(3)).maxPermission, isNull);
        expect((await tasks.readDetails(4)).maxPermission, isNull);
      });

      test('the x-max-permission header where the body has none; the body '
          'wins', () async {
        FakeRoute withHeader(int id, String permission, {Object? body}) =>
            (_) => ResponseBody.fromString(
              jsonEncode(taskJson(id, overrides: {'max_permission': body})),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
                'x-max-permission': [permission],
              },
            );
        final dio = fakeDio({
          _detailsUrl(version, 1): withHeader(1, '0'),
          _detailsUrl(version, 2): withHeader(2, '1'),
          _detailsUrl(version, 3): withHeader(3, 'admin'),
          _detailsUrl(version, 4): withHeader(4, '0', body: 2),
        });
        final tasks = _tasks(dio, version);

        expect((await tasks.readDetails(1)).maxPermission, Permission.read);
        expect((await tasks.readDetails(2)).maxPermission, Permission.write);
        expect((await tasks.readDetails(3)).maxPermission, isNull);
        expect((await tasks.readDetails(4)).maxPermission, Permission.admin);
      });

      test('a plain task: nothing attached, nobody reacted, read, not '
          'followed', () async {
        final dio = fakeDio({
          _detailsUrl(version, 5): json(
            taskJson(
              5,
              overrides: {
                'attachments': null,
                'cover_image_attachment_id': 0,
                'reactions': null,
                'comment_count': 0,
              },
            ),
          ),
        });

        final details = await _tasks(dio, version).readDetails(5);

        expect(details.attachments, isEmpty);
        expect(details.coverImageAttachmentId, 0);
        expect(details.reactions, isEmpty);
        expect(details.commentCount, 0);
        expect(details.isUnread, isFalse);
        expect(details.subscription, isNull);
        expect(details.maxPermission, isNull);
      });

      test('odd values: a dangling cover, an empty reaction, an attachment '
          'without an id, is_unread false, no comment count', () async {
        final dio = fakeDio({
          _detailsUrl(version, 5): json(
            taskJson(
              5,
              overrides: {
                'attachments': [
                  {
                    'id': 9,
                    'file': {'name': 'a.png'},
                  },
                  {
                    'file': {'name': 'b.png'},
                  },
                  'nonsense',
                ],
                'cover_image_attachment_id': 22,
                'reactions': {
                  '👍': <Object?>[],
                  '🎉': [userJson(2, 'bob'), 'nobody'],
                  '❤️': null,
                },
                'is_unread': false,
              },
            ),
          ),
        });

        final details = await _tasks(dio, version).readDetails(5);

        expect(details.attachments, const [
          TaskAttachment(id: 9, taskId: 5, name: 'a.png'),
        ]);
        expect(details.coverImageAttachmentId, 22);
        expect(details.reactions.keys, ['🎉']);
        expect(details.reactions['🎉']!.single.username, 'bob');
        expect(details.commentCount, 0);
        expect(details.isUnread, isFalse);
      });

      test('a body that is no task is unexpected', () async {
        final dio = fakeDio({
          _detailsUrl(version, 5): json([1, 2]),
        });

        await expectLater(
          _tasks(dio, version).readDetails(5),
          throwsA(isA<UnexpectedResponse>()),
        );
      });

      test('errors are normalized', () async {
        final dio = fakeDio({
          _detailsUrl(version, 5): json({
            'code': 4002,
            'message': 'This task does not exist',
          }, status: 404),
          _detailsUrl(version, 6): json({
            'code': 1,
            'message': "You're not allowed to do this.",
          }, status: 403),
        });
        final tasks = _tasks(dio, version);

        await expectLater(
          tasks.readDetails(5),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
        await expectLater(tasks.readDetails(6), throwsA(isA<Forbidden>()));
        await expectLater(
          _tasks(fakeDio({}), version).readDetails(5),
          throwsA(isA<NetworkFailure>()),
        );
      });
    });
  }
}
