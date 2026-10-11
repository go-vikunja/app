@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

Future<Map<String, Object?>> _post(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  String path,
  Map<String, Object?> body,
) async {
  final v2 = connection.apiBaseUri(ApiVersion.v2);
  try {
    final response = await despiteWriteRaces(
      () => dio.postUri<Map<String, Object?>>(
        v2.replace(path: '${v2.path}$path'),
        data: body,
        options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
      ),
    );
    return response.data!;
  } on DioException catch (error) {
    // Error bodies carry no secrets; the failure is far easier to read with
    // the server's message.
    throw StateError(
      'POST $path failed with ${error.response?.statusCode}: '
      '${error.response?.data}',
    );
  }
}

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

Set<int> _labelIds(Task task) => {for (final label in task.labels) label.id};

Set<int> _assigneeIds(Task task) => {
  for (final user in task.assignees) user.id,
};

void main() {
  group(
    'labels, assignees and project users on local Docker servers',
    skip: contractSkip,
    () {
      for (final (:port, :version) in contractServers) {
        group('$version on :$port', () {
          late Dio dio;
          late ServerConnection connection;
          late TestUser owner;
          late TestUser member;
          late int projectId;
          late int privateProjectId;
          late int foreignLabelId;
          late String runId;

          setUpAll(() async {
            dio = contractDio();
            connection = await DioServerConnector(dio)
                .connect('http://localhost:$port');
            // The owner writes through the clients. The member is shared
            // into one project with write permission, as the second
            // assignee, and owns a label the owner cannot see. The other
            // project is not shared, so the member cannot be assigned there.
            owner = await registerAndLogin(dio, connection);
            member = await registerAndLogin(dio, connection);
            runId = Random.secure().nextInt(1 << 16).toRadixString(16);
            Future<int> create(
              TestUser user,
              String path,
              Map<String, Object?> body,
            ) async =>
                (await _post(dio, connection, user, path, body))['id']! as int;
            projectId = await create(owner, '/projects', {
              'title': 'Labels contract $runId',
            });
            privateProjectId = await create(owner, '/projects', {
              'title': 'Labels contract, private $runId',
            });
            await _post(dio, connection, owner, '/projects/$projectId/users', {
              'username': member.username,
              'permission': 1,
            });
            foreignLabelId = await create(member, '/labels', {
              'title': 'Not yours $runId',
            });
          });

          tearDownAll(() => dio.close(force: true));

          for (final apiVersion in ApiVersion.values) {
            group(apiVersion.pathSegment, () {
              late TasksWritePort rawWrites;
              late TasksWritePort writes;
              late LabelsWritePort labels;
              late TasksPort reads;
              late UsersPort users;
              late _StaleReads staleReads;

              setUpAll(() async {
                expect(connection.apiVersions, contains(apiVersion));
                final only = onlyVersion(connection, apiVersion);
                staleReads = _StaleReads();
                final authenticated = createAuthenticatedDio(
                  base: dio,
                  connection: only,
                  tokens: StaticJwt(owner.jwt),
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
                labels = RetryingLabelsWrites(writeClient.labels);
                reads = readClient.tasks;
                users = readClient.users;
              });

              final suffix = apiVersion.pathSegment;

              Future<Task> newTask(
                String title, {
                int? project,
                DateTime? due,
              }) => writes.create(
                NewTask(
                  projectId: project ?? projectId,
                  title: title,
                  dueDate: due,
                ),
              );

              test(
                'a label is created with its colour and description',
                () async {
                  final label = await labels.create(
                    NewLabel(
                      title: 'Groceries $suffix $runId',
                      hexColor: 'fb5607',
                      description: 'Shop runs',
                    ),
                  );

                  expect(label.id, greaterThan(0));
                  expect(label.title, 'Groceries $suffix $runId');
                  expect(label.hexColor, 'fb5607');
                  expect(label.description, 'Shop runs');
                  expect(label.createdBy?.id, owner.id);

                  final plain = await labels.create(
                    NewLabel(title: 'Plain $suffix $runId'),
                  );
                  expect(plain.hexColor, '');
                  expect(plain.description, '');
                },
              );

              test(
                'labels added, added again, removed, removed again',
                () async {
                  final first = await labels.create(
                    NewLabel(title: 'First $suffix $runId', hexColor: 'e8323c'),
                  );
                  final second = await labels.create(
                    NewLabel(title: 'Second $suffix $runId'),
                  );
                  final task = await newTask('Labelled');
                  final both = {first.id, second.id};
                  final add = TaskChanges(labels: IdSetChange(added: both));
                  final remove = TaskChanges(
                    labels: IdSetChange(removed: both),
                  );

                  final added = await writes.update(task.id, add);
                  expect(_labelIds(added), both);
                  expect(_labelIds(await reads.read(task.id)), both);

                  final addedAgain = await writes.update(task.id, add);
                  expect(_labelIds(addedAgain), both);
                  expect(_labelIds(await reads.read(task.id)), both);

                  final removed = await writes.update(task.id, remove);
                  expect(removed.labels, isEmpty);
                  expect((await reads.read(task.id)).labels, isEmpty);

                  final removedAgain = await writes.update(task.id, remove);
                  expect(removedAgain.labels, isEmpty);
                  expect((await reads.read(task.id)).labels, isEmpty);
                },
              );

              test('assignees: the owner and a shared member assigned, again, '
                  'unassigned, again', () async {
                final task = await newTask('Assigned');
                final both = {owner.id, member.id};
                final assign = TaskChanges(assignees: IdSetChange(added: both));
                final unassign = TaskChanges(
                  assignees: IdSetChange(removed: both),
                );

                final assigned = await writes.update(task.id, assign);
                expect(_assigneeIds(assigned), both);
                expect(_assigneeIds(await reads.read(task.id)), both);

                final assignedAgain = await writes.update(task.id, assign);
                expect(_assigneeIds(assignedAgain), both);

                final unassigned = await writes.update(task.id, unassign);
                expect(unassigned.assignees, isEmpty);
                expect((await reads.read(task.id)).assignees, isEmpty);

                final unassignedAgain = await writes.update(task.id, unassign);
                expect(unassignedAgain.assignees, isEmpty);
              });

              test('body fields, labels and assignees in one update', () async {
                final label = await labels.create(
                  NewLabel(title: 'Together $suffix $runId'),
                );
                final task = await newTask('Separately');

                final changed = await writes.update(
                  task.id,
                  TaskChanges(
                    title: 'All at once',
                    priority: TaskPriority.urgent.value,
                    labels: IdSetChange(added: {label.id}),
                    assignees: IdSetChange(added: {member.id}),
                  ),
                );

                expect(changed.title, 'All at once');
                expect(changed.priority, TaskPriority.urgent);
                expect(_labelIds(changed), {label.id});
                expect(_assigneeIds(changed), {member.id});
                final stored = await reads.read(task.id);
                expect(stored.title, 'All at once');
                expect(_labelIds(stored), {label.id});
                expect(_assigneeIds(stored), {member.id});
              });

              test('a label and reminder change keeps the assignees', () async {
                final due = DateTime.utc(2030, 1, 2, 3, 4, 5);
                final label = await labels.create(
                  NewLabel(title: 'Kept $suffix $runId'),
                );
                final task = await newTask('Keeps its people', due: due);
                await writes.update(
                  task.id,
                  TaskChanges(
                    assignees: IdSetChange(added: {owner.id, member.id}),
                  ),
                );

                final changed = await writes.update(
                  task.id,
                  TaskChanges(
                    labels: IdSetChange(added: {label.id}),
                    reminders: const [
                      TaskReminder(
                        relativePeriod: Duration(hours: -1),
                        relativeTo: ReminderRelativeTo.dueDate,
                      ),
                    ],
                  ),
                );

                for (final current in [changed, await reads.read(task.id)]) {
                  expect(_assigneeIds(current), {owner.id, member.id});
                  expect(_labelIds(current), {label.id});
                  expect(
                    current.reminders.single.reminder,
                    due.subtract(const Duration(hours: 1)),
                  );
                }
              });

              test('the tolerated races, provoked by a stale read', () async {
                final label = await labels.create(
                  NewLabel(title: 'Raced $suffix $runId'),
                );
                final gone = await labels.create(
                  NewLabel(title: 'Gone $suffix $runId'),
                );
                final task = await newTask('Raced');
                await writes.update(
                  task.id,
                  TaskChanges(assignees: IdSetChange(added: {owner.id})),
                );
                await writes.update(
                  task.id,
                  TaskChanges(labels: IdSetChange(added: {label.id})),
                );

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

                // The read misses the label and the assignee another device
                // just added: the adds are answered 400 with 8001 and 4021.
                final readded = await afterStaleRead(
                  (task) {
                    task['labels'] = null;
                    task['assignees'] = null;
                  },
                  TaskChanges(
                    labels: IdSetChange(added: {label.id}),
                    assignees: IdSetChange(added: {owner.id}),
                  ),
                );
                expect(staleReads.errorStatuses, [400, 400]);
                expect(_labelIds(readded), {label.id});
                expect(_assigneeIds(readded), {owner.id});

                // The read shows a label another device just removed: the
                // remove is answered 403, and a second read clears it up.
                final removed = await afterStaleRead((task) {
                  task['labels'] = [
                    ...?task['labels'] as List<Object?>?,
                    {'id': gone.id, 'title': gone.title},
                  ];
                }, TaskChanges(labels: IdSetChange(removed: {gone.id})));
                expect(staleReads.errorStatuses, [403]);
                expect(_labelIds(removed), {label.id});
                expect(_labelIds(await reads.read(task.id)), {label.id});
                expect(_assigneeIds(removed), {owner.id});
              });

              test(
                'assigning a user without access is Forbidden 7003',
                () async {
                  final task = await newTask(
                    'Private',
                    project: privateProjectId,
                  );

                  await expectLater(
                    writes.update(
                      task.id,
                      TaskChanges(assignees: IdSetChange(added: {member.id})),
                    ),
                    throwsA(
                      isA<Forbidden>().having((f) => f.code, 'code', 7003),
                    ),
                  );
                  expect((await reads.read(task.id)).assignees, isEmpty);
                },
              );

              test('a label that does not exist is NotFound 8002', () async {
                final task = await newTask('Missing label');

                await expectLater(
                  writes.update(
                    task.id,
                    const TaskChanges(labels: IdSetChange(added: {1 << 30})),
                  ),
                  throwsA(isA<NotFound>().having((f) => f.code, 'code', 8002)),
                );
              });

              test("another user's label is Forbidden", () async {
                final task = await newTask('Foreign label');

                await expectLater(
                  writes.update(
                    task.id,
                    TaskChanges(labels: IdSetChange(added: {foreignLabelId})),
                  ),
                  throwsA(
                    isA<Forbidden>().having((f) => f.code, 'code', isNull),
                  ),
                );
                expect((await reads.read(task.id)).labels, isEmpty);
              });

              test(
                'the project users: owner and member, filtered by the query',
                () async {
                  final everyone = await users.searchProjectUsers(projectId);
                  expect(
                    everyone.map((u) => u.id),
                    unorderedEquals([owner.id, member.id]),
                  );
                  expect(
                    everyone.singleWhere((u) => u.id == member.id).username,
                    member.username,
                  );

                  final found = await users.searchProjectUsers(
                    projectId,
                    query: member.username,
                  );
                  expect(found.map((u) => u.id), [member.id]);

                  expect(
                    await users.searchProjectUsers(
                      projectId,
                      query: 'nobody-$runId',
                    ),
                    isEmpty,
                  );
                  expect(
                    (await users.searchProjectUsers(privateProjectId))
                        .map((u) => u.id),
                    [owner.id],
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
