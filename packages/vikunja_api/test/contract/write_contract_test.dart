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
        late int labelId;

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
          seeder = _Seeder(dio, connection, user);
          final runId = Random.secure().nextInt(1 << 16).toRadixString(16);
          final identifier = 'CW${runId.toUpperCase()}';
          projectId = await seeder.create('/projects', {
            'title': 'Write contract',
            'identifier': identifier,
          });
          labelId = await seeder.create('/labels', {
            'title': 'kept',
            'hex_color': 'e8323c',
          });
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            late _Seed seed;
            late TasksWritePort writes;
            late TasksPort reads;

            setUpAll(() async {
              expect(connection.apiVersions, contains(apiVersion));
              seed = await seeder.tasks(projectId, labelId);
              final only = onlyVersion(connection, apiVersion);
              final authenticated = createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(user.jwt),
              );
              writes = createWriteClient(
                dio: authenticated,
                connection: only,
              ).tasks;
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

            test('delete, then delete again', () async {
              await writes.delete(seed.doomedId);

              await expectLater(
                reads.read(seed.doomedId),
                throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
              );
              await expectLater(writes.delete(seed.doomedId), completes);
            });
          });
        }
      });
    }
  });
}
