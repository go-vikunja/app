@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Per API version, a task and a project take the HTML the description editor
// writes and give it back byte for byte; an update with a description rebase
// sees what the server has right before the write. One user for the whole
// file.
const _pace = Duration(milliseconds: 500);

final String _editorHtml = [
  '<h1>Plan \u{1F600} &amp; more</h1>',
  '<p>Line one<br>line two\r\nafter CR LF</p>',
  '<ul data-type="taskList">',
  '<li data-checked="false" data-type="taskItem" data-task-id="abcd1234">',
  '<label><input type="checkbox"><span></span></label>',
  '<div><p>Milk</p></div></li>',
  '<li data-checked="true" data-type="taskItem" data-task-id="efgh5678">',
  '<label><input type="checkbox" checked="checked"><span></span></label>',
  '<div><p>Eggs</p></div></li></ul>',
  '<p>hi <mention-user data-id="jdoe" data-label="Jane Doe" ',
  'data-mention-suggestion-char="@"></mention-user> see ',
  '<a target="_blank" rel="noopener noreferrer nofollow" ',
  'href="http://localhost:34527/tasks/1">http://localhost:34527/tasks/1</a>',
  '</p>',
  '<table style="min-width: 25px"><colgroup><col style="min-width: 25px">',
  '</colgroup><tbody><tr><td colspan="1" rowspan="1" ',
  'style="background-color: rgb(255, 0, 0)"><p>cell</p></td></tr></tbody>',
  '</table>',
  '<p><img src="#" data-src="/api/v1/tasks/1/attachments/2" ',
  'id="tiptap-image-1-2" alt="pic"></p>',
  '<blockquote data-comment-id="5"><p>quoted</p></blockquote>',
  '<pre><code class="language-js">a &lt; b</code></pre><p></p>',
].join();

void main() {
  group('descriptions on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;

        Future<Map<String, Object?>> send(
          String method,
          String path,
          Map<String, Object?> body, {
          String? contentType,
        }) async {
          final v2 = connection.apiBaseUri(ApiVersion.v2);
          try {
            final response = await despiteWriteRaces(
              () => dio.requestUri<Map<String, Object?>>(
                v2.replace(path: '${v2.path}$path'),
                data: body,
                options: Options(
                  method: method,
                  contentType: contentType,
                  headers: {'Authorization': 'Bearer ${user.jwt}'},
                ),
              ),
            );
            await Future<void>.delayed(_pace);
            return response.data!;
          } on DioException catch (error) {
            throw StateError(
              '$method $path failed with ${error.response?.statusCode}: '
              '${error.response?.data}',
            );
          }
        }

        Future<Map<String, Object?>> post(
          String path,
          Map<String, Object?> body,
        ) => send('POST', path, body);

        /// A change made on the web meanwhile.
        Future<void> changeOnTheWeb(int taskId, String description) => send(
          'PATCH',
          '/tasks/$taskId',
          {'description': description},
          contentType: 'application/merge-patch+json',
        );

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            late VikunjaReadClient reads;
            late VikunjaWriteClient writes;
            late TasksWritePort tasks;
            late int projectId;

            Future<T> paced<T>(Future<T> Function() write) async {
              final result = await despiteWriteRaces(write);
              await Future<void>.delayed(_pace);
              return result;
            }

            Future<int> newTask(String description) async =>
                (await post('/projects/$projectId/tasks', {
                      'title': 'Described',
                      'description': description,
                    }))['id']!
                    as int;

            setUpAll(() async {
              final only = onlyVersion(connection, apiVersion);
              final authenticated = createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(user.jwt),
              );
              reads = createReadClient(dio: authenticated, connection: only);
              writes = createWriteClient(dio: authenticated, connection: only);
              tasks = RetryingTasksWrites(writes.tasks);
              projectId =
                  (await post('/projects', {
                        'title': 'Descriptions ${apiVersion.pathSegment}',
                      }))['id']!
                      as int;
            });

            test('the editor HTML round-trips byte for byte', () async {
              final id = await newTask('');

              final answered = await paced(
                () => tasks.update(
                  id,
                  TaskChanges(description: _editorHtml, descriptionBase: ''),
                ),
              );

              expect(answered.description, _editorHtml);
              expect(
                (await patiently(() => reads.tasks.read(id))).description,
                _editorHtml,
              );
            });

            test('an emptied description is stored as written', () async {
              final id = await newTask('<p>Something</p>');

              await paced(
                () =>
                    tasks.update(id, const TaskChanges(description: '<p></p>')),
              );

              expect(
                (await patiently(() => reads.tasks.read(id))).description,
                '<p></p>',
              );
            });

            test('a rebase sees the description the server has right before '
                'the write and stores what it returns', () async {
              final id = await newTask('<p>Start</p>');
              await changeOnTheWeb(id, '<p>Web</p>');
              final seen = <String>[];

              final answered = await paced(
                () => tasks.update(
                  id,
                  const TaskChanges(
                    description: '<p>Mine</p>',
                    descriptionBase: '<p>Start</p>',
                    priority: 2,
                  ),
                  rebaseDescription: (current) {
                    seen.add(current);
                    return '$current<p>Mine</p>';
                  },
                ),
              );

              expect(seen.last, '<p>Web</p>');
              expect(answered.description, '<p>Web</p><p>Mine</p>');
              final stored = await patiently(() => reads.tasks.read(id));
              expect(stored.description, '<p>Web</p><p>Mine</p>');
              expect(stored.priority, TaskPriority.medium);
            });

            test('a rebase that throws writes nothing', () async {
              final id = await newTask('<p>Start</p>');
              await changeOnTheWeb(id, '<p>Web</p>');

              await expectLater(
                tasks.update(
                  id,
                  const TaskChanges(
                    description: '<p>Mine</p>',
                    descriptionBase: '<p>Start</p>',
                    done: true,
                  ),
                  rebaseDescription: (_) => throw const DescriptionConflict(),
                ),
                throwsA(isA<DescriptionConflict>()),
              );

              final stored = await patiently(() => reads.tasks.read(id));
              expect(stored.description, '<p>Web</p>');
              expect(stored.done, isFalse);
            });

            test('a project description round-trips byte for byte, the '
                'other fields kept', () async {
              final projects = RetryingProjectsWrites(writes.projects);
              final before = await patiently(
                () => reads.projects.read(projectId),
              );

              final answered = await paced(
                () => projects.update(
                  projectId,
                  ProjectChanges(description: _editorHtml),
                ),
              );

              expect(answered.description, _editorHtml);
              final stored = await patiently(
                () => reads.projects.read(projectId),
              );
              expect(stored.description, _editorHtml);
              expect(stored.title, before.title);
              expect(stored.position, before.position);
            });

            test('a project description rebase sees what the server has '
                'right before the write; one that throws writes '
                'nothing', () async {
              final projects = RetryingProjectsWrites(writes.projects);
              await send('PATCH', '/projects/$projectId', {
                'description': '<p>Web</p>',
              }, contentType: 'application/merge-patch+json');
              final before = await patiently(
                () => reads.projects.read(projectId),
              );
              final seen = <String>[];

              await expectLater(
                projects.update(
                  projectId,
                  const ProjectChanges(description: '<p>Mine</p>'),
                  rebaseDescription: (current) {
                    seen.add(current);
                    throw const DescriptionConflict();
                  },
                ),
                throwsA(isA<DescriptionConflict>()),
              );
              expect(seen.last, '<p>Web</p>');
              expect(
                (await patiently(() => reads.projects.read(projectId)))
                    .description,
                '<p>Web</p>',
              );

              final answered = await paced(
                () => projects.update(
                  projectId,
                  const ProjectChanges(description: '<p>Mine</p>'),
                  rebaseDescription: (current) => '$current<p>Mine</p>',
                ),
              );

              expect(answered.description, '<p>Web</p><p>Mine</p>');
              final stored = await patiently(
                () => reads.projects.read(projectId),
              );
              expect(stored.description, '<p>Web</p><p>Mine</p>');
              expect(stored.title, before.title);
              expect(stored.identifier, before.identifier);
            });
          });
        }
      });
    }
  });
}
