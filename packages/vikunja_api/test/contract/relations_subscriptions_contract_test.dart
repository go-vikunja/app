@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

Future<int> _createProject(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  Map<String, Object?> body,
) async {
  final v2 = connection.apiBaseUri(ApiVersion.v2);
  try {
    final response = await despiteWriteRaces(
      () => dio.postUri<Map<String, Object?>>(
        v2.replace(path: '${v2.path}/projects'),
        data: body,
        options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
      ),
    );
    return response.data!['id']! as int;
  } on DioException catch (error) {
    // Error bodies carry no secrets; the failure is far easier to read with
    // the server's message.
    throw StateError(
      'POST /projects failed with ${error.response?.statusCode}: '
      '${error.response?.data}',
    );
  }
}

Future<void> _deleteProject(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  int projectId,
) async {
  final v2 = connection.apiBaseUri(ApiVersion.v2);
  await despiteWriteRaces(
    () => dio.deleteUri<Object?>(
      v2.replace(path: '${v2.path}/projects/$projectId'),
      options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
    ),
  );
}

Set<TaskRelationRef> _edges(Task task) => {
  for (final MapEntry(key: kind, value: others) in task.relatedTasks.entries)
    for (final other in others) TaskRelationRef(kind, other.id),
};

TaskChanges _add(Set<TaskRelationRef> edges) =>
    TaskChanges(relations: RelationChange(added: edges));

TaskChanges _remove(Set<TaskRelationRef> edges) =>
    TaskChanges(relations: RelationChange(removed: edges));

/// Makes the next read of a task show what [editNextRead] leaves of it, as a
/// read made before another device's change would; the request after it then
/// meets a race the write client has to tolerate. [errorStatuses] shows that
/// the server really answered with an error.
final class _StaleReads extends Interceptor {
  void Function(Map<String, Object?> task)? editNextRead;
  final List<int?> errorStatuses = [];

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final edit = editNextRead;
    final data = response.data;
    if (edit != null &&
        response.requestOptions.method == 'GET' &&
        RegExp(r'/tasks/\d+$').hasMatch(response.requestOptions.path) &&
        data is Map<String, Object?>) {
      editNextRead = null;
      edit(data);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    errorStatuses.add(err.response?.statusCode);
    handler.next(err);
  }
}

/// Retries over the lost write races of the shared SQLite server; both
/// calls are safe to repeat.
final class _RetryingSubscriptions implements SubscriptionsWritePort {
  new(this._writes);

  final SubscriptionsWritePort _writes;

  @override
  Future<void> subscribe(SubscriptionEntity entity, int id) =>
      despiteWriteRaces(() => _writes.subscribe(entity, id));

  @override
  Future<void> unsubscribe(SubscriptionEntity entity, int id) =>
      despiteWriteRaces(() => _writes.unsubscribe(entity, id));
}

void main() {
  group(
    'relations, duplicate and subscriptions on local Docker servers',
    skip: contractSkip,
    () {
      for (final (:port, :version) in contractServers) {
        group('$version on :$port', () {
          late Dio dio;
          late ServerConnection connection;
          late TestUser user;
          late String runId;

          setUpAll(() async {
            dio = contractDio();
            connection = await DioServerConnector(dio)
                .connect('http://localhost:$port');
            user = await registerAndLogin(dio, connection);
            runId = Random.secure().nextInt(1 << 16).toRadixString(16);
          });

          tearDownAll(() => dio.close(force: true));

          // From 2.8.0 a deleted task waits in the trash, and every route
          // answers 4040 for it.
          int taskGoneCode() =>
              connection.info.version!.isAtLeast(2, 8) ? 4040 : 4002;

          for (final apiVersion in ApiVersion.values) {
            group(apiVersion.pathSegment, () {
              late TasksWritePort rawWrites;
              late TasksWritePort writes;
              late TasksPort reads;
              late _StaleReads staleReads;
              late SubscriptionsWritePort subscriptionWrites;
              late SubscriptionsPort subscriptions;
              late int projectId;
              late int childProjectId;

              setUpAll(() async {
                expect(connection.apiVersions, contains(apiVersion));
                final only = onlyVersion(connection, apiVersion);
                staleReads = _StaleReads();
                final authenticated = createAuthenticatedDio(
                  base: dio,
                  connection: only,
                  tokens: StaticJwt(user.jwt),
                )..interceptors.add(staleReads);
                final writeClient = createWriteClient(
                  dio: authenticated,
                  connection: only,
                );
                final readClient = createReadClient(
                  dio: authenticated,
                  connection: only,
                );
                rawWrites = writeClient.tasks;
                // Other test files write to the same SQLite server meanwhile.
                writes = RetryingTasksWrites(rawWrites);
                reads = readClient.tasks;
                subscriptionWrites = _RetryingSubscriptions(
                  writeClient.subscriptions,
                );
                subscriptions = readClient.subscriptions;
                // A project per version: subscriptions belong to the user,
                // and one version's project subscription would show in the
                // other's tasks.
                projectId = await _createProject(dio, connection, user, {
                  'title':
                      'Relations contract ${apiVersion.pathSegment} '
                      '$runId',
                });
                childProjectId = await _createProject(dio, connection, user, {
                  'title': 'Relations contract child $runId',
                  'parent_project_id': projectId,
                });
              });

              Future<Task> newTask(String title, {int? project}) =>
                  writes.create(
                    NewTask(projectId: project ?? projectId, title: title),
                  );

              group('relations', () {
                test('added, added again, removed, removed again; the server '
                    'keeps the inverse edges on the other tasks', () async {
                  final parent = await newTask('Parent');
                  final child = await newTask('Child');
                  final other = await newTask('Other');
                  final edges = {
                    TaskRelationRef(TaskRelationKind.parentTask, parent.id),
                    TaskRelationRef(TaskRelationKind.related, other.id),
                  };

                  final added = await writes.update(child.id, _add(edges));
                  expect(_edges(added), edges);
                  expect(_edges(await reads.read(parent.id)), {
                    TaskRelationRef(TaskRelationKind.subtask, child.id),
                  });
                  expect(_edges(await reads.read(other.id)), {
                    TaskRelationRef(TaskRelationKind.related, child.id),
                  });

                  final addedAgain = await writes.update(child.id, _add(edges));
                  expect(_edges(addedAgain), edges);

                  final removed = await writes.update(child.id, _remove(edges));
                  expect(removed.relatedTasks, isEmpty);
                  expect((await reads.read(parent.id)).relatedTasks, isEmpty);
                  expect((await reads.read(other.id)).relatedTasks, isEmpty);

                  final removedAgain = await writes.update(
                    child.id,
                    _remove(edges),
                  );
                  expect(removedAgain.relatedTasks, isEmpty);
                });

                test('an edge whose inverse was added from the other task '
                    'counts as added, and either side removes both', () async {
                  final parent = await newTask('Parent from above');
                  final child = await newTask('Child from above');
                  final down = TaskRelationRef(
                    TaskRelationKind.subtask,
                    child.id,
                  );
                  final up = TaskRelationRef(
                    TaskRelationKind.parentTask,
                    parent.id,
                  );

                  await writes.update(parent.id, _add({down}));
                  // The read shows the edge already, so nothing is sent; a
                  // stale read would meet the server's 409 code 4008.
                  expect(_edges(await writes.update(child.id, _add({up}))), {
                    up,
                  });

                  await writes.update(parent.id, _remove({down}));
                  expect((await reads.read(child.id)).relatedTasks, isEmpty);
                });

                test(
                  'races after a stale read: an add answered 409 code '
                  '4008 and a remove answered 404 code 4009 count as done',
                  () async {
                    final task = await newTask('Raced');
                    final there = await newTask('Already related');
                    final gone = await newTask('No longer related');
                    final thereEdge = TaskRelationRef(
                      TaskRelationKind.related,
                      there.id,
                    );
                    final goneEdge = TaskRelationRef(
                      TaskRelationKind.precedes,
                      gone.id,
                    );
                    await writes.update(task.id, _add({thereEdge}));

                    // A lost write race is retried after a fresh stale read, so
                    // the statuses are those of the attempt that got through.
                    Future<Task> afterStaleRead(
                      void Function(Map<String, Object?> task) edit,
                      TaskChanges changes,
                    ) => despiteWriteRaces(() {
                      staleReads
                        ..errorStatuses.clear()
                        ..editNextRead = edit;
                      return rawWrites.update(task.id, changes);
                    });

                    // The read misses the edge another device just added.
                    final readded = await afterStaleRead(
                      (task) => task['related_tasks'] = <String, Object?>{},
                      _add({thereEdge}),
                    );
                    expect(staleReads.errorStatuses, [409]);
                    expect(_edges(readded), {thereEdge});

                    // The read shows an edge another device just removed.
                    final removed = await afterStaleRead((task) {
                      task['related_tasks'] = {
                        ...?task['related_tasks'] as Map<String, Object?>?,
                        'precedes': [
                          {
                            'id': gone.id,
                            'title': gone.title,
                            'project_id': projectId,
                          },
                        ],
                      };
                    }, _remove({goneEdge}));
                    expect(staleReads.errorStatuses, [404]);
                    expect(_edges(removed), {thereEdge});
                  },
                );

                test('every kind is stored with its inverse', () async {
                  const inverse = {
                    TaskRelationKind.subtask: TaskRelationKind.parentTask,
                    TaskRelationKind.related: TaskRelationKind.related,
                    TaskRelationKind.duplicateOf: TaskRelationKind.duplicates,
                    TaskRelationKind.blocking: TaskRelationKind.blocked,
                    TaskRelationKind.precedes: TaskRelationKind.follows,
                    TaskRelationKind.copiedFrom: TaskRelationKind.copiedTo,
                  };
                  final task = await newTask('Every kind');
                  final others = {
                    for (final kind in inverse.keys)
                      kind: await newTask('Other ${kind.wireName}'),
                  };

                  final stored = await writes.update(
                    task.id,
                    _add({
                      for (final MapEntry(key: kind, value: other)
                          in others.entries)
                        TaskRelationRef(kind, other.id),
                    }),
                  );

                  expect(
                    stored.relatedTasks.keys,
                    unorderedEquals(inverse.keys),
                  );
                  for (final MapEntry(key: kind, value: other)
                      in others.entries) {
                    expect(_edges(await reads.read(other.id)), {
                      TaskRelationRef(inverse[kind]!, task.id),
                    }, reason: kind.wireName);
                  }
                });

                test('a cycle is refused with 409 code 4023', () async {
                  final parent = await newTask('Cycle parent');
                  final child = await newTask('Cycle child');
                  await writes.update(
                    child.id,
                    _add({
                      TaskRelationRef(TaskRelationKind.parentTask, parent.id),
                    }),
                  );

                  await expectLater(
                    writes.update(
                      parent.id,
                      _add({
                        TaskRelationRef(TaskRelationKind.parentTask, child.id),
                      }),
                    ),
                    throwsA(
                      isA<DomainError>()
                          .having((f) => f.statusCode, 'status', 409)
                          .having((f) => f.code, 'code', 4023),
                    ),
                  );
                });

                test(
                  'a relation to the task itself is refused with code 4010',
                  () async {
                    final task = await newTask('Self');

                    await expectLater(
                      writes.update(
                        task.id,
                        _add({
                          TaskRelationRef(TaskRelationKind.related, task.id),
                        }),
                      ),
                      throwsA(
                        isA<DomainError>()
                            .having((f) => f.statusCode, 'status', 400)
                            .having((f) => f.code, 'code', 4010),
                      ),
                    );
                  },
                );

                test('a deleted other task is a RelatedTaskMissing, and the '
                    'task itself is still there', () async {
                  final task = await newTask('Relates to a ghost');
                  final ghost = await newTask('Ghost');
                  await writes.delete(ghost.id);

                  await expectLater(
                    writes.update(
                      task.id,
                      _add({
                        TaskRelationRef(TaskRelationKind.related, ghost.id),
                      }),
                    ),
                    throwsA(
                      isA<RelatedTaskMissing>()
                          .having((f) => f.otherTaskId, 'otherTaskId', ghost.id)
                          .having((f) => f.code, 'code', taskGoneCode()),
                    ),
                  );
                  expect((await reads.read(task.id)).relatedTasks, isEmpty);
                });

                test('an other task in a deleted project is a '
                    'RelatedTaskMissing, and its edge counts as '
                    'removed', () async {
                  final task = await newTask('Relates into a doomed project');
                  final doomedProject = await _createProject(
                    dio,
                    connection,
                    user,
                    {'title': 'Relations contract doomed $runId'},
                  );
                  final other = await newTask(
                    'In the doomed project',
                    project: doomedProject,
                  );
                  final edge = TaskRelationRef(
                    TaskRelationKind.related,
                    other.id,
                  );
                  await writes.update(task.id, _add({edge}));
                  await _deleteProject(dio, connection, user, doomedProject);
                  final projectGoneCode =
                      connection.info.version!.isAtLeast(2, 8) ? 3018 : 4002;

                  expect((await reads.read(task.id)).relatedTasks, isEmpty);
                  // A read from before the delete still shows the edge.
                  final removed = await despiteWriteRaces(() {
                    staleReads
                      ..errorStatuses.clear()
                      ..editNextRead = (read) => read['related_tasks'] = {
                        'related': [
                          {
                            'id': other.id,
                            'title': other.title,
                            'project_id': doomedProject,
                          },
                        ],
                      };
                    return rawWrites.update(task.id, _remove({edge}));
                  });
                  expect(staleReads.errorStatuses, [404]);
                  expect(removed.relatedTasks, isEmpty);
                  await expectLater(
                    writes.update(task.id, _add({edge})),
                    throwsA(
                      isA<RelatedTaskMissing>()
                          .having((f) => f.otherTaskId, 'otherTaskId', other.id)
                          .having((f) => f.code, 'code', projectGoneCode),
                    ),
                  );
                  expect((await reads.read(task.id)).relatedTasks, isEmpty);
                });

                test('the edges to a deleted task go with it; removing one '
                    'afterwards is no failure', () async {
                  final task = await newTask('Outlives');
                  final doomed = await newTask('Doomed');
                  final edge = TaskRelationRef(
                    TaskRelationKind.blocking,
                    doomed.id,
                  );
                  await writes.update(task.id, _add({edge}));

                  await writes.delete(doomed.id);

                  expect((await reads.read(task.id)).relatedTasks, isEmpty);
                  final removed = await writes.update(task.id, _remove({edge}));
                  expect(removed.relatedTasks, isEmpty);
                });

                test('body fields and relations in one update', () async {
                  final task = await newTask('Before');
                  final other = await newTask('Precedes it');
                  final edge = TaskRelationRef(
                    TaskRelationKind.follows,
                    other.id,
                  );

                  final changed = await writes.update(
                    task.id,
                    TaskChanges(
                      title: 'After',
                      relations: RelationChange(added: {edge}),
                    ),
                  );

                  expect(changed.title, 'After');
                  expect(_edges(changed), {edge});
                  final stored = await reads.read(task.id);
                  expect(stored.title, 'After');
                  expect(_edges(stored), {edge});
                });

                test('a title change and a relation remove in one update '
                    'remove the edge', () async {
                  final task = await newTask('Rename and unrelate');
                  final other = await newTask('Related until then');
                  final edge = TaskRelationRef(
                    TaskRelationKind.related,
                    other.id,
                  );
                  await writes.update(task.id, _add({edge}));

                  final changed = await writes.update(
                    task.id,
                    TaskChanges(
                      title: 'Renamed',
                      relations: RelationChange(removed: {edge}),
                    ),
                  );

                  expect(changed.title, 'Renamed');
                  expect(changed.relatedTasks, isEmpty);
                  final stored = await reads.read(task.id);
                  expect(stored.title, 'Renamed');
                  expect(stored.relatedTasks, isEmpty);
                  expect((await reads.read(other.id)).relatedTasks, isEmpty);
                });

                test(
                  'a body-only update answers with the edges of the task',
                  () async {
                    final parent = await newTask('Keeps its subtask');
                    final child = await newTask('Its subtask');
                    final edge = TaskRelationRef(
                      TaskRelationKind.subtask,
                      child.id,
                    );
                    await writes.update(parent.id, _add({edge}));

                    final renamed = await writes.update(
                      parent.id,
                      const TaskChanges(title: 'Renamed parent'),
                    );
                    expect(renamed.title, 'Renamed parent');
                    expect(_edges(renamed), {edge});

                    final done = await writes.update(
                      parent.id,
                      const TaskChanges(done: true),
                    );
                    expect(done.done, isTrue);
                    expect(_edges(done), {edge});
                  },
                );
              });

              test('duplicate returns the copy with copiedfrom; the source '
                  'gets copiedto', () async {
                final source = await writes.create(
                  NewTask(
                    projectId: projectId,
                    title: 'Original',
                    description: '<p>Copied along</p>',
                  ),
                );

                final copy = await writes.duplicate(source.id);

                expect(copy.id, isNot(source.id));
                expect(copy.title, 'Original');
                expect(copy.description, '<p>Copied along</p>');
                expect(copy.projectId, projectId);
                expect(_edges(copy), {
                  TaskRelationRef(TaskRelationKind.copiedFrom, source.id),
                });
                expect(_edges(await reads.read(source.id)), {
                  TaskRelationRef(TaskRelationKind.copiedTo, copy.id),
                });
                expect(_edges(await reads.read(copy.id)), {
                  TaskRelationRef(TaskRelationKind.copiedFrom, source.id),
                });
              });

              group('subscriptions', () {
                Subscription own(SubscriptionEntity entity, int id) =>
                    Subscription(entity: entity, entityId: id);

                test('the creator follows a new task; unsubscribe and '
                    'subscribe again, each twice', () async {
                  final task = await newTask('Followed');
                  final ownTask = own(SubscriptionEntity.task, task.id);

                  expect(await subscriptions.forTask(task.id), ownTask);
                  await subscriptionWrites.subscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(await subscriptions.forTask(task.id), ownTask);

                  await subscriptionWrites.unsubscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(await subscriptions.forTask(task.id), isNull);
                  await subscriptionWrites.unsubscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(await subscriptions.forTask(task.id), isNull);

                  await subscriptionWrites.subscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(await subscriptions.forTask(task.id), ownTask);
                });

                test('a project subscription covers its tasks and child '
                    'projects; unfollowing a task stores an opt-out', () async {
                  final ownProject = own(SubscriptionEntity.project, projectId);
                  final task = await newTask('Covered');
                  // Without the creator's own subscription, the task shows
                  // the project's.
                  await subscriptionWrites.unsubscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(await subscriptions.forProject(projectId), isNull);

                  await subscriptionWrites.subscribe(
                    SubscriptionEntity.project,
                    projectId,
                  );
                  await subscriptionWrites.subscribe(
                    SubscriptionEntity.project,
                    projectId,
                  );
                  expect(await subscriptions.forProject(projectId), ownProject);
                  expect(
                    await subscriptions.forProject(childProjectId),
                    ownProject,
                  );
                  expect(await subscriptions.forTask(task.id), ownProject);

                  await subscriptionWrites.unsubscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(await subscriptions.forTask(task.id), isNull);
                  expect(await subscriptions.forProject(projectId), ownProject);
                  await subscriptionWrites.unsubscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(await subscriptions.forTask(task.id), isNull);

                  await subscriptionWrites.subscribe(
                    SubscriptionEntity.task,
                    task.id,
                  );
                  expect(
                    await subscriptions.forTask(task.id),
                    own(SubscriptionEntity.task, task.id),
                  );

                  await subscriptionWrites.unsubscribe(
                    SubscriptionEntity.project,
                    projectId,
                  );
                  expect(await subscriptions.forProject(projectId), isNull);
                  await subscriptionWrites.unsubscribe(
                    SubscriptionEntity.project,
                    projectId,
                  );
                  expect(await subscriptions.forProject(projectId), isNull);
                });

                test('a missing task cannot be followed', () async {
                  final ghost = await newTask('Unfollowable');
                  await writes.delete(ghost.id);

                  await expectLater(
                    subscriptionWrites.subscribe(
                      SubscriptionEntity.task,
                      ghost.id,
                    ),
                    throwsA(
                      isA<NotFound>().having(
                        (f) => f.code,
                        'code',
                        taskGoneCode(),
                      ),
                    ),
                  );
                  await expectLater(
                    subscriptions.forTask(ghost.id),
                    throwsA(isA<NotFound>()),
                  );
                });
              });
            });
          }
        });
      }
    },
  );
}
