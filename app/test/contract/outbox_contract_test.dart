@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// Each API version gets a user of its own with a task carrying everything a
// v1 full replace could lose (the user as assignee, an absolute and a
// relative reminder, a label), a daily repeating task and a task to delete.
typedef _Seed = ({
  int richId,
  int repeatingId,
  int doomedId,
  int labelId,
  DateTime repeatingDue,
});

Future<_Seed> _seed(Seeder seeder, TestUser user) async {
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
  final projectId = await seeder.create('/projects', {'title': 'Outbox'});
  final labelId = await seeder.create('/labels', {'title': 'kept'});
  final path = '/projects/$projectId/tasks';
  final richId = await seeder.create(path, {
    'title': 'Water the plants',
    'description': '<p>Every pot</p>',
    'due_date': reminderAt.add(const Duration(days: 1)).toIso8601String(),
    'priority': 3,
    'reminders': [
      {'reminder': reminderAt.toIso8601String()},
      {'relative_period': -600, 'relative_to': 'due_date'},
    ],
  });
  await seeder.post('/tasks/$richId/assignees', {'user_id': user.id});
  await seeder.post('/tasks/$richId/labels', {'label_id': labelId});
  final repeatingId = await seeder.create(path, {
    'title': 'Daily',
    'due_date': repeatingDue.toIso8601String(),
    'repeat_after': 86400,
  });
  final doomedId = await seeder.create(path, {'title': 'Doomed'});
  return (
    richId: richId,
    repeatingId: repeatingId,
    doomedId: doomedId,
    labelId: labelId,
    repeatingDue: repeatingDue,
  );
}

/// The real write client behind a connection that drops the next
/// [failNext] requests before they leave the device.
final class _FlakyWriteClient implements VikunjaWriteClient {
  new(this._real);

  final VikunjaWriteClient _real;
  int failNext = 0;
  int attempts = 0;

  @override
  late final TasksWritePort tasks = _FlakyTasks(this);
}

final class _FlakyTasks implements TasksWritePort {
  new(this._client);

  final _FlakyWriteClient _client;

  void _maybeFail() {
    _client.attempts++;
    if (_client.failNext > 0) {
      _client.failNext--;
      throw const NetworkFailure(NetworkProblem.unreachable);
    }
  }

  @override
  Future<Task> update(int id, TaskChanges changes) {
    _maybeFail();
    return _client._real.tasks.update(id, changes);
  }

  @override
  Future<void> delete(int id) {
    _maybeFail();
    return _client._real.tasks.delete(id);
  }
}

Matcher _within1s(DateTime expected) => predicate<DateTime?>(
  (actual) =>
      actual != null &&
      actual.difference(expected).abs() < const Duration(seconds: 1),
  'within a second of $expected',
);

Future<void> _until(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

/// A drain whose transient failures are retried: the SQLite test server
/// answers a lost write race with a 500 (another contract file seeding at
/// the same time is enough), which the sender retries on its own timer.
Future<void> _drainFully(OutboxSender sender, AppDatabase db) async {
  await sender.drain();
  await _until(() async => await db.outboxDao.count() == 0);
}

void main() {
  group('outbox against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      test('local writes reach the server over ${apiVersion.pathSegment} '
          'and the answers land in the rows', () async {
        final user = await registerAndLogin(dio, connection);
        final seed = await _seed(Seeder(dio, connection, user), user);
        final only = onlyApiVersion(connection, apiVersion);
        final authenticated = createAuthenticatedDio(
          base: dio,
          connection: only,
          tokens: StaticJwt(user.jwt),
        );
        final reads = createReadClient(dio: authenticated, connection: only);
        final writes = _FlakyWriteClient(
          createWriteClient(dio: authenticated, connection: only),
        );
        final db = testDatabase();
        final engine = DefaultSyncEngine(
          db: db,
          client: reads,
          perPage: only.info.maxItemsPerPage,
          currentUser: AccountApi(authenticated, only).currentUser,
        );
        addTearDown(engine.dispose);
        final sender = OutboxSender(
          db: db,
          writeClient: writes,
          readClient: reads,
          sync: engine,
        );
        addTearDown(sender.dispose);
        final repository = LocalTaskRepository(db, engine, sender);
        addTearDown(repository.dispose);

        await engine.ensureInitialSync();
        expect(await db.tasksDao.count(), 3);

        void expectIntact(Task task) {
          expect(task.assignees.map((u) => u.id), [user.id]);
          expect(task.reminders, hasLength(2));
          expect(
            task.reminders.map((r) => r.relativeTo),
            containsAll([null, ReminderRelativeTo.dueDate]),
          );
          expect(task.labels.map((l) => l.id), [seed.labelId]);
          expect(task.title, 'Water the plants');
          expect(task.description, '<p>Every pot</p>');
          expect(task.priority, TaskPriority.high);
        }

        // Done: on screen at once, then on the server; the response fills
        // done_at, and nothing the v1 full replace could lose is lost.
        await repository.setDone(seed.richId, done: true);
        expect((await db.tasksDao.find(seed.richId))!.done, isTrue);
        await _drainFully(sender, db);

        expect(await db.outboxDao.count(), 0);
        final rich = (await db.tasksDao.find(seed.richId))!;
        expect(rich.done, isTrue);
        expect(rich.doneAt, isNotNull);
        expectIntact(rich);
        final richOnServer = await reads.tasks.read(seed.richId);
        expect(richOnServer.done, isTrue);
        expect(richOnServer.doneAt, rich.doneAt);
        expect(richOnServer.updated, rich.updated);
        expectIntact(richOnServer);

        // Favourite.
        await repository.setFavorite(seed.richId, favorite: true);
        await _drainFully(sender, db);

        expect((await db.tasksDao.find(seed.richId))!.isFavorite, isTrue);
        expect((await reads.tasks.read(seed.richId)).isFavorite, isTrue);
        expect(await db.outboxDao.count(), 0);

        // Offline for the first attempt: the op waits for its backoff and
        // gets through on the retry.
        writes.failNext = 1;
        final attemptsBefore = writes.attempts;
        await repository.setDone(seed.richId, done: false);
        await sender.drain();

        expect(sender.state, OutboxSenderState.waiting);
        final waiting = (await db.outboxDao.all()).single;
        expect(waiting.state, OutboxState.pending.name);
        expect(waiting.attempts, 1);
        expect(waiting.nextAttemptAt, isNotNull);
        expect((await db.tasksDao.find(seed.richId))!.done, isFalse);
        await _until(() async => await db.outboxDao.count() == 0);
        expect(writes.attempts, greaterThanOrEqualTo(attemptsBefore + 2));
        expect((await reads.tasks.read(seed.richId)).done, isFalse);
        final undone = (await db.tasksDao.find(seed.richId))!;
        expect(undone.done, isFalse);
        expect(undone.doneAt, isNull);
        expectIntact(undone);

        // A repeating task comes back open with the server's next date.
        final repeatingBefore = (await db.tasksDao.find(seed.repeatingId))!;
        await repository.setDone(seed.repeatingId, done: true);
        expect((await db.tasksDao.find(seed.repeatingId))!.done, isTrue);
        await _drainFully(sender, db);

        final daily = (await db.tasksDao.find(seed.repeatingId))!;
        expect(daily.done, isFalse);
        expect(
          daily.dueDate,
          _within1s(seed.repeatingDue.add(const Duration(days: 1))),
        );
        expect(
          (await reads.tasks.read(seed.repeatingId)).dueDate,
          daily.dueDate,
        );

        // Undo takes the previous occurrence back: the server does not
        // shift an open task again, on either version.
        await repository.undoDone(repeatingBefore);
        expect(
          (await db.tasksDao.find(seed.repeatingId))!.dueDate,
          _within1s(seed.repeatingDue),
        );
        await _drainFully(sender, db);

        final restored = (await db.tasksDao.find(seed.repeatingId))!;
        expect(restored.done, isFalse);
        expect(restored.dueDate, _within1s(seed.repeatingDue));
        expect(
          (await reads.tasks.read(seed.repeatingId)).dueDate,
          restored.dueDate,
        );

        // Delete: hidden at once, gone on both sides after the drain.
        await repository.deleteTask(seed.doomedId);
        expect(await db.tasksDao.find(seed.doomedId), isNull);
        await _drainFully(sender, db);

        expect(await db.tasksDao.findRow(seed.doomedId), isNull);
        await expectLater(
          reads.tasks.read(seed.doomedId),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );

        // The pull after the drain agrees with the server.
        await engine.refresh();
        expect(await db.tasksDao.count(), 2);
        expect(await db.outboxDao.count(), 0);
        expect(sender.state, OutboxSenderState.idle);
      });
    }
  });
}
