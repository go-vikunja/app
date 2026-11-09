@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Seeded through raw v2 calls, once per API version: a task with everything
// a v1 full replace could lose (the user as assignee, an absolute and a
// relative reminder, a label), a daily repeating task due in two days and a
// task to delete. The project with its per-run identifier and the label are
// shared by both versions.
typedef _Seed = ({
  int richId,
  int repeatingId,
  int doomedId,
  DateTime reminderAt,
  DateTime repeatingDue,
});

final class _Seeder {
  new(this._dio, ServerConnection connection, this._user)
    : _v2 = connection.apiBaseUri(ApiVersion.v2);

  final Dio _dio;
  final Uri _v2;
  final TestUser _user;

  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await despiteWriteRaces(
        () => _dio.postUri<Map<String, Object?>>(
          _v2.replace(path: '${_v2.path}$path'),
          data: body,
          options: Options(headers: {'Authorization': 'Bearer ${_user.jwt}'}),
        ),
      );
      return response.data!;
    } on DioException catch (error) {
      // Error bodies carry no secrets; the failure is far easier to read
      // with the server's message.
      throw StateError(
        'POST $path failed with ${error.response?.statusCode}: '
        '${error.response?.data}',
      );
    }
  }

  Future<int> create(String path, Map<String, Object?> body) async =>
      (await post(path, body))['id']! as int;

  Future<void> delete(String path) => despiteWriteRaces(
    () => _dio.deleteUri<Object?>(
      _v2.replace(path: '${_v2.path}$path'),
      options: Options(headers: {'Authorization': 'Bearer ${_user.jwt}'}),
    ),
  );

  Future<_Seed> tasks(int projectId, int labelId) async {
    final now = DateTime.now().toUtc();
    final reminderAt = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour + 1,
      now.minute,
      now.second,
    );
    final repeatingDue = reminderAt.add(const Duration(days: 2));
    final path = '/projects/$projectId/tasks';
    final richId = await create(path, {
      'title': 'Water the plants',
      'description': '<p>Every pot</p>',
      'due_date': reminderAt.add(const Duration(days: 1)).toIso8601String(),
      'priority': 3,
      'reminders': [
        {'reminder': reminderAt.toIso8601String()},
        {'relative_period': -600, 'relative_to': 'due_date'},
      ],
    });
    await post('/tasks/$richId/assignees', {'user_id': _user.id});
    await post('/tasks/$richId/labels', {'label_id': labelId});
    final repeatingId = await create(path, {
      'title': 'Daily',
      'due_date': repeatingDue.toIso8601String(),
      'repeat_after': 86400,
    });
    final doomedId = await create(path, {'title': 'Doomed'});
    return (
      richId: richId,
      repeatingId: repeatingId,
      doomedId: doomedId,
      reminderAt: reminderAt,
      repeatingDue: repeatingDue,
    );
  }
}

Matcher _within1s(DateTime expected) => predicate<DateTime?>(
  (actual) =>
      actual != null &&
      actual.difference(expected).abs() < const Duration(seconds: 1),
  'within a second of $expected',
);

void main() {
  group('writes on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;
        late _Seeder seeder;
        late int projectId;
        late String identifier;
        late int otherProjectId;
        late String otherIdentifier;
        late int labelId;

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
          seeder = _Seeder(dio, connection, user);
          final runId = Random.secure().nextInt(1 << 16).toRadixString(16);
          identifier = 'CW${runId.toUpperCase()}';
          otherIdentifier = 'CX${runId.toUpperCase()}';
          projectId = await seeder.create('/projects', {
            'title': 'Write contract',
            'identifier': identifier,
          });
          otherProjectId = await seeder.create('/projects', {
            'title': 'Write contract, moved',
            'identifier': otherIdentifier,
          });
          labelId = await seeder.create('/labels', {
            'title': 'kept',
            'hex_color': 'e8323c',
          });
        });

        tearDownAll(() => dio.close(force: true));

        bool since280() => connection.info.version!.isAtLeast(2, 8);

        Matcher notFound(int code) =>
            isA<NotFound>().having((f) => f.code, 'code', code);

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            late _Seed seed;
            late TasksWritePort writes;
            late TasksPort reads;
            late int createdId;

            setUpAll(() async {
              expect(connection.apiVersions, contains(apiVersion));
              seed = await seeder.tasks(projectId, labelId);
              final only = onlyVersion(connection, apiVersion);
              final authenticated = createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(user.jwt),
              );
              // Other test files write to the same SQLite server meanwhile.
              writes = RetryingTasksWrites(
                createWriteClient(dio: authenticated, connection: only).tasks,
              );
              reads = createReadClient(
                dio: authenticated,
                connection: only,
              ).tasks;
            });

            void expectIntact(Task task) {
              expect(task.assignees.map((u) => u.id), [user.id]);
              expect(task.reminders, hasLength(2));
              expect(
                task.reminders.map((r) => r.relativeTo),
                containsAll([null, ReminderRelativeTo.dueDate]),
              );
              expect(
                task.reminders.singleWhere((r) => !r.isRelative).reminder,
                _within1s(seed.reminderAt),
              );
              expect(
                task.reminders.singleWhere((r) => r.isRelative).relativePeriod,
                const Duration(minutes: -10),
              );
              expect(task.labels.map((l) => l.id), [labelId]);
              expect(task.title, 'Water the plants');
              expect(task.description, '<p>Every pot</p>');
              expect(task.priority, TaskPriority.high);
              expect(task.dueDate, isNotNull);
            }

            test(
              'marking done keeps assignees, reminders and the label',
              () async {
                final response = await writes.update(
                  seed.richId,
                  const TaskChanges(done: true),
                );

                expect(response.id, seed.richId);
                expect(response.done, isTrue);
                expect(response.doneAt, isNotNull);
                expectIntact(response);

                final stored = await reads.read(seed.richId);
                expect(stored.done, isTrue);
                expect(stored.doneAt, isNotNull);
                expectIntact(stored);
              },
            );

            test('marking not done again', () async {
              final response = await writes.update(
                seed.richId,
                const TaskChanges(done: false),
              );

              expect(response.done, isFalse);
              expect(response.doneAt, isNull);
              expectIntact(response);

              final stored = await reads.read(seed.richId);
              expect(stored.done, isFalse);
              expect(stored.doneAt, isNull);
              expectIntact(stored);
            });

            test('favourite on and off', () async {
              final on = await writes.update(
                seed.richId,
                const TaskChanges(isFavorite: true),
              );
              expect(on.isFavorite, isTrue);
              expect((await reads.read(seed.richId)).isFavorite, isTrue);

              final off = await writes.update(
                seed.richId,
                const TaskChanges(isFavorite: false),
              );
              expect(off.isFavorite, isFalse);
              final stored = await reads.read(seed.richId);
              expect(stored.isFavorite, isFalse);
              expectIntact(stored);
            });

            test('a title change', () async {
              final response = await writes.update(
                seed.richId,
                const TaskChanges(title: 'Water the plants twice'),
              );
              expect(response.title, 'Water the plants twice');

              final stored = await reads.read(seed.richId);
              expect(stored.title, 'Water the plants twice');
              expect(stored.done, isFalse);
              expect(stored.assignees.map((u) => u.id), [user.id]);
              expect(stored.reminders, hasLength(2));
              expect(stored.labels.map((l) => l.id), [labelId]);

              final back = await writes.update(
                seed.richId,
                const TaskChanges(title: 'Water the plants'),
              );
              expect(back.title, 'Water the plants');
            });

            test('an update that changes nothing returns the task', () async {
              final response = await writes.update(
                seed.richId,
                const TaskChanges(title: 'Water the plants'),
              );

              expect(response.id, seed.richId);
              expect(response.title, 'Water the plants');
              expectIntact(await reads.read(seed.richId));
            });

            test('setting and clearing the due date', () async {
              final due = DateTime.utc(2030, 1, 2, 3, 4, 5);

              final set = await writes.update(
                seed.richId,
                TaskChanges(dueDate: DateChange.set(due)),
              );
              expect(set.dueDate, due);
              expect((await reads.read(seed.richId)).dueDate, due);

              final cleared = await writes.update(
                seed.richId,
                const TaskChanges(dueDate: DateChange.clear()),
              );
              expect(cleared.dueDate, isNull);
              final stored = await reads.read(seed.richId);
              expect(stored.dueDate, isNull);
              expect(stored.assignees.map((u) => u.id), [user.id]);
              expect(stored.reminders, hasLength(2));
              expect(stored.labels.map((l) => l.id), [labelId]);
            });

            test(
              'a repeating task marked done comes back open a day later',
              () async {
                final response = await writes.update(
                  seed.repeatingId,
                  const TaskChanges(done: true),
                );

                expect(response.done, isFalse);
                expect(
                  response.dueDate,
                  _within1s(seed.repeatingDue.add(const Duration(days: 1))),
                );
                expect(response.repeatAfter, const Duration(days: 1));

                final stored = await reads.read(seed.repeatingId);
                expect(stored.done, isFalse);
                expect(stored.dueDate, response.dueDate);
              },
            );

            test('create with every core field: the server echoes them and '
                'assigns the identifier', () async {
              final due = DateTime.utc(2030, 1, 2, 3, 4, 5);
              final start = DateTime.utc(2030, 1, 1, 8);
              final end = DateTime.utc(2030, 1, 3, 18);
              final title = 'Created on ${apiVersion.pathSegment}';

              final created = await writes.create(
                NewTask(
                  projectId: projectId,
                  title: title,
                  description: '<p>With everything</p>',
                  dueDate: due,
                  startDate: start,
                  endDate: end,
                  priority: TaskPriority.urgent,
                  percentDone: 0.5,
                  hexColor: '1973ff',
                  repeatAfter: const Duration(days: 30),
                  isFavorite: true,
                ),
              );
              createdId = created.id;

              expect(created.id, greaterThan(0));
              expect(created.projectId, projectId);
              expect(created.index, greaterThan(0));
              expect(created.identifier, '$identifier-${created.index}');
              expect(created.title, title);
              expect(created.description, '<p>With everything</p>');
              expect(created.done, isFalse);
              expect(created.dueDate, due);
              expect(created.startDate, start);
              expect(created.endDate, end);
              expect(created.priority, TaskPriority.urgent);
              expect(created.percentDone, 0.5);
              expect(created.hexColor, '1973ff');
              expect(created.repeatAfter, const Duration(days: 30));
              expect(created.repeatMode, RepeatMode.afterAmount);
              expect(created.repeats, isTrue);
              expect(created.isFavorite, isTrue);
              expect(created.created, isNotNull);
              expect(created.createdBy?.id, user.id);

              final stored = await reads.read(created.id);
              expect(stored.identifier, created.identifier);
              expect(stored.title, title);
              expect(stored.dueDate, due);
              expect(stored.priority, TaskPriority.urgent);
              expect(stored.hexColor, '1973ff');
              expect(stored.repeatAfter, const Duration(days: 30));
              expect(stored.isFavorite, isTrue);
            });

            test('a move to another project gives a new identifier', () async {
              final moved = await writes.update(
                createdId,
                TaskChanges(projectId: otherProjectId),
              );

              expect(moved.id, createdId);
              expect(moved.projectId, otherProjectId);
              expect(moved.identifier, '$otherIdentifier-${moved.index}');
              expect(moved.title, 'Created on ${apiVersion.pathSegment}');
              expect(moved.repeatAfter, const Duration(days: 30));
              expect(moved.isFavorite, isTrue);

              final stored = await reads.read(createdId);
              expect(stored.projectId, otherProjectId);
              expect(stored.identifier, moved.identifier);
              expect(stored.index, moved.index);
            });

            test('repeat changed, switched to monthly and removed', () async {
              final weekly = await writes.update(
                createdId,
                const TaskChanges(
                  repeatAfter: Duration(days: 7),
                  repeatMode: RepeatMode.afterAmount,
                ),
              );
              expect(weekly.repeatAfter, const Duration(days: 7));
              expect(weekly.repeatMode, RepeatMode.afterAmount);
              expect(weekly.repeats, isTrue);

              final monthly = await writes.update(
                createdId,
                const TaskChanges(repeatMode: RepeatMode.monthly),
              );
              expect(monthly.repeatMode, RepeatMode.monthly);
              expect(monthly.repeats, isTrue);

              final removed = await writes.update(
                createdId,
                const TaskChanges(
                  repeatAfter: Duration.zero,
                  repeatMode: RepeatMode.afterAmount,
                ),
              );
              expect(removed.repeatAfter, Duration.zero);
              expect(removed.repeatMode, RepeatMode.afterAmount);
              expect(removed.repeats, isFalse);

              final stored = await reads.read(createdId);
              expect(stored.repeatAfter, Duration.zero);
              expect(stored.repeatMode, RepeatMode.afterAmount);
              expect(stored.repeats, isFalse);
            });

            test('an empty title is rejected', () async {
              final failure = switch (apiVersion) {
                ApiVersion.v2 => isA<ValidationFailed>().having(
                  (f) => f.fieldErrors.keys,
                  'fields',
                  ['title'],
                ),
                ApiVersion.v1 =>
                  isA<DomainError>()
                      .having((f) => f.statusCode, 'status', 400)
                      .having((f) => f.code, 'code', 4001),
              };

              await expectLater(
                writes.create(NewTask(projectId: projectId, title: '')),
                throwsA(failure),
              );
            });

            test('a repeat beyond ten years is domain error 4029', () async {
              final failure = isA<DomainError>()
                  .having((f) => f.statusCode, 'status', 400)
                  .having((f) => f.code, 'code', 4029);
              const tooLong = Duration(days: 4000);

              await expectLater(
                writes.create(
                  NewTask(
                    projectId: projectId,
                    title: 'Too long',
                    repeatAfter: tooLong,
                  ),
                ),
                throwsA(failure),
              );
              await expectLater(
                writes.update(
                  createdId,
                  const TaskChanges(repeatAfter: tooLong),
                ),
                throwsA(failure),
              );
            });

            // From 2.8.0 a deleted task waits in the trash for 30 days.
            test('delete, then delete again', () async {
              await writes.delete(seed.doomedId);

              await expectLater(
                reads.read(seed.doomedId),
                throwsA(notFound(since280() ? 4040 : 4002)),
              );
              await expectLater(writes.delete(seed.doomedId), completes);
            });

            test('a task whose project went to the trash answers 3018 to a '
                'read and 3001 to a delete, which counts as done', () async {
              final trashedProject = await seeder.create('/projects', {
                'title': 'Trashed ${apiVersion.pathSegment}',
              });
              final taskId = await seeder.create(
                '/projects/$trashedProject/tasks',
                {'title': 'In a trashed project'},
              );
              await seeder.delete('/projects/$trashedProject');
              final base = connection.apiBaseUri(apiVersion);

              await expectLater(
                reads.read(taskId),
                throwsA(notFound(since280() ? 3018 : 4002)),
              );
              await expectLater(
                despiteWriteRaces(
                  () => dio.deleteUri<Object?>(
                    base.replace(path: '${base.path}/tasks/$taskId'),
                    options: Options(
                      headers: {'Authorization': 'Bearer ${user.jwt}'},
                    ),
                  ),
                ),
                throwsA(
                  isA<DioException>().having(
                    normalizeError,
                    'failure',
                    notFound(since280() ? 3001 : 4002),
                  ),
                ),
              );
              await expectLater(writes.delete(taskId), completes);
            });

            test('from 2.8.0 a title has at most 1000 code points and a task '
                'at most 100 reminders, refused with code 2002', () async {
              if (!since280()) {
                markTestSkipped('servers before 2.8.0 have no such limits');
                return;
              }
              Matcher refused(String field) => isA<ValidationFailed>()
                  .having((f) => f.code, 'code', 2002)
                  .having((f) => f.fieldErrors.keys, 'fields', [field]);
              final longest = '\u{1F600}' * Task.maxTitleLength;
              final reminders = [
                for (var i = 0; i < Task.maxReminders; i++)
                  TaskReminder(
                    reminder: DateTime.utc(2030).add(Duration(minutes: i)),
                  ),
              ];

              final created = await writes.create(
                NewTask(
                  projectId: projectId,
                  title: longest,
                  reminders: reminders,
                ),
              );
              expect(created.title, longest);
              expect(created.reminders, hasLength(Task.maxReminders));
              final stored = await reads.read(created.id);
              expect(stored.title, longest);
              expect(stored.reminders, hasLength(Task.maxReminders));

              await expectLater(
                writes.create(
                  NewTask(projectId: projectId, title: '${longest}x'),
                ),
                throwsA(refused('title')),
              );
              await expectLater(
                writes.update(
                  created.id,
                  TaskChanges(title: '\u00e4' * (Task.maxTitleLength + 1)),
                ),
                throwsA(refused('title')),
              );
              await expectLater(
                writes.update(
                  created.id,
                  TaskChanges(
                    reminders: [
                      ...reminders,
                      TaskReminder(reminder: DateTime.utc(2031)),
                    ],
                  ),
                ),
                throwsA(refused('reminders')),
              );
              // Unchanged, the long title and the reminders stay editable.
              final done = await writes.update(
                created.id,
                const TaskChanges(done: true),
              );
              expect(done.title, longest);
              expect(done.reminders, hasLength(Task.maxReminders));
            });

            test('a NUL in a text is stripped before it is sent: 2.8.0 '
                'refuses a body with one', () async {
              if (since280()) {
                final base = connection.apiBaseUri(apiVersion);
                await expectLater(
                  despiteWriteRaces(
                    () => dio.requestUri<Object?>(
                      base.replace(
                        path: '${base.path}/projects/$projectId/tasks',
                      ),
                      data: {'title': 'Raw\u0000 NUL'},
                      options: Options(
                        method: switch (apiVersion) {
                          ApiVersion.v1 => 'PUT',
                          ApiVersion.v2 => 'POST',
                        },
                        headers: {'Authorization': 'Bearer ${user.jwt}'},
                      ),
                    ),
                  ),
                  throwsA(
                    isA<DioException>().having(
                      (e) => e.response?.statusCode,
                      'status',
                      400,
                    ),
                  ),
                );
              }

              final created = await writes.create(
                NewTask(
                  projectId: projectId,
                  title: 'With\u0000 a NUL',
                  description: '<p>Pasted\u0000 text</p>',
                ),
              );
              expect(created.title, 'With a NUL');
              expect(created.description, '<p>Pasted text</p>');

              final changed = await writes.update(
                created.id,
                const TaskChanges(title: 'Still\u0000 none'),
              );
              expect(changed.title, 'Still none');
              final stored = await reads.read(created.id);
              expect(stored.title, 'Still none');
              expect(stored.description, '<p>Pasted text</p>');
            });

            test('reminders set as absolute and relative ones, the server '
                'computing the relative instants, then cleared', () async {
              final due = DateTime.utc(2030, 1, 2, 3, 4, 5);
              final absolute = DateTime.utc(2030, 1, 1, 18);
              final task = await writes.create(
                NewTask(projectId: projectId, title: 'Remind me', dueDate: due),
              );

              final set = await writes.update(
                task.id,
                TaskChanges(
                  reminders: [
                    TaskReminder(reminder: absolute),
                    const TaskReminder(
                      relativePeriod: Duration(hours: -1),
                      relativeTo: ReminderRelativeTo.dueDate,
                    ),
                    const TaskReminder(relativeTo: ReminderRelativeTo.dueDate),
                    // No start date: kept, without an instant.
                    const TaskReminder(
                      relativePeriod: Duration(hours: 2),
                      relativeTo: ReminderRelativeTo.startDate,
                    ),
                  ],
                ),
              );

              final expected = unorderedEquals([
                TaskReminder(reminder: absolute),
                TaskReminder(
                  reminder: due.subtract(const Duration(hours: 1)),
                  relativePeriod: const Duration(hours: -1),
                  relativeTo: ReminderRelativeTo.dueDate,
                ),
                TaskReminder(
                  reminder: due,
                  relativeTo: ReminderRelativeTo.dueDate,
                ),
                const TaskReminder(
                  relativePeriod: Duration(hours: 2),
                  relativeTo: ReminderRelativeTo.startDate,
                ),
              ]);
              expect(set.reminders, expected);
              expect((await reads.read(task.id)).reminders, expected);

              final cleared = await writes.update(
                task.id,
                const TaskChanges(reminders: []),
              );
              expect(cleared.reminders, isEmpty);
              expect((await reads.read(task.id)).reminders, isEmpty);
            });

            // The update answers with the list as sent; the read-back shows
            // what was stored.
            test('reminders on the same instant are stored once', () async {
              final due = DateTime.utc(2030, 1, 2, 3, 4, 5);
              final task = await writes.create(
                NewTask(projectId: projectId, title: 'Twice', dueDate: due),
              );
              final hourBefore = due.subtract(const Duration(hours: 1));

              final response = await writes.update(
                task.id,
                TaskChanges(
                  reminders: [
                    TaskReminder(reminder: hourBefore),
                    TaskReminder(reminder: hourBefore),
                    const TaskReminder(
                      relativePeriod: Duration(hours: -1),
                      relativeTo: ReminderRelativeTo.dueDate,
                    ),
                  ],
                ),
              );

              final stored = (await reads.read(task.id)).reminders;
              expect(stored, hasLength(1));
              expect(stored.single.reminder, hourBefore);
              expect(stored.single.relativeTo, ReminderRelativeTo.dueDate);
              expect(response.reminders, stored);
            });

            // Every reminder relative to a cleared date falls on the zero
            // instant, where the server keeps one. The update answers with
            // both; the read-back shows what was stored.
            test('clearing the date of two relative reminders leaves the '
                'one the server kept', () async {
              final due = DateTime.utc(2030, 1, 2, 3, 4, 5);
              final task = await writes.create(
                NewTask(
                  projectId: projectId,
                  title: 'Undated',
                  dueDate: due,
                  reminders: const [
                    TaskReminder(relativeTo: ReminderRelativeTo.dueDate),
                    TaskReminder(
                      relativePeriod: Duration(days: -1),
                      relativeTo: ReminderRelativeTo.dueDate,
                    ),
                  ],
                ),
              );
              expect(task.reminders, hasLength(2));

              final cleared = await writes.update(
                task.id,
                const TaskChanges(dueDate: DateChange.clear()),
              );

              final stored = (await reads.read(task.id)).reminders;
              expect(stored, hasLength(1));
              expect(stored.single.reminder, isNull);
              expect(cleared.reminders, stored);
            });

            test('create with reminders', () async {
              final due = DateTime.utc(2030, 1, 2, 3, 4, 5);
              final absolute = DateTime.utc(2030, 1, 1, 18);

              final created = await writes.create(
                NewTask(
                  projectId: projectId,
                  title: 'Created with reminders',
                  dueDate: due,
                  reminders: [
                    TaskReminder(reminder: absolute),
                    const TaskReminder(
                      relativePeriod: Duration(days: -1),
                      relativeTo: ReminderRelativeTo.dueDate,
                    ),
                  ],
                ),
              );

              final expected = unorderedEquals([
                TaskReminder(reminder: absolute),
                TaskReminder(
                  reminder: due.subtract(const Duration(days: 1)),
                  relativePeriod: const Duration(days: -1),
                  relativeTo: ReminderRelativeTo.dueDate,
                ),
              ]);
              expect(created.reminders, expected);
              expect((await reads.read(created.id)).reminders, expected);
            });
          });
        }
      });
    }
  });
}
