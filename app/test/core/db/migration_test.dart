import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

import '../../helpers/sample_data.dart';
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

    await verifier.migrateAndValidate(db, 3);

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

  test('v2 → v3 keeps the queued ops, adds the remap table and the '
      'sent_at column', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase
      ..execute(
        'INSERT INTO tasks (id, project_id, title, description, done, done_at, '
        'due_date, start_date, end_date, priority, percent_done, hex_color, '
        'identifier, "index", is_favorite, position, repeat_after, '
        'repeat_mode, bucket_id, created_by_id, created, updated, '
        'sync_run_id, pending_changes, pending_delete) '
        "VALUES (1, 7, 'Queued', '', 1, 1760100000000, NULL, NULL, NULL, 0, "
        "0.0, '', '-1', 1, 0, 0.0, 0, 0, 0, NULL, NULL, 1759000000000, "
        "'run-1', '{\"done\":true}', 0)",
      )
      ..execute(
        'INSERT INTO outbox (id, sequence, kind, task_id, payload, created_at, '
        'attempts, next_attempt_at, last_attempt_at, state, last_error) '
        "VALUES ('op-1', 1, 'updateTask', 1, '{\"done\":true}', "
        "1760100000000, 1, 1760100002000, 1760100000000, 'pending', "
        "'{\"kind\":\"network\",\"problem\":\"timeout\"}')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);

    final op = (await db.outboxDao.all()).single;
    expect(op.id, 'op-1');
    expect(op.kind, 'updateTask');
    expect(op.state, OutboxState.pending.name);
    expect(op.attempts, 1);
    expect(op.sentAt, isNull);
    expect(decodeTaskChanges(op.payload), const TaskChanges(done: true));
    expect((await db.tasksDao.find(1))!.done, isTrue);
    expect((await db.outboxDao.nextPending())!.id, 'op-1');

    final localId = await db.outboxDao.queueCreate(
      const NewTask(projectId: 7, title: 'Created after the upgrade'),
      now: DateTime.utc(2026, 10, 11),
    );
    expect(localId, -1);
    expect((await db.tasksDao.find(-1))!.title, 'Created after the upgrade');
    final create = (await db.outboxDao.all()).last;
    await db.outboxDao.completeCreate(
      create.id,
      sampleTask(id: 50, title: 'Created after the upgrade', projectId: 7),
      at: DateTime.utc(2026, 10, 11),
    );
    expect(await db.tasksDao.resolveId(-1), 50);
    expect(await db.tasksDao.find(-1), isNull);
    expect((await db.tasksDao.find(50))!.title, 'Created after the upgrade');
    expect(await db.outboxDao.count(), 1);
  });

  test('v3 → v4 keeps the tasks with their reminders and remaps and adds '
      'the scheduled notifications', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase
      ..execute(
        'INSERT INTO tasks (id, project_id, title, description, done, done_at, '
        'due_date, start_date, end_date, priority, percent_done, hex_color, '
        'identifier, "index", is_favorite, position, repeat_after, '
        'repeat_mode, bucket_id, created_by_id, created, updated, '
        'sync_run_id, pending_changes, pending_delete) '
        "VALUES (50, 7, 'Remind me', '', 0, NULL, 1760000000000, NULL, NULL, "
        "0, 0.0, '', '-1', 1, 0, 0.0, 0, 0, 0, NULL, NULL, 1759000000000, "
        "'run-1', NULL, 0)",
      )
      ..execute(
        'INSERT INTO task_reminders (task_id, ordinal, reminder, '
        'relative_period, relative_to) '
        'VALUES (50, 0, 1759990000000, 0, NULL), '
        "(50, 1, 1759996400000, -3600, 'due_date')",
      )
      ..execute(
        'INSERT INTO task_id_remaps (local_id, server_id, at) '
        'VALUES (-1, 50, 1759500000000)',
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);

    final task = (await db.tasksDao.find(50))!;
    expect(task.title, 'Remind me');
    expect(task.reminders, [
      TaskReminder(reminder: DateTime.utc(2025, 10, 9, 6, 6, 40)),
      TaskReminder(
        reminder: DateTime.utc(2025, 10, 9, 7, 53, 20),
        relativePeriod: const Duration(hours: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      ),
    ]);
    expect(await db.tasksDao.resolveId(-1), 50);
    expect(await db.scheduledNotificationsDao.all(), isEmpty);
    await db.scheduledNotificationsDao.replaceAll([
      ScheduledNotificationRow(
        key: '50:reminder:0',
        osId: 1234,
        taskId: 50,
        kind: 'reminder',
        fireAt: DateTime.utc(2025, 10, 9, 6, 6, 40),
        title: 'Remind me',
        body: 'Reminder',
        exact: false,
      ),
    ]);
    expect(await db.scheduledNotificationsDao.osIds(), {1234});
    expect((await db.scheduledNotificationsDao.all()).single.exact, isFalse);
  });
}
