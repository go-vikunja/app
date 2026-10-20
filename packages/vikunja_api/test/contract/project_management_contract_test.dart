@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Per API version, the ports create Studio (a colour) with the child
// Sketches (a colour, a description set beside the ports) and its child
// Deep, edit, favourite, archive, duplicate and delete them; and they manage
// the views of a second project down to none, which the server allows. A
// link share with write permission stands in for a second user: it may not
// write views or delete the project. The tests run in order and build on
// each other.
const _pace = Duration(milliseconds: 500);

void main() {
  group('project management on local Docker servers', skip: contractSkip, () {
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
          final base = connection.apiBaseUri(ApiVersion.v1);
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

        Future<String> linkShareJwt(int projectId) async {
          final share = await send(
            'PUT',
            '/projects/$projectId/shares',
            body: {'right': 1},
          );
          final auth = await patiently(
            () => dio.postUri<Map<String, Object?>>(
              at('/shares/${share['hash']}/auth'),
              data: const <String, Object?>{},
            ),
          );
          return auth.data!['token']! as String;
        }

        Dio authorized(ServerConnection only, {String? jwt}) =>
            createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(jwt ?? user.jwt),
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
            final segment = apiVersion.pathSegment;
            late int studio;
            late int sketches;
            late int deep;
            late int primeTask;
            late int viewsProject;
            late ProjectView openView;
            late ProjectView boardView;

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

            ProjectsWritePort projects() =>
                RetryingProjectsWrites(writes().projects);

            ProjectViewsWritePort views() =>
                RetryingProjectViewsWrites(writes().views);

            Future<Project> create(NewProject project) =>
                paced(() => projects().create(project));

            Future<Project> update(int id, ProjectChanges changes) =>
                paced(() => projects().update(id, changes));

            Future<Project> read(int id) =>
                patiently(() => reads().projects.read(id));

            Future<Set<int>> allProjectIds() async => {
              for (final project in await patiently(
                () => reads().projects.listAll(includeArchived: true),
              ))
                project.id,
            };

            Future<List<ProjectView>> viewsOf(int projectId) async =>
                [...(await read(projectId)).views]
                  ..sort((a, b) => a.position.compareTo(b.position));

            void expectSame(Project actual, Project expected) {
              expect(actual.title, expected.title);
              expect(actual.description, expected.description);
              expect(actual.identifier, expected.identifier);
              expect(actual.hexColor, expected.hexColor);
              expect(actual.parentProjectId, expected.parentProjectId);
              expect(actual.position, expected.position);
              expect(actual.isFavorite, expected.isFavorite);
              expect(actual.isArchived, expected.isArchived);
            }

            test('a project is created at the top level with a colour, its '
                'children under it', () async {
              final created = await create(
                NewProject(title: 'Studio $segment', hexColor: 'e8b04a'),
              );
              studio = created.id;

              expect(created.title, 'Studio $segment');
              expect(created.hexColor, 'e8b04a');
              expect(created.parentProjectId, 0);
              expect(created.identifier, '');
              expect(created.position, studio * 65536);
              final defaults = [...created.views]
                ..sort((a, b) => a.position.compareTo(b.position));
              expect([
                for (final view in defaults) view.kind,
              ], ProjectViewKind.values);
              expect(defaults.first.filter?.filter, 'done = false');
              expect(
                defaults.last.bucketConfigurationMode,
                BucketConfigurationMode.manual,
              );

              final child = await create(
                NewProject(
                  title: 'Sketches',
                  parentProjectId: studio,
                  hexColor: '#4a90e2',
                ),
              );
              sketches = child.id;
              expect(child.parentProjectId, studio);
              expect(child.hexColor, '4a90e2');
              deep = (await create(
                NewProject(title: 'Deep', parentProjectId: sketches),
              )).id;

              final stored = await read(sketches);
              expect(stored.parentProjectId, studio);
              expect(stored.hexColor, '4a90e2');
              expect((await read(deep)).parentProjectId, sketches);
            });

            test(
              'each field changes alone and every other one stays',
              () async {
                await send(
                  'POST',
                  '/projects/$sketches',
                  body: {
                    ...await send('GET', '/projects/$sketches'),
                    'description': '<p>Keep me</p>',
                  },
                );
                var expected = await read(sketches);
                expect(expected.description, '<p>Keep me</p>');

                Future<void> change(
                  ProjectChanges changes,
                  Project Function(Project before) apply,
                ) async {
                  final answer = await update(sketches, changes);
                  expected = apply(expected);
                  expectSame(answer, expected);
                  expectSame(await read(sketches), expected);
                }

                final identifier = 'p$segment$identifierSuffix';
                await change(
                  ProjectChanges(identifier: identifier),
                  (p) => _with(p, identifier: identifier.toUpperCase()),
                );
                await change(
                  const ProjectChanges(title: 'Drafts'),
                  (p) => _with(p, title: 'Drafts'),
                );
                await change(
                  const ProjectChanges(hexColor: '#ff851b'),
                  (p) => _with(p, hexColor: 'ff851b'),
                );
                await change(
                  const ProjectChanges(hexColor: ''),
                  (p) => _with(p, hexColor: ''),
                );
                await change(
                  const ProjectChanges(identifier: ''),
                  (p) => _with(p, identifier: ''),
                );
              },
            );

            test('a parent change keeps the position', () async {
              final before = await read(sketches);

              final moved = await update(
                sketches,
                const ProjectChanges(parentProjectId: 0),
              );

              expect(moved.parentProjectId, 0);
              expect(moved.position, before.position);
              await update(sketches, ProjectChanges(parentProjectId: studio));
              expectSame(await read(sketches), before);
              expect((await read(deep)).parentProjectId, sketches);
            });

            test('an identifier any project uses is refused with 3007 and '
                'changes nothing', () async {
              final taken = 'q$segment$identifierSuffix';
              await update(studio, ProjectChanges(identifier: taken));
              final before = await read(sketches);

              await expectLater(
                writes().projects.update(
                  sketches,
                  ProjectChanges(identifier: taken.toLowerCase()),
                ),
                throwsA(
                  isA<DomainError>()
                      .having((f) => f.statusCode, 'status', 400)
                      .having((f) => f.code, 'code', 3007),
                ),
              );

              expectSame(await read(sketches), before);
              expect((await read(studio)).identifier, taken.toUpperCase());
            });

            test('a favourite stays through other edits', () async {
              final before = await read(studio);

              final favourite = await update(
                studio,
                const ProjectChanges(isFavorite: true),
              );
              expectSame(favourite, _with(before, isFavorite: true));
              final renamed = await update(
                studio,
                ProjectChanges(title: 'Studio $segment renamed'),
              );
              expect(renamed.isFavorite, isTrue);
              expect((await read(studio)).isFavorite, isTrue);

              await update(
                studio,
                ProjectChanges(title: before.title, isFavorite: false),
              );
              expectSame(await read(studio), before);
            });

            test('archiving cascades, a child under an archived parent cannot '
                'be unarchived (3016), an archived project cannot be edited '
                '(3008), unarchiving restores the subtree', () async {
              final archived = await update(
                studio,
                const ProjectChanges(isArchived: true),
              );

              expect(archived.isArchived, isTrue);
              expect((await read(sketches)).isArchived, isTrue);
              expect((await read(deep)).isArchived, isTrue);
              await expectLater(
                writes().projects.update(
                  sketches,
                  const ProjectChanges(isArchived: false),
                ),
                throwsA(isA<DomainError>().having((f) => f.code, 'code', 3016)),
              );
              await expectLater(
                writes().projects.update(
                  studio,
                  const ProjectChanges(title: 'Atelier'),
                ),
                throwsA(isA<DomainError>().having((f) => f.code, 'code', 3008)),
              );

              await update(studio, const ProjectChanges(isArchived: false));

              for (final id in [studio, sketches, deep]) {
                expect((await read(id)).isArchived, isFalse, reason: '$id');
              }
              expect((await read(studio)).title, 'Studio $segment');
            });

            test('the default project cannot be archived (3013)', () async {
              final defaultProjectId = (await patiently(
                () => AccountApi(
                  authorized(only()),
                  only(),
                ).currentUserWithSettings(),
              )).settings.defaultProjectId!;

              await expectLater(
                writes().projects.update(
                  defaultProjectId,
                  const ProjectChanges(isArchived: true),
                ),
                throwsA(
                  isA<DomainError>()
                      .having((f) => f.statusCode, 'status', 412)
                      .having((f) => f.code, 'code', 3013),
                ),
              );
              expect((await read(defaultProjectId)).isArchived, isFalse);
            });

            test('a duplicate copies the tasks and the views, not the '
                'children', () async {
              final tasks = RetryingTasksWrites(writes().tasks);
              primeTask = (await paced(
                () => tasks.create(
                  NewTask(projectId: studio, title: 'Prime the canvas'),
                ),
              )).id;
              final brushes = await paced(
                () => tasks.create(
                  NewTask(projectId: studio, title: 'Buy brushes'),
                ),
              );
              await paced(
                () => tasks.update(brushes.id, const TaskChanges(done: true)),
              );
              final source = await read(studio);

              final copy = await paced(
                () => projects().duplicate(
                  studio,
                  parentProjectId: 0,
                  copyShares: false,
                ),
              );

              expect(copy.title, 'Studio $segment - duplicate');
              expect(copy.identifier, '');
              expect(copy.parentProjectId, 0);
              expect(copy.hexColor, source.hexColor);
              expect(copy.position, source.position);
              expect(copy.isFavorite, isFalse);
              expect(
                {for (final view in copy.views) view.title},
                {for (final view in source.views) view.title},
              );
              final copiedTasks = (await patiently(
                () => reads().tasks.listInProject(copy.id, const TaskQuery()),
              )).items;
              expect(
                {for (final task in copiedTasks) task.title: task.done},
                {'Prime the canvas': false, 'Buy brushes': true},
              );
              final ids = await allProjectIds();
              expect(ids, contains(copy.id));
              final copyChildren = [
                for (final project in await patiently(
                  () => reads().projects.listAll(includeArchived: true),
                ))
                  if (project.parentProjectId == copy.id) project.id,
              ];
              expect(copyChildren, isEmpty);

              final nested = await paced(
                () => projects().duplicate(
                  studio,
                  parentProjectId: studio,
                  copyShares: true,
                ),
              );
              expect(nested.parentProjectId, studio);

              await paced(() => projects().delete(copy.id));
              expect(await allProjectIds(), isNot(contains(copy.id)));
            });

            test('a delete takes the whole subtree with its tasks; a repeat '
                'counts as deleted', () async {
              final subtree = {
                studio,
                sketches,
                deep,
                for (final project in await patiently(
                  () => reads().projects.listAll(includeArchived: true),
                ))
                  if (project.parentProjectId == studio) project.id,
              };
              expect(subtree, hasLength(4));

              await paced(() => projects().delete(studio));

              expect((await allProjectIds()).intersection(subtree), isEmpty);
              await expectLater(
                patiently(() => reads().tasks.read(primeTask)),
                throwsA(isA<NotFound>()),
              );
              await paced(() => projects().delete(studio));
            });

            test('a list view is created with a filter, a board without a '
                'mode gets the default buckets', () async {
              viewsProject = (await create(NewProject(title: 'Views $segment')))
                  .id;

              openView = await paced(
                () => views().create(
                  viewsProject,
                  const ViewDraft(
                    title: 'Open',
                    kind: ProjectViewKind.list,
                    filter: ViewFilter(filter: 'done = false'),
                  ),
                ),
              );
              boardView = await paced(
                () => views().create(
                  viewsProject,
                  const ViewDraft(
                    title: 'Board',
                    kind: ProjectViewKind.kanban,
                    position: 150,
                  ),
                ),
              );

              expect(openView.projectId, viewsProject);
              expect(openView.filter, const ViewFilter(filter: 'done = false'));
              expect(
                openView.bucketConfigurationMode,
                BucketConfigurationMode.none,
              );
              expect(openView.position, openView.id * 65536);
              expect(
                boardView.bucketConfigurationMode,
                BucketConfigurationMode.manual,
              );
              expect(boardView.position, 150);
              expect(boardView.defaultBucketId, isNot(0));
              expect(boardView.doneBucketId, isNot(0));
              final stored = {
                for (final view in await viewsOf(viewsProject)) view.id: view,
              };
              expect(stored[openView.id]?.filter?.filter, 'done = false');
              expect(stored[boardView.id]?.position, 150);
            });

            test('an update writes the draft and keeps the position', () async {
              final updated = await paced(
                () => views().update(
                  viewsProject,
                  openView.id,
                  const ViewDraft(
                    title: 'Urgent',
                    kind: ProjectViewKind.list,
                    filter: ViewFilter(filter: 'priority >= 3'),
                  ),
                ),
              );

              expect(updated.title, 'Urgent');
              expect(updated.filter?.filter, 'priority >= 3');
              expect(updated.position, openView.position);
              final stored = (await viewsOf(viewsProject))
                  .firstWhere((view) => view.id == openView.id);
              expect(stored.title, 'Urgent');
              expect(stored.filter?.filter, 'priority >= 3');
              openView = stored;
            });

            test('a move changes only the position, keeping a filter '
                'changed since the view was read', () async {
              await paced(
                () => views().update(
                  viewsProject,
                  openView.id,
                  const ViewDraft(
                    title: 'Urgent',
                    kind: ProjectViewKind.list,
                    filter: ViewFilter(filter: 'priority >= 4'),
                  ),
                ),
              );
              final first = (await viewsOf(viewsProject)).first;

              final moved = await paced(
                () => views().move(
                  viewsProject,
                  openView.id,
                  position: first.position / 2,
                ),
              );

              expect(moved.position, first.position / 2);
              final stored = await viewsOf(viewsProject);
              expect(stored.first.id, openView.id);
              expect(stored.first.title, 'Urgent');
              expect(stored.first.filter?.filter, 'priority >= 4');
              openView = stored.first;
            });

            test('a draft without a filter clears it', () async {
              final cleared = await paced(
                () => views().update(
                  viewsProject,
                  openView.id,
                  const ViewDraft(title: 'Urgent', kind: ProjectViewKind.list),
                ),
              );

              expect(cleared.filter, isNull);
              expect(cleared.position, openView.position);
            });

            test('a board turned into a list and back keeps its '
                'buckets', () async {
              final asList = await paced(
                () => views().update(
                  viewsProject,
                  boardView.id,
                  const ViewDraft(title: 'Board', kind: ProjectViewKind.list),
                ),
              );
              expect(asList.kind, ProjectViewKind.list);

              final again = await paced(
                () => views().update(
                  viewsProject,
                  boardView.id,
                  const ViewDraft(
                    title: 'Board',
                    kind: ProjectViewKind.kanban,
                    bucketConfigurationMode: BucketConfigurationMode.manual,
                  ),
                ),
              );

              expect(again.kind, ProjectViewKind.kanban);
              expect(again.defaultBucketId, boardView.defaultBucketId);
              expect(again.doneBucketId, boardView.doneBucketId);
              expect(again.position, 150);
            });

            test('invalid filters are refused with 4024, 4019 and 4016 and '
                'create nothing', () async {
              final before = (await viewsOf(viewsProject)).length;

              for (final (filter, code) in [
                ('((', 4024),
                ('priority >>= 1', 4019),
                ('foo = 1', 4016),
              ]) {
                await expectLater(
                  writes().views.create(
                    viewsProject,
                    ViewDraft(
                      title: 'Broken',
                      kind: ProjectViewKind.list,
                      filter: ViewFilter(filter: filter),
                    ),
                  ),
                  throwsA(
                    isA<DomainError>()
                        .having((f) => f.statusCode, 'status', 400)
                        .having((f) => f.code, 'code', code),
                  ),
                  reason: filter,
                );
              }

              expect(await viewsOf(viewsProject), hasLength(before));
            });

            test('a write share may not write views or delete the '
                'project', () async {
              final jwt = await linkShareJwt(viewsProject);
              final guest = createWriteClient(
                dio: authorized(only(), jwt: jwt),
                connection: only(),
              );

              await expectLater(
                guest.views.create(
                  viewsProject,
                  const ViewDraft(title: 'Mine', kind: ProjectViewKind.list),
                ),
                throwsA(isA<Forbidden>()),
              );
              await expectLater(
                guest.views.delete(viewsProject, openView.id),
                throwsA(isA<Forbidden>()),
              );
              await expectLater(
                guest.projects.delete(viewsProject),
                throwsA(isA<Forbidden>()),
              );
              expect(await allProjectIds(), contains(viewsProject));
            });

            test('a view is deleted; a repeat counts as deleted', () async {
              await paced(() => views().delete(viewsProject, openView.id));

              expect([
                for (final view in await viewsOf(viewsProject)) view.id,
              ], isNot(contains(openView.id)));
              await paced(() => views().delete(viewsProject, openView.id));
            });

            // The app refuses this itself; the server does not.
            test('the server deletes the last view of a project', () async {
              for (final view in await viewsOf(viewsProject)) {
                await paced(() => views().delete(viewsProject, view.id));
              }

              expect(await viewsOf(viewsProject), isEmpty);
              await paced(() => projects().delete(viewsProject));
            });
          });
        }
      });
    }
  });
}

Project _with(
  Project project, {
  String? title,
  String? identifier,
  String? hexColor,
  bool? isFavorite,
}) => Project(
  id: project.id,
  title: title ?? project.title,
  description: project.description,
  identifier: identifier ?? project.identifier,
  hexColor: hexColor ?? project.hexColor,
  parentProjectId: project.parentProjectId,
  isArchived: project.isArchived,
  isFavorite: isFavorite ?? project.isFavorite,
  position: project.position,
);
