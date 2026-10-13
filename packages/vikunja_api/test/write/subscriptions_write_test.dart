import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

SubscriptionsWritePort _subscriptions(Dio dio, {bool hasV2 = true}) =>
    createWriteClient(
      dio: dio,
      connection: testConnection(hasV2: hasV2),
    ).subscriptions;

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

/// The error bodies of 2.7.0: problem+json on v2, `{code, message}` on v1.
FakeRoute _error(int status, int? code, {required bool hasV2}) => json(
  hasV2
      ? {
          'title': 'Error',
          'status': status,
          'detail': 'Vikunja code $code',
          'code': ?code,
        }
      : {'code': code ?? 0, 'message': 'Vikunja code $code'},
  status: status,
);

Map<String, Object?> _subscription(String entity, int entityId) => {
  'id': 99,
  'entity': entity,
  'entity_id': entityId,
  'created': '2026-10-13T17:25:23Z',
};

Map<String, Object?> _project(int id, {Object? subscription}) => {
  'id': id,
  'title': 'Project $id',
  'subscription': subscription,
};

void main() {
  for (final (hasV2, base, create, deleted) in [
    (true, _v2, 'POST', 204),
    (false, _v1, 'PUT', 200),
  ]) {
    final version = hasV2 ? 'v2' : 'v1';

    group('$version subscribe', () {
      for (final (entity, id) in [
        (SubscriptionEntity.task, 42),
        (SubscriptionEntity.project, 7),
      ]) {
        test('${entity.name} sends $create without a body', () async {
          final path = '$base/subscriptions/${entity.wireName}/$id';
          final dio = fakeDio({
            path: json(_subscription(entity.wireName, id), status: 201),
          });

          await _subscriptions(dio, hasV2: hasV2).subscribe(entity, id);

          expect(_calls(dio), ['$create $path']);
          expect(adapterOf(dio).decodedBodies, [null]);
        });
      }

      test('already subscribed (412 code 12002), as the creator of a task '
          'always is, counts as done', () async {
        final dio = fakeDio({
          '$base/subscriptions/task/42': _error(412, 12002, hasV2: hasV2),
        });

        await _subscriptions(
          dio,
          hasV2: hasV2,
        ).subscribe(SubscriptionEntity.task, 42);

        expect(_calls(dio), hasLength(1));
      });

      for (final (name, route, failure) in [
        (
          'a missing task',
          _error(404, 4002, hasV2: hasV2),
          isA<NotFound>().having((f) => f.code, 'code', 4002),
        ),
        (
          'a task the user may not see',
          _error(403, null, hasV2: hasV2),
          isA<Forbidden>(),
        ),
        (
          'another 412',
          _error(412, 12001, hasV2: hasV2),
          isA<DomainError>().having((f) => f.code, 'code', 12001),
        ),
      ]) {
        test('$name fails', () async {
          final dio = fakeDio({'$base/subscriptions/task/42': route});

          await expectLater(
            _subscriptions(
              dio,
              hasV2: hasV2,
            ).subscribe(SubscriptionEntity.task, 42),
            throwsA(failure),
          );
        });
      }
    });

    group('$version unsubscribe', () {
      test('sends DELETE', () async {
        final dio = fakeDio({
          '$base/subscriptions/project/7': json({
            'message': 'Successfully deleted.',
          }, status: deleted),
        });

        await _subscriptions(
          dio,
          hasV2: hasV2,
        ).unsubscribe(SubscriptionEntity.project, 7);

        expect(_calls(dio), ['DELETE $base/subscriptions/project/7']);
      });

      test('nothing to delete (403 without a code) counts as done when the '
          'task reads without a subscription', () async {
        final dio = fakeDio({
          '$base/subscriptions/task/42': _error(403, null, hasV2: hasV2),
          '$base/tasks/42': json(
            taskJson(42, overrides: {'subscription': null}),
          ),
        });

        await _subscriptions(
          dio,
          hasV2: hasV2,
        ).unsubscribe(SubscriptionEntity.task, 42);

        expect(_calls(dio), [
          'DELETE $base/subscriptions/task/42',
          'GET $base/tasks/42',
        ]);
      });

      test('a project is read at its own path', () async {
        final dio = fakeDio({
          '$base/subscriptions/project/7': _error(403, null, hasV2: hasV2),
          '$base/projects/7': json(_project(7)),
        });

        await _subscriptions(
          dio,
          hasV2: hasV2,
        ).unsubscribe(SubscriptionEntity.project, 7);

        expect(_calls(dio), [
          'DELETE $base/subscriptions/project/7',
          'GET $base/projects/7',
        ]);
      });
    });
  }

  group('unsubscribe fails', () {
    for (final (name, subscription) in [
      ('when the task still reads its own subscription', ('task', 42)),
      ('when the task still follows its project', ('project', 7)),
    ]) {
      test(name, () async {
        final dio = fakeDio({
          '$_v2/subscriptions/task/42': _error(403, null, hasV2: true),
          '$_v2/tasks/42': json(
            taskJson(
              42,
              overrides: {
                'subscription': _subscription(subscription.$1, subscription.$2),
              },
            ),
          ),
        });

        await expectLater(
          _subscriptions(dio).unsubscribe(SubscriptionEntity.task, 42),
          throwsA(isA<Forbidden>()),
        );
      });
    }

    test(
      'with the failure of the read when the task is gone meanwhile',
      () async {
        final dio = fakeDio({
          '$_v1/subscriptions/task/42': _error(403, null, hasV2: false),
          '$_v1/tasks/42': _error(404, 4002, hasV2: false),
        });

        await expectLater(
          _subscriptions(
            dio,
            hasV2: false,
          ).unsubscribe(SubscriptionEntity.task, 42),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
      },
    );

    test('without a read for a 403 that has a code', () async {
      final dio = fakeDio({
        '$_v2/subscriptions/task/42': _error(403, 7003, hasV2: true),
      });

      await expectLater(
        _subscriptions(dio).unsubscribe(SubscriptionEntity.task, 42),
        throwsA(isA<Forbidden>().having((f) => f.code, 'code', 7003)),
      );
      expect(_calls(dio), hasLength(1));
    });

    test('for a missing task', () async {
      final dio = fakeDio({
        '$_v2/subscriptions/task/42': _error(404, 4002, hasV2: true),
      });

      await expectLater(
        _subscriptions(dio).unsubscribe(SubscriptionEntity.task, 42),
        throwsA(isA<NotFound>()),
      );
    });
  });
}
