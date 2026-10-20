import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

VikunjaWriteClient _client(Dio dio, {required bool hasV2}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
);

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

Map<String, Object?> _task(String description) =>
    taskJson(42, overrides: {'description': description});

Map<String, Object?> _project(String description) => {
  'id': 7,
  'title': 'Studio',
  'description': description,
  'identifier': 'STU',
  'position': 65536,
};

const _projectEdit = ProjectChanges(description: '<p>mine</p>');

const _queued = TaskChanges(
  description: '<p>mine</p>',
  descriptionBase: '<p>base</p>',
  checklistToggles: [ChecklistToggle.byId('a', checked: true)],
  done: true,
);

void main() {
  group('v2', () {
    test('never sends the base or the taps', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(_task('<p>mine</p>'))});

      await _client(dio, hasV2: true).tasks.update(42, _queued);

      expect(_calls(dio), ['PATCH $_v2/tasks/42']);
      expect(adapterOf(dio).decodedBodies.single, {
        'description': '<p>mine</p>',
        'done': true,
      });
    });

    test('with a rebase reads the task once and patches what it returns '
        'for the server description', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': _byMethod({
          'GET': json(_task('<p>web</p>')),
          'PATCH': json(_task('<p>rebased</p>')),
        }),
      });
      final seen = <String>[];

      final task = await _client(dio, hasV2: true).tasks.update(
        42,
        _queued,
        rebaseDescription: (current) {
          seen.add(current);
          return '<p>rebased</p>';
        },
      );

      expect(seen, ['<p>web</p>']);
      expect(_calls(dio), ['GET $_v2/tasks/42', 'PATCH $_v2/tasks/42']);
      expect(adapterOf(dio).decodedBodies.last, {
        'description': '<p>rebased</p>',
        'done': true,
      });
      expect(task.description, '<p>rebased</p>');
    });

    test('a rebase that throws ends the call after the read', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(_task('<p>web</p>'))});

      await expectLater(
        _client(dio, hasV2: true).tasks.update(
          42,
          _queued,
          rebaseDescription: (_) => throw const DescriptionConflict(),
        ),
        throwsA(isA<DescriptionConflict>()),
      );
      expect(_calls(dio), ['GET $_v2/tasks/42']);
    });

    test('without a description the rebase is not asked and nothing is '
        'read first', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(_task('<p>web</p>'))});

      await _client(dio, hasV2: true).tasks.update(
        42,
        const TaskChanges(done: true),
        rebaseDescription: (_) => fail('asked without a description'),
      );

      expect(_calls(dio), ['PATCH $_v2/tasks/42']);
    });
  });

  group('v1', () {
    test('passes the description of the read the replace makes anyway and '
        'posts what the rebase returns', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': _byMethod({
          'GET': json(_task('<p>web</p>')),
          'POST': json(_task('<p>rebased</p>')),
        }),
      });
      final seen = <String>[];

      final task = await _client(dio, hasV2: false).tasks.update(
        42,
        _queued,
        rebaseDescription: (current) {
          seen.add(current);
          return '<p>rebased</p>';
        },
      );

      expect(seen, ['<p>web</p>']);
      expect(_calls(dio), ['GET $_v1/tasks/42', 'POST $_v1/tasks/42']);
      final body = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
      expect(body['description'], '<p>rebased</p>');
      expect(body['done'], isTrue);
      expect(
        body.keys,
        isNot(anyOf(contains('description_base'), contains('checklist'))),
      );
      expect(task.description, '<p>rebased</p>');
    });

    test('a rebase that throws posts nothing', () async {
      final dio = fakeDio({'$_v1/tasks/42': json(_task('<p>web</p>'))});

      await expectLater(
        _client(dio, hasV2: false).tasks.update(
          42,
          _queued,
          rebaseDescription: (_) => throw const DescriptionConflict(),
        ),
        throwsA(isA<DescriptionConflict>()),
      );
      expect(_calls(dio), ['GET $_v1/tasks/42']);
    });

    test('a description of null on the server is passed as empty', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': _byMethod({
          'GET': json(taskJson(42, overrides: {'description': null})),
          'POST': json(_task('<p>mine</p>')),
        }),
      });
      final seen = <String>[];

      await _client(dio, hasV2: false).tasks.update(
        42,
        _queued,
        rebaseDescription: (current) {
          seen.add(current);
          return '<p>mine</p>';
        },
      );

      expect(seen, ['']);
    });
  });

  group('project', () {
    for (final hasV2 in [true, false]) {
      final root = hasV2 ? _v2 : _v1;
      final write = hasV2 ? 'PATCH' : 'POST';

      test('${hasV2 ? 'v2' : 'v1'} with a rebase reads the project once and '
          'writes what it returns for the server description', () async {
        final dio = fakeDio({
          '$root/projects/7': _byMethod({
            'GET': json(_project('<p>web</p>')),
            write: json(_project('<p>rebased</p>')),
          }),
        });
        final seen = <String>[];

        final project = await _client(dio, hasV2: hasV2).projects.update(
          7,
          _projectEdit,
          rebaseDescription: (current) {
            seen.add(current);
            return '<p>rebased</p>';
          },
        );

        expect(seen, ['<p>web</p>']);
        expect(_calls(dio), [
          'GET $root/projects/7',
          '$write $root/projects/7',
        ]);
        final body = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
        expect(body['description'], '<p>rebased</p>');
        if (hasV2) {
          expect(body, {'description': '<p>rebased</p>'});
        } else {
          expect(body['identifier'], 'STU');
        }
        expect(project.description, '<p>rebased</p>');
      });

      test('${hasV2 ? 'v2' : 'v1'} a rebase that throws writes '
          'nothing', () async {
        final dio = fakeDio({'$root/projects/7': json(_project('<p>web</p>'))});

        await expectLater(
          _client(dio, hasV2: hasV2).projects.update(
            7,
            _projectEdit,
            rebaseDescription: (_) => throw const DescriptionConflict(),
          ),
          throwsA(isA<DescriptionConflict>()),
        );
        expect(_calls(dio), ['GET $root/projects/7']);
      });
    }

    test('without a description the rebase is not asked', () async {
      final dio = fakeDio({'$_v2/projects/7': json(_project('<p>web</p>'))});

      await _client(dio, hasV2: true).projects.update(
        7,
        const ProjectChanges(title: 'Studio'),
        rebaseDescription: (_) => fail('asked without a description'),
      );

      expect(_calls(dio), ['PATCH $_v2/projects/7']);
    });
  });
}
