import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/task_edits.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

// The sync engine against the outbox: a pull must not clobber a queued
// change, show a queued delete, or purge a row whose op is still queued.
void main() {
  late AppDatabase db;
  late FakeSyncClient client;
  late DateTime now;
  final base = DateTime.utc(2026, 10, 10, 9);
  final edited = DateTime.utc(2026, 10, 10, 12);
  final monday = DateTime.utc(2026, 10, 12, 9);
  const done = TaskChanges(done: true);

  List<Task> tasks() => [
    sampleTask(id: 1, title: 'One', due: monday, updated: base),
    sampleTask(id: 2, title: 'Two', updated: base),
    sampleTask(id: 3, title: 'Three', updated: base),
    sampleTask(id: 4, title: 'Four', projectId: 2, updated: base),
  ];

  DefaultSyncEngine engine() {
    final engine = DefaultSyncEngine(
      db: db,
      client: client,
      perPage: 50,
      now: () => now,
    );
    addTearDown(engine.dispose);
    return engine;
  }

  Future<void> queue(int id, TaskChanges changes) async {
    expect(await db.outboxDao.queueUpdate(id, changes, now: now), isTrue);
  }

  Task serverTask(int id) => client.allTasks.singleWhere((t) => t.id == id);

  void editOnServer(int id, Task Function(Task task) edit) {
    client.allTasks = [
      for (final task in client.allTasks)
        if (task.id == id) edit(task) else task,
    ];
  }

  setUp(() async {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 10, 12, 30);
    client = FakeSyncClient()
      ..allProjects = [
        sampleProject(id: 1, title: 'Work', position: 1),
        sampleProject(id: 2, title: 'Home', position: 2),
      ]
      ..allTasks = tasks();
    await engine().ensureInitialSync();
    expect(await db.tasksDao.count(), 4);
  });

  test(
    "a pull keeps the fields of a queued change over the server's",
    () async {
      await queue(1, done);
      editOnServer(
        1,
        (task) => copyTask(task, title: 'One, renamed', updated: edited),
      );

      await engine().refresh();

      final one = (await db.tasksDao.find(1))!;
      expect(one.title, 'One, renamed');
      expect(one.done, isTrue);
      expect(one.doneAt, now);
      expect(one.updated, edited);
      expect(
        decodeTaskChanges((await db.tasksDao.findRow(1))!.pendingChanges!),
        done,
      );
      expect(await db.outboxDao.count(), 1);
    },
  );

  test('the full pull keeps them too', () async {
    await queue(1, const TaskChanges(done: true, isFavorite: true));
    editOnServer(1, (task) => copyTask(task, dueDate: null, updated: edited));

    await engine().fullResync();

    final one = (await db.tasksDao.find(1))!;
    expect(one.dueDate, isNull);
    expect(one.done, isTrue);
    expect(one.isFavorite, isTrue);
    expect(await db.tasksDao.count(), 4);
  });

  test(
    'a queued delete stays hidden through the pull and is never brought back',
    () async {
      expect(await db.outboxDao.queueDelete(2, now: now), isTrue);
      editOnServer(
        2,
        (task) => copyTask(task, title: 'Two, edited', updated: edited),
      );

      await engine().refresh();

      expect(await db.tasksDao.find(2), isNull);
      final row = (await db.tasksDao.findRow(2))!;
      expect(row.pendingDelete, isTrue);
      expect(row.title, 'Two, edited');
      expect(await db.tasksDao.count(), 4);
      expect(await db.outboxDao.count(), 1);

      // The server no longer has it either (deleted on the web meanwhile): the
      // full pull leaves the row to the queued delete.
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id != 2) task,
      ];
      await engine().fullResync();

      expect((await db.tasksDao.findRow(2))!.pendingDelete, isTrue);
      expect(await db.outboxDao.count(), 1);
    },
  );

  test(
    'the count probe counts a queued delete as the server still has it',
    () async {
      expect(await db.outboxDao.queueDelete(2, now: now), isTrue);
      client.requests.clear();

      await engine().refresh();

      // Four tasks on both sides: no project is counted.
      expect(
        client.requests.where((r) => r.contains('per_page=1 ')),
        hasLength(1),
      );
      expect(await db.tasksDao.countNotInProjects([]), 4);
      expect(await db.tasksDao.find(2), isNull);
    },
  );

  test(
    'a reconcile keeps a row with a queued op the server did not return',
    () async {
      await queue(3, done);
      // Deleted on the web: task 1 goes, task 3 stays for its queued op.
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id != 1 && task.id != 3) task,
      ];

      await engine().refresh();

      expect(await db.tasksDao.find(1), isNull);
      expect((await db.tasksDao.find(3))!.done, isTrue);
      expect(await db.outboxDao.count(), 1);
    },
  );

  test(
    'the full pull keeps a row with a queued op the server did not return',
    () async {
      await queue(3, done);
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id != 3) task,
      ];

      await engine().fullResync();

      expect((await db.tasksDao.find(3))!.done, isTrue);
      expect(await db.tasksDao.count(), 4);
    },
  );

  test('a removed project keeps the task with a queued op', () async {
    await queue(4, done);
    client
      ..allProjects = [sampleProject(id: 1, title: 'Work', position: 1)]
      ..allTasks = [
        for (final task in client.allTasks)
          if (task.projectId != 2) task,
      ];

    await engine().refresh();

    expect((await db.tasksDao.find(4))!.done, isTrue);
    expect((await db.projectsDao.loadAll()).map((p) => p.id), [1]);
  });

  test("once sent, the next pull takes the server's row as it is", () async {
    await queue(1, done);
    final write = FakeWriteClient(clock: () => now)
      ..serverTasks[1] = serverTask(1);
    final sync = RecordingSyncEngine();
    final sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: client,
      sync: sync,
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    await sender.drain();
    expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
    // The web undid it afterwards.
    editOnServer(
      1,
      (task) => copyTask(task, done: false, doneAt: null, updated: edited),
    );

    await engine().refresh();

    expect((await db.tasksDao.find(1))!.done, isFalse);
  });
}
