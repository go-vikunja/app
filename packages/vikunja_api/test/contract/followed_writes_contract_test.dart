@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Every write the app sends to a task or project the user follows: directly,
// as an assignee, or through the project. Vikunja 2.4.0 refuses a v2
// merge-patch of anything followed (422 on `subscription.entity`) unless the
// patch removes the subscription from its merge; the follow outlives each
// write. An account that stored 2.4.0 before its server was upgraded keeps
// sending that removal, which the newer server must take the same way.

/// [connection] over v2 only, as an account that stored 2.4.0 sees it.
ServerConnection _storedAs24(ServerConnection connection) {
  final info = ServerInfo(
    version: const ServerVersion(2, 4, 0),
    maxItemsPerPage: connection.info.maxItemsPerPage,
  );
  const apiVersions = {ApiVersion.v2};
  return ServerConnection(
    rootUri: connection.rootUri,
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

void main() {
  group(
    'writes to followed tasks and projects on local Docker servers',
    skip: contractSkip,
    () {
      for (final (:port, :version) in contractServers) {
        group('$version on :$port', () {
          late Dio dio;
          late ServerConnection connection;
          late TestUser user;

          setUpAll(() async {
            dio = contractDio();
            connection = await DioServerConnector(dio)
                .connect('http://localhost:$port');
            user = await registerAndLogin(dio, connection);
          });

          tearDownAll(() => dio.close(force: true));

          for (final (apiVersion, stored) in [
            for (final apiVersion in ApiVersion.values) (apiVersion, false),
            if (contractServerVersion.isAtLeast(2, 5)) (ApiVersion.v2, true),
          ]) {
            final name =
                '${apiVersion.pathSegment}${stored ? ', a stored 2.4.0' : ''}';
            final removesSubscription =
                apiVersion == ApiVersion.v2 &&
                (stored || !contractServerVersion.isAtLeast(2, 5));
            group(name, skip: skipWithout(apiVersion), () {
              final patchesRemovingSubscription = <String>[];
              setUp(patchesRemovingSubscription.clear);
              late VikunjaWriteClient writes;
              late TasksWritePort tasks;
              late ProjectsWritePort projects;
              late VikunjaReadClient reads;
              late int projectId;
              late int childId;
              late int labelId;

              setUpAll(() async {
                final only = onlyVersion(connection, apiVersion);
                final authenticated =
                    createAuthenticatedDio(
                        base: dio,
                        connection: only,
                        tokens: StaticJwt(user.jwt),
                      )
                      ..interceptors.add(
                        InterceptorsWrapper(
                          onRequest: (options, handler) {
                            if (options.data
                                case final Map<Object?, Object?> body
                                when options.method == 'PATCH' &&
                                    body.containsKey('subscription')) {
                              patchesRemovingSubscription.add(options.path);
                            }
                            handler.next(options);
                          },
                        ),
                      );
                final writing = stored ? _storedAs24(connection) : only;
                writes = createWriteClient(
                  dio: authenticated,
                  connection: writing,
                );
                tasks = RetryingTasksWrites(writes.tasks);
                projects = RetryingProjectsWrites(writes.projects);
                reads = createReadClient(dio: authenticated, connection: only);
                projectId = (await projects.create(
                  NewProject(title: 'Followed $name'),
                )).id;
                await despiteWriteRaces(
                  () => writes.subscriptions.subscribe(
                    SubscriptionEntity.project,
                    projectId,
                  ),
                );
                childId = (await projects.create(
                  NewProject(
                    title: 'Followed child $name',
                    parentProjectId: projectId,
                  ),
                )).id;
                labelId = (await despiteWriteRaces(
                  () => writes.labels.create(const NewLabel(title: 'followed')),
                )).id;
              });

              Future<int> followedTask(String how) async {
                final id = (await tasks.create(
                  NewTask(projectId: projectId, title: 'Followed $how'),
                )).id;
                switch (how) {
                  case 'directly':
                    await despiteWriteRaces(
                      () => writes.subscriptions.subscribe(
                        SubscriptionEntity.task,
                        id,
                      ),
                    );
                  case 'as an assignee':
                    await tasks.update(
                      id,
                      TaskChanges(assignees: IdSetChange(added: {user.id})),
                    );
                }
                return id;
              }

              for (final how in [
                'directly',
                'as an assignee',
                'through its project',
              ]) {
                test('a task followed $how takes every change the outbox '
                    'sends and stays followed', () async {
                  final id = await followedTask(how);
                  final followed = await reads.subscriptions.forTask(id);
                  expect(followed, isNotNull);
                  final due = DateTime.now().toUtc().add(
                    const Duration(days: 3),
                  );
                  final day = DateTime.utc(due.year, due.month, due.day, 9);

                  for (final change in [
                    const TaskChanges(title: 'Renamed'),
                    const TaskChanges(description: '<p>Notes</p>'),
                    const TaskChanges(done: true),
                    const TaskChanges(done: false),
                    TaskChanges(
                      dueDate: DateChange.set(day),
                      startDate: DateChange.set(
                        day.subtract(const Duration(days: 1)),
                      ),
                      endDate: DateChange.set(day.add(const Duration(days: 1))),
                    ),
                    const TaskChanges(priority: 4),
                    const TaskChanges(percentDone: 0.5),
                    const TaskChanges(hexColor: '4caf50'),
                    const TaskChanges(isFavorite: true),
                    const TaskChanges(
                      repeatAfter: Duration(days: 7),
                      repeatMode: RepeatMode.afterAmount,
                    ),
                    TaskChanges(
                      reminders: [
                        TaskReminder(
                          reminder: day.subtract(const Duration(hours: 2)),
                        ),
                        const TaskReminder(
                          relativePeriod: Duration(minutes: -10),
                          relativeTo: ReminderRelativeTo.dueDate,
                        ),
                      ],
                    ),
                    TaskChanges(labels: IdSetChange(added: {labelId})),
                    TaskChanges(projectId: childId),
                  ]) {
                    await tasks.update(id, change);
                  }

                  final task = await reads.tasks.read(id);
                  expect(task.title, 'Renamed');
                  expect(task.description, '<p>Notes</p>');
                  expect(task.done, isFalse);
                  expect(task.dueDate, day);
                  expect(task.priority, TaskPriority.fromValue(4));
                  expect(task.percentDone, 0.5);
                  expect(task.hexColor, '4caf50');
                  expect(task.isFavorite, isTrue);
                  expect(task.repeatAfter, const Duration(days: 7));
                  expect(task.reminders, hasLength(2));
                  expect(task.labels.map((label) => label.id), [labelId]);
                  expect(task.projectId, childId);
                  if (how == 'as an assignee') {
                    expect(task.assignees.map((u) => u.id), [user.id]);
                  }
                  expect(await reads.subscriptions.forTask(id), followed);
                  expect(
                    patchesRemovingSubscription,
                    removesSubscription ? isNotEmpty : isEmpty,
                  );
                });
              }

              test(
                'a followed project and its child take an update, a '
                'rebased description and a move, and stay followed',
                () async {
                  await projects.update(
                    projectId,
                    const ProjectChanges(title: 'Followed, renamed'),
                  );
                  await projects.update(
                    childId,
                    const ProjectChanges(description: '<p>Child</p>'),
                    rebaseDescription: (current) => '$current<p>Child</p>',
                  );
                  await projects.move(
                    childId,
                    position: 2048,
                    parentProjectId: projectId,
                  );

                  final parent = await reads.subscriptions.forProject(
                    projectId,
                  );
                  final child = await reads.subscriptions.forProject(childId);
                  expect(
                    parent,
                    Subscription(
                      entity: SubscriptionEntity.project,
                      entityId: projectId,
                    ),
                  );
                  expect(child, parent);
                  expect(
                    patchesRemovingSubscription,
                    removesSubscription ? isNotEmpty : isEmpty,
                  );
                },
              );
            });
          }
        });
      }
    },
  );
}
