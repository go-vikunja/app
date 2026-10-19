import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_bucket_fixtures.dart: project
// 842, Kanban view 4712 with To-Do 3546, Doing 3547 and Done 3548, then
// Later 3552 (v1) and Someday 3553 (v2); a second board 4713 down to its
// last bucket 3551.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _project = 842;
const _kanban = 4712;
const _toDo = 3546;
const _doing = 3547;
const _done = 3548;
const _later = 3552;
const _someday = 3553;

VikunjaWriteClient _client(Dio dio, {required bool hasV2}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

String _buckets(String base, {int viewId = _kanban}) =>
    '$base/projects/$_project/views/$viewId/buckets';

String _view(String base) => '$base/projects/$_project/views/$_kanban';

FakeRoute _write(String name) => capturedFixture('write/$name');

void main() {
  for (final hasV2 in [true, false]) {
    final version = hasV2 ? 'v2' : 'v1';
    final base = hasV2 ? _v2 : _v1;
    final createVerb = hasV2 ? 'POST' : 'PUT';
    final updateVerb = hasV2 ? 'PUT' : 'POST';

    group('$version bucket create', () {
      test('sends $createVerb with title and limit, no position unless '
          'given, and returns the created bucket', () async {
        final dio = fakeDio({_buckets(base): _write('v1_bucket_create_2.7.0')});

        final bucket = await _client(
          dio,
          hasV2: hasV2,
        ).buckets.create(_project, _kanban, title: 'Later');

        expect(_calls(dio), ['$createVerb ${_buckets(base)}']);
        expect(adapterOf(dio).decodedBodies, [
          {'title': 'Later', 'limit': 0},
        ]);
        expect(
          bucket,
          const Bucket(
            id: _later,
            viewId: _kanban,
            title: 'Later',
            position: 232783872,
          ),
        );
      });

      test('sends a limit and a position', () async {
        final dio = fakeDio({_buckets(base): _write('v2_bucket_create_2.7.0')});

        final bucket = await _client(dio, hasV2: hasV2).buckets.create(
          _project,
          _kanban,
          title: 'Someday',
          limit: 3,
          position: 500,
        );

        expect(adapterOf(dio).decodedBodies, [
          {'title': 'Someday', 'limit': 3, 'position': 500},
        ]);
        expect(bucket.id, _someday);
        expect(bucket.limit, 3);
        expect(bucket.position, 500);
      });

      test('an empty title fails validation', () async {
        final dio = fakeDio({
          _buckets(base): _write('${version}_bucket_create_empty_title_2.7.0'),
        });

        await expectLater(
          _client(
            dio,
            hasV2: hasV2,
          ).buckets.create(_project, _kanban, title: ''),
          throwsA(
            isA<ValidationFailed>().having(
              (failure) => failure.fieldErrors.keys,
              'fields',
              ['title'],
            ),
          ),
        );
      });
    });

    group('$version bucket update', () {
      test('sends $updateVerb with title, limit and position together and '
          'returns what was sent', () async {
        final dio = fakeDio({
          '${_buckets(base)}/$_later': _write('v1_bucket_update_2.7.0'),
        });

        final bucket = await _client(dio, hasV2: hasV2).buckets.update(
          _project,
          _kanban,
          bucketId: _later,
          title: 'Next week',
          limit: 2,
          position: 450,
        );

        expect(_calls(dio), ['$updateVerb ${_buckets(base)}/$_later']);
        expect(adapterOf(dio).decodedBodies, [
          {'title': 'Next week', 'limit': 2, 'position': 450},
        ]);
        expect(
          bucket,
          const Bucket(
            id: _later,
            viewId: _kanban,
            title: 'Next week',
            limit: 2,
            position: 450,
          ),
        );
      });

      test('sends a cleared limit and a zero position as they are', () async {
        final dio = fakeDio({
          '${_buckets(base)}/$_someday': _write('v2_bucket_update_2.7.0'),
        });

        await _client(dio, hasV2: hasV2).buckets.update(
          _project,
          _kanban,
          bucketId: _someday,
          title: 'Some day',
          limit: 0,
          position: 0,
        );

        expect(adapterOf(dio).decodedBodies, [
          {'title': 'Some day', 'limit': 0, 'position': 0},
        ]);
      });

      test('a bucket that is gone fails with code 10001', () async {
        final dio = fakeDio({
          '${_buckets(base)}/$_doing': _write(
            '${version}_bucket_delete_unknown_2.7.0',
          ),
        });

        await expectLater(
          _client(dio, hasV2: hasV2).buckets.update(
            _project,
            _kanban,
            bucketId: _doing,
            title: 'Doing',
            limit: 0,
            position: 200,
          ),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 10001)),
        );
      });
    });

    group('$version bucket delete', () {
      test('sends DELETE', () async {
        final dio = fakeDio({
          '${_buckets(base)}/$_doing': _write('${version}_bucket_delete_2.7.0'),
        });

        await _client(
          dio,
          hasV2: hasV2,
        ).buckets.delete(_project, _kanban, _doing);

        expect(_calls(dio), ['DELETE ${_buckets(base)}/$_doing']);
        expect(adapterOf(dio).decodedBodies, [null]);
      });

      test('a bucket that is gone already (404 code 10001) counts as '
          'deleted', () async {
        final dio = fakeDio({
          '${_buckets(base)}/$_doing': _write(
            '${version}_bucket_delete_unknown_2.7.0',
          ),
        });

        await _client(
          dio,
          hasV2: hasV2,
        ).buckets.delete(_project, _kanban, _doing);
      });

      test('a missing route still fails', () async {
        final dio = fakeDio({
          '${_buckets(base)}/$_doing': errorFixture('v1_404_route_2.7.0'),
        });

        await expectLater(
          _client(dio, hasV2: hasV2).buckets.delete(_project, _kanban, _doing),
          throwsA(isA<NotFound>()),
        );
      });

      test('the last bucket fails with code 10003', () async {
        final dio = fakeDio({
          '${_buckets(base, viewId: 4713)}/3551': _write(
            '${version}_bucket_delete_last_2.7.0',
          ),
        });

        await expectLater(
          _client(dio, hasV2: hasV2).buckets.delete(_project, 4713, 3551),
          throwsA(isA<DomainError>().having((f) => f.code, 'code', 10003)),
        );
      });
    });
  }

  test('v2 bucket create in an archived project fails with code '
      '3008', () async {
    final dio = fakeDio({
      _buckets(_v2): _write('v2_bucket_create_archived_2.7.0'),
    });

    await expectLater(
      _client(
        dio,
        hasV2: true,
      ).buckets.create(_project, _kanban, title: 'Archived'),
      throwsA(isA<DomainError>().having((f) => f.code, 'code', 3008)),
    );
  });

  group('v2 view buckets', () {
    test('send a merge-patch with only the given ids and return the view '
        'as stored', () async {
      final dio = fakeDio({_view(_v2): _write('v2_project_view_patch_2.7.0')});

      final view = await _client(dio, hasV2: true).views.setBuckets(
        _project,
        _kanban,
        doneBucketId: _done,
        defaultBucketId: _later,
      );

      expect(_calls(dio), ['PATCH ${_view(_v2)}']);
      expect(
        adapterOf(dio).requests.single.headers['content-type'],
        'application/merge-patch+json',
      );
      expect(adapterOf(dio).decodedBodies, [
        {'done_bucket_id': _done, 'default_bucket_id': _later},
      ]);
      expect(view.id, _kanban);
      expect(view.kind, ProjectViewKind.kanban);
      expect(view.doneBucketId, _done);
      expect(view.defaultBucketId, _later);
    });

    test('send 0 to clear one and leave the other out', () async {
      final dio = fakeDio({_view(_v2): _write('v2_project_view_patch_2.7.0')});

      await _client(
        dio,
        hasV2: true,
      ).views.setBuckets(_project, _kanban, doneBucketId: 0);

      expect(adapterOf(dio).decodedBodies, [
        {'done_bucket_id': 0},
      ]);
    });

    test('read the view when nothing changed (304)', () async {
      final dio = fakeDio({
        _view(_v2): _byMethod({
          'PATCH': _write('v2_project_view_patch_unchanged_2.7.0'),
          'GET': _write('v2_project_view_2.7.0'),
        }),
      });

      final view = await _client(
        dio,
        hasV2: true,
      ).views.setBuckets(_project, _kanban, doneBucketId: _doing);

      expect(_calls(dio), ['PATCH ${_view(_v2)}', 'GET ${_view(_v2)}']);
      expect(view.doneBucketId, _doing);
      expect(view.defaultBucketId, _toDo);
    });

    test('a bucket of another view fails with code 10002', () async {
      final dio = fakeDio({
        _view(_v2): _write('v2_project_view_patch_foreign_2.7.0'),
      });

      await expectLater(
        _client(
          dio,
          hasV2: true,
        ).views.setBuckets(_project, _kanban, doneBucketId: 3549),
        throwsA(isA<DomainError>().having((f) => f.code, 'code', 10002)),
      );
    });

    test('a view of a kind this client does not know is unexpected', () async {
      final dio = fakeDio({
        _view(_v2): json({
          'id': _kanban,
          'project_id': _project,
          'title': 'Kanban',
          'view_kind': 'timeline',
        }),
      });

      await expectLater(
        _client(
          dio,
          hasV2: true,
        ).views.setBuckets(_project, _kanban, doneBucketId: _done),
        throwsA(isA<UnexpectedResponse>()),
      );
    });
  });

  group('v1 view buckets', () {
    test('read the view and post every field back with the change', () async {
      final dio = fakeDio({
        _view(_v1): _byMethod({
          'GET': _write('v1_project_view_2.7.0'),
          'POST': _write('v1_project_view_update_2.7.0'),
        }),
      });

      final view = await _client(
        dio,
        hasV2: false,
      ).views.setBuckets(_project, _kanban, doneBucketId: _doing);

      expect(_calls(dio), ['GET ${_view(_v1)}', 'POST ${_view(_v1)}']);
      expect(adapterOf(dio).decodedBodies.last, {
        'id': _kanban,
        'title': 'Kanban',
        'project_id': _project,
        'view_kind': 'kanban',
        'filter': null,
        'position': 400,
        'bucket_configuration_mode': 'manual',
        'bucket_configuration': null,
        'default_bucket_id': _toDo,
        'done_bucket_id': _doing,
        'updated': '2026-10-19T18:34:03Z',
        'created': '2026-10-19T18:34:03Z',
      });
      expect(view.doneBucketId, _doing);
      expect(view.defaultBucketId, _toDo);
    });

    test('keep a filter and both ids when only the default changes', () async {
      const filter = {
        'filter': 'done = false',
        's': '',
        'sort_by': ['position'],
        'order_by': ['asc'],
        'filter_include_nulls': false,
      };
      final dio = fakeDio({
        _view(_v1): _byMethod({
          'GET': json({
            'id': _kanban,
            'title': 'Open work',
            'project_id': _project,
            'view_kind': 'kanban',
            'filter': filter,
            'position': 300,
            'bucket_configuration_mode': 'manual',
            'bucket_configuration': null,
            'default_bucket_id': _toDo,
            'done_bucket_id': _done,
          }),
          'POST': _write('v1_project_view_update_2.7.0'),
        }),
      });

      await _client(
        dio,
        hasV2: false,
      ).views.setBuckets(_project, _kanban, defaultBucketId: 0);

      expect(adapterOf(dio).decodedBodies.last, {
        'id': _kanban,
        'title': 'Open work',
        'project_id': _project,
        'view_kind': 'kanban',
        'filter': filter,
        'position': 300,
        'bucket_configuration_mode': 'manual',
        'bucket_configuration': null,
        'default_bucket_id': 0,
        'done_bucket_id': _done,
      });
    });
  });

  for (final hasV2 in [true, false]) {
    final base = hasV2 ? _v2 : _v1;
    test('${hasV2 ? 'v2' : 'v1'} view buckets without a change only read the '
        'view', () async {
      final dio = fakeDio({
        _view(base): _write('${hasV2 ? 'v2' : 'v1'}_project_view_2.7.0'),
      });

      final view = await _client(
        dio,
        hasV2: hasV2,
      ).views.setBuckets(_project, _kanban);

      expect(_calls(dio), ['GET ${_view(base)}']);
      expect(view.id, _kanban);
    });
  }
}
