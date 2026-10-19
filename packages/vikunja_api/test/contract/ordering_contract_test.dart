@Tags(['contract'])
@Timeout(Duration(minutes: 4))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Per API version, the tasks A, B, C and D are created in that order in one
// project, each new one on top of every view (65536, then half the lowest),
// and D is marked done, which hides it from the list view (its filter is
// `done = false`). And a project tree: Top with the children First and
// Second (a favourite with colour, identifier and description) and First's
// child Deep, the top-level Other (the same extras) and the archived Attic;
// a new project's position is its id × 65536. The tests run in order and
// build on each other. No position below 0.1 is ever sent: the server would
// renumber every sibling, at the top level those of every user.
typedef _Tasks = ({
  int projectId,
  int listViewId,
  int tableViewId,
  int a,
  int b,
  int c,
  int d,
});

typedef _Tree = ({
  int top,
  int first,
  int second,
  int deep,
  int other,
  int attic,
});

const _pace = Duration(milliseconds: 500);
const _mergePatch = 'application/merge-patch+json';

void main() {
  group('manual ordering on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;
        final identifierSuffix = Random.secure()
            .nextInt(1 << 24)
            .toRadixString(16)
            .toUpperCase();

        Uri at(String path) {
          final base = connection.apiBaseUri(ApiVersion.v2);
          return base.replace(path: '${base.path}$path');
        }

        Future<Map<String, Object?>> send(
          String method,
          String path, {
          Map<String, Object?>? body,
          String? contentType,
        }) async {
          try {
            final response = await despiteWriteRaces(
              () => dio.requestUri<Map<String, Object?>>(
                at(path),
                data: body,
                options: Options(
                  method: method,
                  contentType: contentType,
                  headers: {'Authorization': 'Bearer ${user.jwt}'},
                ),
              ),
            );
            if (method != 'GET') await Future<void>.delayed(_pace);
            return response.data ?? const {};
          } on DioException catch (error) {
            throw StateError(
              '$method $path failed with ${error.response?.statusCode}: '
              '${error.response?.data}',
            );
          }
        }

        Future<int> create(String path, Map<String, Object?> body) async =>
            (await send('POST', path, body: body))['id']! as int;

        Future<void> patch(String path, Map<String, Object?> body) =>
            send('PATCH', path, body: body, contentType: _mergePatch);

        Dio authorized(ServerConnection only) => createAuthenticatedDio(
          base: dio,
          connection: only,
          tokens: StaticJwt(user.jwt),
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
            late _Tasks tasks;
            late _Tree tree;

            ServerConnection only() => onlyVersion(connection, apiVersion);

            VikunjaReadClient reads() =>
                createReadClient(dio: authorized(only()), connection: only());

            VikunjaWriteClient writes() =>
                createWriteClient(dio: authorized(only()), connection: only());

            Future<T> paced<T>(Future<T> Function() write) async {
              final result = await write();
              await Future<void>.delayed(_pace);
              return result;
            }

            Future<Task> place(int taskId, int viewId, double position) =>
                paced(
                  () => RetryingTasksWrites(
                    writes().tasks,
                  ).update(taskId, TaskChanges(positions: {viewId: position})),
                );

            Future<List<Task>> inView(int viewId) async => (await patiently(
              () => reads().tasks.listInView(
                tasks.projectId,
                viewId,
                const TaskQuery(sort: [TaskSort(TaskSortField.position)]),
              ),
            )).items;

            Future<Project> move(
              int projectId, {
              required double position,
              required int parent,
            }) => paced(
              () => RetryingProjectsWrites(writes().projects)
                  .move(projectId, position: position, parentProjectId: parent),
            );

            Future<Project> project(int id) =>
                patiently(() => reads().projects.read(id));

            Future<List<int>> childrenOf(int parent) async => [
              for (final project in await patiently(
                () => reads().projects.listAll(includeArchived: true),
              ))
                if (project.parentProjectId == parent) project.id,
            ];

            void expectKept(Project moved, Project before) {
              expect(moved.title, before.title);
              expect(moved.description, before.description);
              expect(moved.identifier, before.identifier);
              expect(moved.hexColor, before.hexColor);
              expect(moved.isFavorite, before.isFavorite);
              expect(moved.isArchived, before.isArchived);
            }

            setUpAll(() async {
              final segment = apiVersion.pathSegment;
              final projectId = await create('/projects', {
                'title': 'Ordering contract $segment',
              });
              final views = (await project(projectId)).views;
              int viewOf(ProjectViewKind kind) =>
                  views.firstWhere((view) => view.kind == kind).id;
              final a = await create('/projects/$projectId/tasks', {
                'title': 'A',
              });
              final b = await create('/projects/$projectId/tasks', {
                'title': 'B',
              });
              final c = await create('/projects/$projectId/tasks', {
                'title': 'C',
              });
              final d = await create('/projects/$projectId/tasks', {
                'title': 'D',
              });
              await patch('/tasks/$d', {'done': true});
              tasks = (
                projectId: projectId,
                listViewId: viewOf(ProjectViewKind.list),
                tableViewId: viewOf(ProjectViewKind.table),
                a: a,
                b: b,
                c: c,
                d: d,
              );

              Future<int> favourite(
                String title,
                String identifier, {
                int parent = 0,
              }) async {
                final id = await create('/projects', {
                  'title': title,
                  'parent_project_id': parent,
                  'hex_color': '4a90e2',
                  'identifier': '$identifier$segment$identifierSuffix',
                  'description': '<p>$title stays</p>',
                });
                await patch('/projects/$id', {'is_favorite': true});
                return id;
              }

              final top = await create('/projects', {'title': 'Top $segment'});
              final first = await create('/projects', {
                'title': 'First',
                'parent_project_id': top,
              });
              final second = await favourite('Second', 'S', parent: top);
              final deep = await create('/projects', {
                'title': 'Deep',
                'parent_project_id': first,
              });
              final other = await favourite('Other $segment', 'O');
              final attic = await create('/projects', {
                'title': 'Attic $segment',
              });
              await patch('/projects/$attic', {'is_archived': true});
              tree = (
                top: top,
                first: first,
                second: second,
                deep: deep,
                other: other,
                attic: attic,
              );
            });

            test('list positions order the list view and leave the task and '
                'the other views as they are', () async {
              final before = await patiently(() => reads().tasks.read(tasks.a));

              await place(tasks.c, tasks.listViewId, 1000);
              final placed = await place(tasks.a, tasks.listViewId, 2000);
              await place(tasks.b, tasks.listViewId, 3000.5);

              final list = await inView(tasks.listViewId);
              expect(
                [for (final task in list) task.id],
                [tasks.c, tasks.a, tasks.b],
              );
              expect(
                [for (final task in list) task.position],
                [1000, 2000, 3000.5],
              );
              expect(placed.id, tasks.a);
              expect(placed.updated, before.updated);
              expect(
                [for (final task in await inView(tasks.tableViewId)) task.id],
                [tasks.d, tasks.c, tasks.b, tasks.a],
              );
            });

            test('a hidden done task takes a position and keeps it when it '
                'reopens', () async {
              await place(tasks.d, tasks.listViewId, 2500);
              expect(
                [for (final task in await inView(tasks.listViewId)) task.id],
                [tasks.c, tasks.a, tasks.b],
              );

              await paced(
                () =>
                    RetryingTasksWrites(writes().tasks)
                        .update(tasks.d, const TaskChanges(done: false)),
              );

              final list = await inView(tasks.listViewId);
              expect(
                [for (final task in list) task.id],
                [tasks.c, tasks.a, tasks.d, tasks.b],
              );
              expect(list[2].position, 2500);
            });

            test('a view that does not exist is NotFound 3014', () async {
              await expectLater(
                writes().tasks.update(
                  tasks.a,
                  const TaskChanges(positions: {999999999: 5}),
                ),
                throwsA(isA<NotFound>().having((f) => f.code, 'code', 3014)),
              );
            });

            test(
              'a reorder among siblings changes only the position',
              () async {
                final first = await project(tree.first);
                final before = await project(tree.second);
                expect(await childrenOf(tree.top), [tree.first, tree.second]);

                final moved = await move(
                  tree.second,
                  position: first.position / 2,
                  parent: tree.top,
                );

                expect(moved.position, first.position / 2);
                expect(moved.parentProjectId, tree.top);
                expectKept(moved, before);
                final stored = await project(tree.second);
                expect(stored.position, first.position / 2);
                expect(stored.parentProjectId, tree.top);
                expectKept(stored, before);
                expect(await childrenOf(tree.top), [tree.second, tree.first]);
              },
            );

            test('a nest under another project and back to the top level '
                'keep every other field', () async {
              final deep = await project(tree.deep);
              final before = await project(tree.other);

              await move(
                tree.other,
                position: deep.position + 65536,
                parent: tree.first,
              );

              final nested = await project(tree.other);
              expect(nested.parentProjectId, tree.first);
              expect(nested.position, deep.position + 65536);
              expectKept(nested, before);
              expect(await childrenOf(tree.first), [tree.deep, tree.other]);

              await move(tree.other, position: before.position, parent: 0);

              final unnested = await project(tree.other);
              expect(unnested.parentProjectId, 0);
              expect(unnested.position, before.position);
              expectKept(unnested, before);
              expect(await childrenOf(tree.first), [tree.deep]);
            });

            test('a project moves with its subtree', () async {
              await move(tree.first, position: 65536, parent: tree.second);

              expect((await project(tree.first)).parentProjectId, tree.second);
              expect((await project(tree.deep)).parentProjectId, tree.first);
              expect(await childrenOf(tree.second), [tree.first]);
            });

            test('a cycle is refused and changes nothing', () async {
              final before = await project(tree.top);

              await expectLater(
                writes().projects.move(
                  tree.top,
                  position: before.position,
                  parentProjectId: tree.deep,
                ),
                throwsA(isA<DomainError>().having((f) => f.code, 'code', 3011)),
              );
              await expectLater(
                writes().projects.move(
                  tree.top,
                  position: before.position,
                  parentProjectId: tree.top,
                ),
                throwsA(isA<DomainError>().having((f) => f.code, 'code', 3010)),
              );

              final after = await project(tree.top);
              expect(after.parentProjectId, 0);
              expect(after.position, before.position);
            });

            test('an archived parent is refused and changes nothing', () async {
              final before = await project(tree.second);

              await expectLater(
                writes().projects.move(
                  tree.second,
                  position: 65536,
                  parentProjectId: tree.attic,
                ),
                throwsA(isA<DomainError>().having((f) => f.code, 'code', 3008)),
              );

              final after = await project(tree.second);
              expect(after.parentProjectId, tree.top);
              expect(after.position, before.position);
              expectKept(after, before);
            });
          });
        }
      });
    }
  });
}
