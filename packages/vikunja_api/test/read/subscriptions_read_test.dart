import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

SubscriptionsPort _subscriptions(Dio dio, {bool hasV2 = true}) =>
    createReadClient(
      dio: dio,
      connection: testConnection(hasV2: hasV2),
    ).subscriptions;

Map<String, Object?> _subscription(String entity, int entityId) => {
  'id': 12412,
  'entity': entity,
  'entity_id': entityId,
  'created': '2026-10-13T17:25:23Z',
};

Map<String, Object?> _project(
  int id, {
  Map<String, Object?> overrides = const {},
}) => {
  'id': id,
  'title': 'Project $id',
  'identifier': '',
  'hex_color': '',
  'parent_project_id': 0,
  'is_archived': false,
  'views': <Object?>[],
  ...overrides,
};

void main() {
  for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
    final version = hasV2 ? 'v2' : 'v1';

    group('$version forTask', () {
      final cases = <(String, Object?, Subscription?)>[
        (
          'its own subscription',
          _subscription('task', 42),
          const Subscription(entity: SubscriptionEntity.task, entityId: 42),
        ),
        (
          "its project's",
          _subscription('project', 7),
          const Subscription(entity: SubscriptionEntity.project, entityId: 7),
        ),
        ('none', null, null),
      ];

      for (final (name, subscription, expected) in cases) {
        test(name, () async {
          final dio = fakeDio({
            '$base/tasks/42': json(
              taskJson(42, overrides: {'subscription': subscription}),
            ),
          });

          expect(await _subscriptions(dio, hasV2: hasV2).forTask(42), expected);
          expect(adapterOf(dio).requestedUrls, ['$base/tasks/42']);
        });
      }

      test('a task without the key is not followed', () async {
        final dio = fakeDio({'$base/tasks/42': json(taskJson(42))});

        expect(await _subscriptions(dio, hasV2: hasV2).forTask(42), isNull);
      });
    });

    group('$version forProject', () {
      test('its own or a parent project subscription', () async {
        final dio = fakeDio({
          '$base/projects/9': json(
            _project(
              9,
              overrides: {'subscription': _subscription('project', 7)},
            ),
          ),
          '$base/projects/7': json(
            _project(7, overrides: {'subscription': null}),
          ),
        });
        final subscriptions = _subscriptions(dio, hasV2: hasV2);

        expect(
          await subscriptions.forProject(9),
          const Subscription(entity: SubscriptionEntity.project, entityId: 7),
        );
        expect(await subscriptions.forProject(7), isNull);
        expect(adapterOf(dio).requestedUrls, [
          '$base/projects/9',
          '$base/projects/7',
        ]);
      });
    });
  }

  group('malformed answers are unexpected', () {
    for (final (name, body) in [
      (
        'an unknown entity',
        taskJson(
          42,
          overrides: {'subscription': _subscription('namespace', 3)},
        ),
      ),
      (
        'a subscription without its entity id',
        taskJson(
          42,
          overrides: {
            'subscription': {'entity': 'task'},
          },
        ),
      ),
      (
        'a subscription that is no object',
        taskJson(42, overrides: {'subscription': 'task'}),
      ),
      ('a body that is no object', <Object?>[]),
    ]) {
      test(name, () async {
        final dio = fakeDio({'$_v2/tasks/42': json(body)});

        await expectLater(
          _subscriptions(dio).forTask(42),
          throwsA(isA<UnexpectedResponse>()),
        );
      });
    }
  });

  test('errors are normalized', () async {
    final dio = fakeDio({
      '$_v2/tasks/42': json({'code': 4002, 'message': 'gone'}, status: 404),
      '$_v2/projects/7': json({'code': 0, 'message': 'Forbidden'}, status: 403),
    });
    final subscriptions = _subscriptions(dio);

    await expectLater(
      subscriptions.forTask(42),
      throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
    );
    await expectLater(subscriptions.forProject(7), throwsA(isA<Forbidden>()));
  });
}
