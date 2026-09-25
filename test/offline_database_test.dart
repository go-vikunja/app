import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vikunja_app/data/local/offline_codec.dart';
import 'package:vikunja_app/data/local/offline_database.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late OfflineDatabase db;

  setUp(() async {
    final raw = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await database.execute(
            'CREATE TABLE cached_tasks (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
          );
          await database.execute(
            'CREATE TABLE cached_projects (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
          );
          await database.execute(
            'CREATE TABLE cached_user (id INTEGER PRIMARY KEY, json TEXT NOT NULL)',
          );
          await database.execute(
            'CREATE TABLE mutations (id INTEGER PRIMARY KEY AUTOINCREMENT, op TEXT NOT NULL, payload TEXT NOT NULL)',
          );
        },
      ),
    );
    db = OfflineDatabase(database: raw);
    await raw.delete('cached_tasks');
    await raw.delete('cached_projects');
    await raw.delete('cached_user');
    await raw.delete('mutations');
  });

  tearDown(() async {
    await db.close();
  });

  Task makeTask({int id = 1, bool done = false, DateTime? due}) {
    return Task(
      id: id,
      title: 'Task $id',
      done: done,
      dueDate: due,
      createdBy: User(username: 'u'),
      projectId: 10,
    );
  }

  test('enqueue keeps FIFO order', () async {
    await db.enqueue('task.create', {'id': 1});
    await db.enqueue('task.update', {'id': 1});
    await db.enqueue('task.delete', {'id': 2});

    final pending = await db.pending();
    expect(pending.map((m) => m.op).toList(), [
      'task.create',
      'task.update',
      'task.delete',
    ]);
  });

  test('filter cache hides done tasks', () async {
    await db.upsertTask(makeTask(id: 1, done: false));
    await db.upsertTask(makeTask(id: 2, done: true));

    final open = await db.tasksByFilter('done = false');
    expect(open.map((t) => t.id), [1]);
  });

  test('remap updates later mutations', () async {
    await db.upsertTask(makeTask(id: -1));
    await db.enqueue('task.update', {
      'task': {'id': -1, 'title': 'x'},
    });

    await db.remapId(kind: 'task', from: -1, to: 42);

    final cached = await db.getTask(42);
    expect(cached?.id, 42);
    expect(await db.getTask(-1), isNull);

    final pending = await db.pending();
    expect(pending.single.payload['task']['id'], 42);
  });

  test('local delete drops queued creates', () async {
    await db.enqueue('task.create', {
      'task': {'id': -3},
    });
    await db.deleteMutationsForTask(-3);
    expect(await db.pending(), isEmpty);
  });

  test('taskMatchesFilter due date', () {
    final withDue = makeTask(due: DateTime(2026, 1, 2));
    final withoutDue = makeTask();
    expect(
      taskMatchesFilter(withDue, 'done = false && due_date > now'),
      isTrue,
    );
    expect(
      taskMatchesFilter(withoutDue, 'done = false && due_date > now'),
      isFalse,
    );
  });
}
