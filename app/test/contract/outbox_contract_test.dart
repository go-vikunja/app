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
// relative reminder, a label), a daily repeating task, a task to delete and
// a second project, with an identifier prefix, to move a task into.
typedef _Seed = ({
  int projectId,
  int otherProjectId,
  String otherIdentifier,
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
  // Identifiers are unique across the server, so the user's random suffix
  // keeps runs apart.
  final otherIdentifier = 'M${user.username.substring(4).toUpperCase()}';
  final otherProjectId = await seeder.create('/projects', {
    'title': 'Elsewhere',
    'identifier': otherIdentifier,
  });
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
    projectId: projectId,
    otherProjectId: otherProjectId,
    otherIdentifier: otherIdentifier,
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

  @override
  LabelsWritePort get labels => _real.labels;
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
  Future<Task> create(NewTask task) {
    _maybeFail();
    return _client._real.tasks.create(task);
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
      group('over ${apiVersion.pathSegment}', () {
        late TestUser user;
        late _Seed seed;
        late VikunjaReadClient reads;
        late _FlakyWriteClient writes;
        late AppDatabase db;
        late DefaultSyncEngine engine;
        late OutboxSender sender;
        late LocalTaskRepository repository;

        // One user per version: /register and /login share the limiter.
        setUpAll(() async {
          user = await registerAndLogin(dio, connection);
          seed = await _seed(Seeder(dio, connection, user), user);
          final only = onlyApiVersion(connection, apiVersion);
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );
          reads = createReadClient(dio: authenticated, connection: only);
          writes = _FlakyWriteClient(
            createWriteClient(dio: authenticated, connection: only),
          );
          db = testDatabase();
          engine = DefaultSyncEngine(
            db: db,
            client: reads,
            perPage: only.info.maxItemsPerPage,
            currentUser: AccountApi(
              authenticated,
              only,
            ).currentUserWithSettings,
          );
          addTearDown(engine.dispose);
          sender = OutboxSender(
            db: db,
            writeClient: writes,
            readClient: reads,
            sync: engine,
          );
          addTearDown(sender.dispose);
          repository = LocalTaskRepository(db, engine, sender);
          addTearDown(repository.dispose);
          await engine.ensureInitialSync();
        });

        test('local writes reach the server and the answers land in the '
            'rows', () async {
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

        test('a task created offline reaches the server with its fields, the '
            'row moves to the server id, edits before the send go with the '
            'create, a delete before the send cancels it, and a move and a '
            'repeat removal come back applied', () async {
          final today = DateTime.now().toUtc();
          final due = DateTime.utc(today.year, today.month, today.day + 3, 9);
          final draft = NewTask(
            projectId: seed.projectId,
            title: 'Created offline',
            description: '<p>While offline</p>',
            dueDate: due,
            priority: TaskPriority.high,
            percentDone: 0.5,
            hexColor: 'ff4136',
            repeatAfter: const Duration(days: 30),
            isFavorite: true,
          );

          // Offline for the first attempt: the row is there at once, the
          // create waits for its backoff and gets through on the retry.
          writes.failNext = 1;
          final localId = await repository.createTask(draft);
          final watched = <Task?>[];
          final subscription = repository
              .watchTask(localId)
              .listen(watched.add);
          addTearDown(subscription.cancel);
          expect(localId, isNegative);
          expect((await db.tasksDao.find(localId))!.title, 'Created offline');
          expect(
            (await db.tasksDao.loadProjectTasks(
              seed.projectId,
              showDone: false,
            )).first.id,
            localId,
          );
          await sender.drain();
          expect(sender.state, OutboxSenderState.waiting);
          expect((await db.outboxDao.all()).single.kind, 'createTask');
          await _until(() async => await db.outboxDao.count() == 0);
          // Joins the retry's run until its refresh is through: the create's
          // answer has an `updated` with sub-second digits that the server
          // does not store, and the refresh replaces it.
          await sender.drain();

          final serverId = await db.tasksDao.resolveId(localId);
          expect(serverId, isPositive);
          expect(await db.tasksDao.findRow(localId), isNull);
          final created = (await db.tasksDao.find(serverId))!;
          expect(created.title, 'Created offline');
          expect(created.description, '<p>While offline</p>');
          expect(created.dueDate, _within1s(due));
          expect(created.priority, TaskPriority.high);
          expect(created.percentDone, 0.5);
          expect(created.hexColor, 'ff4136');
          expect(created.repeatAfter, const Duration(days: 30));
          expect(created.isFavorite, isTrue);
          expect(created.index, greaterThan(0));
          expect(created.identifier, isNotEmpty);
          expect(created.updated, isNotNull);
          final onServer = await reads.tasks.read(serverId);
          expect(onServer.title, created.title);
          expect(onServer.dueDate, created.dueDate);
          expect(onServer.priority, created.priority);
          expect(onServer.percentDone, created.percentDone);
          expect(onServer.hexColor, created.hexColor);
          expect(onServer.repeatAfter, created.repeatAfter);
          expect(onServer.isFavorite, isTrue);
          expect(onServer.identifier, created.identifier);
          expect(onServer.index, created.index);
          expect(onServer.updated, created.updated);
          await _until(() async => watched.last?.id == serverId);
          expect(watched.first!.id, localId);

          // Create and edit before the send: one request.
          sender.pause();
          var attemptsBefore = writes.attempts;
          final editedId = await repository.createTask(
            NewTask(projectId: seed.projectId, title: 'Draft'),
          );
          await repository.updateTask(
            editedId,
            TaskChanges(
              title: 'Edited before the send',
              priority: TaskPriority.urgent.value,
            ),
          );
          await sender.resume();
          await _until(() async => await db.outboxDao.count() == 0);

          expect(writes.attempts, attemptsBefore + 1);
          final editedServerId = await db.tasksDao.resolveId(editedId);
          expect(editedServerId, isPositive);
          final edited = await reads.tasks.read(editedServerId);
          expect(edited.title, 'Edited before the send');
          expect(edited.priority, TaskPriority.urgent);

          // Create and delete before the send: no request.
          sender.pause();
          attemptsBefore = writes.attempts;
          final doomedId = await repository.createTask(
            NewTask(projectId: seed.projectId, title: 'Never sent'),
          );
          await repository.deleteTask(doomedId);
          await sender.resume();

          expect(writes.attempts, attemptsBefore);
          expect(await db.tasksDao.findRow(doomedId), isNull);
          expect(await db.outboxDao.count(), 0);

          // A move: the answer carries the new project's identifier.
          await repository.updateTask(
            serverId,
            TaskChanges(projectId: seed.otherProjectId),
          );
          expect(
            (await db.tasksDao.find(serverId))!.projectId,
            seed.otherProjectId,
          );
          await _drainFully(sender, db);

          final moved = (await db.tasksDao.find(serverId))!;
          expect(moved.projectId, seed.otherProjectId);
          expect(moved.identifier, '${seed.otherIdentifier}-${moved.index}');
          expect(moved.identifier, isNot(created.identifier));
          final movedOnServer = await reads.tasks.read(serverId);
          expect(movedOnServer.projectId, seed.otherProjectId);
          expect(movedOnServer.identifier, moved.identifier);
          expect(movedOnServer.index, moved.index);

          // The repeat removed.
          await repository.updateTask(
            serverId,
            const TaskChanges(
              repeatAfter: Duration.zero,
              repeatMode: RepeatMode.afterAmount,
            ),
          );
          expect((await db.tasksDao.find(serverId))!.repeats, isFalse);
          await _drainFully(sender, db);

          expect((await db.tasksDao.find(serverId))!.repeats, isFalse);
          expect((await reads.tasks.read(serverId)).repeatAfter, Duration.zero);

          // The pull after the drain agrees with the server.
          await engine.refresh();
          expect(await db.tasksDao.count(), 4);
          expect(await db.tasksDao.countInProject(seed.otherProjectId), 1);
          expect(await db.outboxDao.count(), 0);
          expect(sender.state, OutboxSenderState.idle);
        });

        test('a create whose answer was lost is adopted from the server by '
            'its title instead of being sent again', () async {
          final draft = NewTask(
            projectId: seed.projectId,
            title: 'Lost answer',
          );
          // The request reached the server; the answer did not come back.
          final onServer = await writes.tasks.create(draft);
          sender.pause();
          final attemptsBefore = writes.attempts;
          final localId = await repository.createTask(draft);
          final op = (await db.outboxDao.all()).single;
          await db.outboxDao.markUncertain(op.id, sentAt: DateTime.now());

          await sender.resume();
          await _until(() async => await db.outboxDao.count() == 0);

          expect(writes.attempts, attemptsBefore);
          expect(await db.tasksDao.resolveId(localId), onServer.id);
          expect(await db.tasksDao.findRow(localId), isNull);
          final adopted = (await db.tasksDao.find(onServer.id))!;
          expect(adopted.title, 'Lost answer');
          expect(adopted.identifier, onServer.identifier);
          await engine.refresh();
          final inProject = await reads.tasks.listInProject(
            seed.projectId,
            const TaskQuery(),
          );
          expect(
            inProject.items.where((task) => task.title == 'Lost answer'),
            hasLength(1),
          );
          expect(
            await db.tasksDao.countInProject(seed.projectId),
            inProject.items.length,
          );
          expect(await db.outboxDao.count(), 0);
          expect(sender.state, OutboxSenderState.idle);
        });

        test('a task created offline with a reminder, labelled and assigned '
            'before the send, reaches the server with all three; a label '
            'comes off and back on through the outbox; undoing a repeating '
            "task's done brings its reminder back", () async {
          final today = DateTime.now().toUtc();
          final due = DateTime.utc(today.year, today.month, today.day + 4, 9);
          const hourBefore = TaskReminder(
            relativePeriod: Duration(hours: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          );
          final beforeDue = due.subtract(const Duration(hours: 1));

          // Offline: the create, the label and the assignee wait together.
          sender.pause();
          final localId = await repository.createTask(
            NewTask(
              projectId: seed.projectId,
              title: 'Labelled offline',
              dueDate: due,
              reminders: const [hourBefore],
            ),
          );
          await repository.updateTask(
            localId,
            TaskChanges(
              labels: IdSetChange(added: {seed.labelId}),
              assignees: IdSetChange(added: {user.id}),
            ),
          );
          final offline = (await db.tasksDao.find(localId))!;
          expect(offline.labels.map((l) => l.id), [seed.labelId]);
          expect(offline.assignees.map((u) => u.id), [user.id]);
          expect(offline.reminders.single.reminder, beforeDue);
          expect((await db.outboxDao.all()).map((op) => op.kind), [
            'createTask',
            'updateTask',
          ]);

          await sender.resume();
          await _until(() async => await db.outboxDao.count() == 0);

          final serverId = await db.tasksDao.resolveId(localId);
          expect(serverId, isPositive);
          expect(await db.tasksDao.findRow(localId), isNull);
          void expectComplete(Task task) {
            expect(task.labels.map((l) => l.id), [seed.labelId]);
            expect(task.assignees.map((u) => u.id), [user.id]);
            expect(task.reminders, hasLength(1));
            expect(
              task.reminders.single.relativeTo,
              ReminderRelativeTo.dueDate,
            );
            expect(
              task.reminders.single.relativePeriod,
              hourBefore.relativePeriod,
            );
            expect(task.reminders.single.reminder, _within1s(beforeDue));
          }

          expectComplete(await reads.tasks.read(serverId));
          expectComplete((await db.tasksDao.find(serverId))!);

          // The label off and on again.
          await repository.updateTask(
            serverId,
            TaskChanges(labels: IdSetChange(removed: {seed.labelId})),
          );
          expect((await db.tasksDao.find(serverId))!.labels, isEmpty);
          await _drainFully(sender, db);

          expect((await reads.tasks.read(serverId)).labels, isEmpty);
          expect((await db.tasksDao.find(serverId))!.labels, isEmpty);

          await repository.updateTask(
            serverId,
            TaskChanges(labels: IdSetChange(added: {seed.labelId})),
          );
          await _drainFully(sender, db);

          expectComplete(await reads.tasks.read(serverId));
          expectComplete((await db.tasksDao.find(serverId))!);

          // A daily task with an absolute reminder: done moves the reminder
          // on with the date, the undo brings both back.
          final reminderAt = DateTime.utc(
            today.year,
            today.month,
            today.day + 2,
            7,
            30,
          );
          final dailyLocalId = await repository.createTask(
            NewTask(
              projectId: seed.projectId,
              title: 'Daily with a reminder',
              dueDate: due,
              repeatAfter: const Duration(days: 1),
              reminders: [TaskReminder(reminder: reminderAt)],
            ),
          );
          await _drainFully(sender, db);
          final dailyId = await db.tasksDao.resolveId(dailyLocalId);
          final previous = (await db.tasksDao.find(dailyId))!;
          expect(previous.reminders.single.reminder, _within1s(reminderAt));

          await repository.setDone(dailyId, done: true);
          await _drainFully(sender, db);

          final shifted = await reads.tasks.read(dailyId);
          expect(shifted.done, isFalse);
          expect(
            shifted.reminders.single.reminder,
            _within1s(reminderAt.add(const Duration(days: 1))),
          );

          await repository.undoDone(previous);
          expect(
            (await db.tasksDao.find(dailyId))!.reminders.single.reminder,
            _within1s(reminderAt),
          );
          await _drainFully(sender, db);

          final undone = await reads.tasks.read(dailyId);
          expect(undone.done, isFalse);
          expect(undone.dueDate, _within1s(due));
          expect(undone.reminders.single.reminder, _within1s(reminderAt));
          expect(
            (await db.tasksDao.find(dailyId))!.reminders.single.reminder,
            _within1s(reminderAt),
          );
          expect(await db.outboxDao.count(), 0);
          expect(sender.state, OutboxSenderState.idle);
        });
      });
    }
  });
}
