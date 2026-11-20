import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

const _v240 = ServerVersion(2, 4, 0);

VikunjaWriteClient _client(
  Dio dio, {
  ServerVersion? version = _v240,
  bool hasV2 = true,
}) => createWriteClient(
  dio: dio,
  connection: version == null
      ? _withoutVersion(hasV2: hasV2)
      : testConnection(hasV2: hasV2, version: version),
);

ServerConnection _withoutVersion({required bool hasV2}) {
  const info = ServerInfo(version: null);
  final apiVersions = {ApiVersion.v1, if (hasV2) ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse(testServerRoot),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

const Map<String, Object?> _subscription = {
  'id': 1,
  'entity': 'task',
  'entity_id': 42,
  'created': '2026-11-20T17:52:41Z',
};

/// The task the user follows, as 2.4.0 answers it.
final Map<String, Object?> _followedTask = taskJson(
  42,
  overrides: {'subscription': _subscription},
);

/// The project the user follows, as 2.4.0 answers it.
const Map<String, Object?> _followedProject = {
  'id': 7,
  'title': 'Project 7',
  'parent_project_id': 0,
  'position': 65536,
  'subscription': {
    'id': 3,
    'entity': 'project',
    'entity_id': 7,
    'created': '2026-11-20T17:52:41Z',
  },
};

/// 2.4.0 over v2: it merges a patch into the object as it answers it and
/// refuses the merged subscription unless the patch removes it.
FakeRoute _patchLike240(Map<String, Object?> stored) => (request) {
  if (request.method != 'PATCH') return json(stored)(request);
  final patch = request.data as Map<String, Object?>;
  if (patch.containsKey('subscription') && patch['subscription'] == null) {
    return json({...stored, ...patch, 'subscription': stored['subscription']})(
      request,
    );
  }
  return json({
    'title': 'Unprocessable Entity',
    'status': 422,
    'detail': 'validation failed',
    'errors': [
      {
        'message': 'expected integer',
        'location': 'body.subscription.entity',
        'value': stored['subscription'] is Map ? 'task' : null,
      },
    ],
  }, status: 422)(request);
};

List<Object?> _patches(Dio dio) => [
  for (final (index, request) in adapterOf(dio).requests.indexed)
    if (request.method == 'PATCH') adapterOf(dio).decodedBodies[index],
];

void main() {
  group('2.4.0 over v2: a followed task', () {
    const monday = '2026-11-23T09:00:00.000Z';
    final changes = <(String, TaskChanges, Map<String, Object?>)>[
      ('done', const TaskChanges(done: true), {'done': true}),
      ('title', const TaskChanges(title: 'Milk'), {'title': 'Milk'}),
      (
        'description',
        const TaskChanges(description: '<p>Oat</p>'),
        {'description': '<p>Oat</p>'},
      ),
      (
        'due date',
        TaskChanges(dueDate: DateChange.set(DateTime.parse(monday))),
        {'due_date': monday},
      ),
      (
        'start and end dates',
        TaskChanges(
          startDate: DateChange.set(DateTime.parse(monday)),
          endDate: const DateChange.clear(),
        ),
        {'start_date': monday, 'end_date': zeroDateJson},
      ),
      ('priority', const TaskChanges(priority: 4), {'priority': 4}),
      (
        'percent done',
        const TaskChanges(percentDone: 0.5),
        {'percent_done': 0.5},
      ),
      (
        'colour',
        const TaskChanges(hexColor: '4caf50'),
        {'hex_color': '4caf50'},
      ),
      ('favourite', const TaskChanges(isFavorite: true), {'is_favorite': true}),
      (
        'repeat',
        const TaskChanges(
          repeatAfter: Duration(days: 7),
          repeatMode: RepeatMode.afterAmount,
        ),
        {'repeat_after': 604800, 'repeat_mode': 0},
      ),
      (
        'reminders',
        TaskChanges(
          reminders: [TaskReminder(reminder: DateTime.parse(monday))],
        ),
        {
          'reminders': [
            {'reminder': monday, 'relative_period': 0, 'relative_to': ''},
          ],
        },
      ),
      ('project', const TaskChanges(projectId: 8), {'project_id': 8}),
      (
        'cover image',
        const TaskChanges(coverImageAttachmentId: 5),
        {'cover_image_attachment_id': 5},
      ),
    ];

    for (final (name, change, body) in changes) {
      test(
        '$name: the patch removes the subscription from the merge',
        () async {
          final dio = fakeDio({'$_v2/tasks/42': _patchLike240(_followedTask)});

          await _client(dio).tasks.update(42, change);

          expect(_patches(dio), [
            {...body, 'subscription': null},
          ]);
        },
      );
    }

    test('a rebased description is patched the same way', () async {
      final dio = fakeDio({'$_v2/tasks/42': _patchLike240(_followedTask)});

      await _client(dio).tasks.update(
        42,
        const TaskChanges(description: '<p>Oat</p>'),
        rebaseDescription: (current) => '$current<p>Oat</p>',
      );

      expect(_patches(dio), [
        {'description': '<p>Oat</p>', 'subscription': null},
      ]);
    });

    test('labels and assignees still go through their own endpoints, '
        'without a patch', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': _patchLike240(_followedTask),
        '$_v2/tasks/42/labels': json({'label_id': 4}, status: 201),
        '$_v2/tasks/42/assignees': json({'user_id': 13}, status: 201),
      });

      await _client(dio).tasks.update(
        42,
        const TaskChanges(
          labels: IdSetChange(added: {4}),
          assignees: IdSetChange(added: {13}),
        ),
      );

      expect(_patches(dio), isEmpty);
      expect(adapterOf(dio).decodedBodies.whereType<Map<String, Object?>>(), [
        {'label_id': 4},
        {'user_id': 13},
      ]);
    });

    test('a build after the 2.4.0 tag counts as 2.4', () async {
      final dio = fakeDio({'$_v2/tasks/42': _patchLike240(_followedTask)});

      await _client(
        dio,
        version: ServerVersion.tryParse('v2.4.0-12-g0123abc'),
      ).tasks.update(42, const TaskChanges(done: true));

      expect(_patches(dio), [
        {'done': true, 'subscription': null},
      ]);
    });
  });

  group('2.4.0 over v2: a followed project', () {
    test('an update removes the subscription from the merge', () async {
      final dio = fakeDio({'$_v2/projects/7': _patchLike240(_followedProject)});

      await _client(dio).projects
          .update(7, const ProjectChanges(title: 'Studio'));

      expect(_patches(dio), [
        {'title': 'Studio', 'subscription': null},
      ]);
    });

    test('an update with a rebased description too', () async {
      final dio = fakeDio({'$_v2/projects/7': _patchLike240(_followedProject)});

      await _client(dio).projects.update(
        7,
        const ProjectChanges(description: 'Mine'),
        rebaseDescription: (current) => '${current}Mine',
      );

      expect(_patches(dio), [
        {'description': 'Mine', 'subscription': null},
      ]);
    });

    test('a move too', () async {
      final dio = fakeDio({'$_v2/projects/7': _patchLike240(_followedProject)});

      await _client(dio).projects.move(7, position: 1024, parentProjectId: 3);

      expect(_patches(dio), [
        {'position': 1024.0, 'parent_project_id': 3, 'subscription': null},
      ]);
    });
  });

  group('2.4.0 over v2: what nobody follows is patched as before', () {
    test('a view', () async {
      final dio = fakeDio({
        '$_v2/projects/7/views/70': json({
          'id': 70,
          'project_id': 7,
          'title': 'List',
          'view_kind': 'list',
          'position': 100,
        }),
      });

      await _client(dio).views.move(7, 70, position: 200);

      expect(_patches(dio), [
        {'position': 200.0},
      ]);
    });

    test('a saved filter', () async {
      final dio = fakeDio({
        '$_v2/filters/3': json({
          'id': 3,
          'title': 'Soon',
          'filters': {'filter': 'done = false'},
        }),
      });

      await _client(dio).savedFilters.setFavorite(3, favorite: true);

      expect(_patches(dio), [
        {'is_favorite': true},
      ]);
    });
  });

  group('elsewhere the patch carries only the changes', () {
    for (final (name, version) in <(String, ServerVersion?)>[
      ('2.5.0', const ServerVersion(2, 5, 0)),
      ('2.6.0', const ServerVersion(2, 6, 0)),
      ('2.7.1', const ServerVersion(2, 7, 1)),
      ('2.8.0', const ServerVersion(2, 8, 0)),
      ('a development build', ServerVersion.tryParse('dev')),
      ('an unknown version', null),
    ]) {
      test('$name: tasks and projects', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_followedTask),
          '$_v2/projects/7': json(_followedProject),
        });
        final client = _client(dio, version: version);

        await client.tasks.update(42, const TaskChanges(done: true));
        await client.projects.update(7, const ProjectChanges(title: 'Studio'));
        await client.projects.move(7, position: 1024, parentProjectId: 0);

        expect(_patches(dio), [
          {'done': true},
          {'title': 'Studio'},
          {'position': 1024.0, 'parent_project_id': 0},
        ]);
      });
    }
  });

  test('2.4.0 with /api/v2 hidden replaces over v1 without the subscription, '
      'as before', () async {
    final dio = fakeDio({
      '$_v1/tasks/42': (request) =>
          json(request.method == 'GET' ? _followedTask : request.data)(request),
    });

    await _client(
      dio,
      hasV2: false,
    ).tasks.update(42, const TaskChanges(done: true));

    final posted = adapterOf(dio).decodedBodies[1]! as Map<String, Object?>;
    expect(adapterOf(dio).requests[1].method, 'POST');
    expect(posted, isNot(contains('subscription')));
    expect(posted['done'], isTrue);
  });
}
