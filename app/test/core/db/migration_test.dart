import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import 'generated/schema.dart';

void main() {
  test('v1 → v2 keeps the rows, adds the outbox and the pending '
      'columns', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute(
        'INSERT INTO projects (id, title, description, identifier, hex_color, '
        'parent_project_id, is_archived, is_favorite, position, owner_id, '
        'created, updated) '
        "VALUES (7, 'Work', '', '', '', 0, 0, 0, 1.0, NULL, NULL, NULL)",
      )
      ..execute(
        'INSERT INTO tasks (id, project_id, title, description, done, done_at, '
        'due_date, start_date, end_date, priority, percent_done, hex_color, '
        'identifier, "index", is_favorite, position, repeat_after, '
        'repeat_mode, bucket_id, created_by_id, created, updated, '
        'sync_run_id) '
        "VALUES (1, 7, 'Keep me', '', 0, NULL, 1760000000000, NULL, NULL, 3, "
        "0.5, 'ff0000', '-1', 1, 1, 2.0, 0, 0, 0, NULL, NULL, 1759000000000, "
        "'run-1')",
      )
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-10-10T12:00:00.000Z')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 2);

    final task = (await db.tasksDao.find(1))!;
    expect(task.title, 'Keep me');
    expect(task.projectId, 7);
    expect(task.dueDate, DateTime.utc(2025, 10, 9, 8, 53, 20));
    expect(task.priority, TaskPriority.high);
    expect(task.percentDone, 0.5);
    expect(task.hexColor, 'ff0000');
    expect(task.isFavorite, isTrue);
    expect(task.position, 2);
    final row = (await db.tasksDao.findRow(1))!;
    expect(row.syncRunId, 'run-1');
    expect(row.pendingChanges, isNull);
    expect(row.pendingDelete, isFalse);
    expect((await db.projectsDao.loadAll()).single.title, 'Work');
    expect(
      (await db.syncStateDao.readAll())['last_synced_at'],
      '2026-10-10T12:00:00.000Z',
    );
    expect(await db.outboxDao.count(), 0);
    expect(
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: DateTime.utc(2026, 10, 11),
      ),
      isTrue,
    );
    expect(await db.outboxDao.count(), 1);
  });
}
