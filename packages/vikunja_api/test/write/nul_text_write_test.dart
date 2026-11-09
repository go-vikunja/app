import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

VikunjaWriteClient _client(Dio dio, {bool hasV2 = true}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
);

// Vikunja 2.8.0 answers 400 to any JSON body with an escaped U+0000.
void main() {
  for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
    final version = hasV2 ? 'v2' : 'v1';

    test('$version create sends the text without U+0000', () async {
      final dio = fakeDio({
        '$base/projects/7/tasks': json(
          taskJson(43, overrides: {'title': 'Milk'}),
        ),
      });

      await _client(dio, hasV2: hasV2).tasks.create(
        const NewTask(
          projectId: 7,
          title: 'Mi\u0000lk',
          description: '<p>Oat\u0000</p>',
        ),
      );

      final adapter = adapterOf(dio);
      expect(adapter.requestBodies.single, isNot(contains(r'\u0000')));
      expect(adapter.decodedBodies.single, containsPair('title', 'Milk'));
      expect(
        adapter.decodedBodies.single,
        containsPair('description', '<p>Oat</p>'),
      );
    });
  }

  test('v2 update sends the changed text without U+0000', () async {
    final dio = fakeDio({'$_v2/tasks/42': json(taskJson(42))});

    await _client(dio).tasks
        .update(42, const TaskChanges(title: '\u0000Milk\u0000\u0000'));

    expect(adapterOf(dio).decodedBodies.single, {'title': 'Milk'});
  });

  test('a v1 replace also drops U+0000 from what the server sent, '
      'nested too', () async {
    final stored = taskJson(
      42,
      overrides: {
        'description': '<p>Old\u0000</p>',
        'assignees': [userJson(13, 'bo\u0000b')],
      },
    );
    final dio = fakeDio({
      '$_v1/tasks/42': sequence([json(stored), json(stored)]),
    });

    await _client(
      dio,
      hasV2: false,
    ).tasks.update(42, const TaskChanges(done: true));

    final adapter = adapterOf(dio);
    expect(adapter.requestBodies.last, isNot(contains(r'\u0000')));
    final body = adapter.decodedBodies.last! as Map<String, Object?>;
    expect(body['description'], '<p>Old</p>');
    expect(
      (body['assignees']! as List<Object?>).single,
      containsPair('username', 'bob'),
    );
    expect(body['done'], isTrue);
  });

  test('a comment is sent without U+0000', () async {
    final dio = fakeDio({
      '$_v2/tasks/21/comments': json({
        'id': 57,
        'comment': '<p>Hi</p>',
        'author': userJson(1, 'alice'),
        'created': '2026-10-10T12:00:00Z',
        'updated': '2026-10-10T12:00:00Z',
      }),
    });

    await _client(dio).comments.create(21, '<p>H\u0000i</p>');

    expect(adapterOf(dio).decodedBodies.single, {'comment': '<p>Hi</p>'});
  });

  test('a written backslash-u0000 is text and stays', () async {
    final dio = fakeDio({'$_v2/tasks/42': json(taskJson(42))});

    await _client(dio).tasks.update(42, const TaskChanges(title: r'a\u0000b'));

    expect(adapterOf(dio).decodedBodies.single, {'title': r'a\u0000b'});
  });
}
