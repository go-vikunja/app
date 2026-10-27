import 'dart:convert';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

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

    await verifier.migrateAndValidate(db, 10);

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
    expect((await db.projectsDao.loadAll()).single.maxPermission, isNull);
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

    await verifier.migrateAndValidate(db, 10);

    final op = (await db.outboxDao.all()).single;
    expect(op.id, 'op-1');
    expect(op.kind, 'updateTask');
    expect(op.state, OutboxState.pending.name);
    expect(op.attempts, 1);
    expect(op.sentAt, isNull);
    expect(decodeTaskChanges(op.payload), const TaskChanges(done: true));
    expect((await db.tasksDao.find(1))!.done, isTrue);
    expect((await db.outboxDao.nextInLine())!.id, 'op-1');

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

    await verifier.migrateAndValidate(db, 10);

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

  test('v4 → v5 keeps the scheduled notifications and the sync state and '
      'adds the server notifications', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);
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
        'INSERT INTO scheduled_notifications (key, os_id, task_id, kind, '
        'fire_at, title, body, snoozed_until, snooze_original_fire_at, exact) '
        "VALUES ('50:due', 4321, 50, 'dueDate', 1760000000000, 'Remind me', "
        "'Due now', NULL, NULL, 1)",
      )
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-10-12T12:00:00.000Z')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    expect((await db.tasksDao.find(50))!.title, 'Remind me');
    final scheduled = (await db.scheduledNotificationsDao.all()).single;
    expect(scheduled.key, '50:due');
    expect(scheduled.osId, 4321);
    expect(scheduled.exact, isTrue);
    final state = await db.syncStateDao.readAll();
    expect(state[SyncStateKeys.lastSyncedAt], '2026-10-12T12:00:00.000Z');
    expect(state[SyncStateKeys.activitySyncedAt], isNull);
    expect(await db.serverNotificationsDao.count(), 0);
    await db.serverNotificationsDao.upsertAll([
      ServerNotification(
        id: 9,
        name: 'task.assigned',
        payload: const {
          'task': {'id': 50, 'title': 'Remind me'},
        },
        created: DateTime.utc(2026, 10, 12, 13),
      ),
    ], handled: false);
    final stored = (await db.serverNotificationsDao.find(9))!;
    expect(stored.taskId, 50);
    expect(stored.isRead, isFalse);
    expect(await db.serverNotificationsDao.unreadCount(), 1);
  });

  test('v5 → v6 keeps the tasks, the projects and the sync state and adds '
      'the list snapshots and preferences', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase
      ..execute(
        'INSERT INTO projects (id, title, description, identifier, hex_color, '
        'parent_project_id, is_archived, is_favorite, position, owner_id, '
        'created, updated) '
        "VALUES (7, 'Work', '', '', '', 0, 0, 0, 1.0, NULL, NULL, NULL)",
      )
      ..execute(
        'INSERT INTO project_views (id, project_id, title, kind, position, '
        'filter_json, bucket_configuration_mode, default_bucket_id, '
        'done_bucket_id) '
        'VALUES (70, 7, ?, ?, 100.0, ?, ?, 0, 0)',
        ['List', 'list', _listViewFilter, 'none'],
      )
      ..execute(
        'INSERT INTO tasks (id, project_id, title, description, done, done_at, '
        'due_date, start_date, end_date, priority, percent_done, hex_color, '
        'identifier, "index", is_favorite, position, repeat_after, '
        'repeat_mode, bucket_id, created_by_id, created, updated, '
        'sync_run_id, pending_changes, pending_delete) '
        "VALUES (60, 7, 'Parent', '', 0, NULL, NULL, NULL, NULL, "
        "0, 0.0, '', '-1', 1, 0, 0.0, 0, 0, 0, NULL, NULL, 1759000000000, "
        "'run-1', NULL, 0), "
        "(61, 7, 'Child', '', 0, NULL, NULL, NULL, NULL, "
        "0, 0.0, '', '-2', 2, 0, 0.0, 0, 0, 0, NULL, NULL, 1759000000000, "
        "'run-1', NULL, 0)",
      )
      ..execute(
        'INSERT INTO task_relations (task_id, other_task_id, kind) '
        "VALUES (60, 61, 'subtask'), (61, 60, 'parenttask')",
      )
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-10-13T12:00:00.000Z'), "
        "('last_full_sync_at', '2026-10-13T11:00:00.000Z')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    final parent = (await db.tasksDao.find(60))!;
    expect(parent.subtasks.map((task) => task.id), [61]);
    final project = (await db.projectsDao.loadAll()).single;
    expect(project.views.single.filter?.filter, 'done = false');
    expect(
      (await db.syncStateDao.readAll())[SyncStateKeys.lastSyncedAt],
      '2026-10-13T12:00:00.000Z',
    );
    expect(
      await db.syncStateDao.readAll(),
      isNot(contains(SyncStateKeys.lastFullSyncAt)),
      reason: 'the first run after the upgrade is a full one',
    );
    expect((await db.listSnapshotsDao.load('view:70')).loadedAt, isNull);
    await db.listSnapshotsDao.replace('view:70', {
      61: 1,
      60: 2,
    }, loadedAt: DateTime.utc(2026, 10, 13, 13));
    final snapshot = await db.listSnapshotsDao.load('view:70');
    expect(snapshot.positions, {61: 1, 60: 2});
    expect(snapshot.loadedAt, DateTime.utc(2026, 10, 13, 13));
    expect(await db.listPreferencesDao.read('upcoming'), isNull);
    await db.listPreferencesDao.write('upcoming', '{}');
    expect(await db.listPreferencesDao.read('upcoming'), '{}');
  });

  test('v6 → v7 keeps the list snapshots and adds the kanban buckets and '
      "the cards' buckets", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(6);
    schema.rawDatabase
      ..execute(
        'INSERT INTO projects (id, title, description, identifier, hex_color, '
        'parent_project_id, is_archived, is_favorite, position, owner_id, '
        'created, updated) '
        "VALUES (7, 'Work', '', '', '', 0, 0, 0, 1.0, NULL, NULL, NULL)",
      )
      ..execute(
        'INSERT INTO project_views (id, project_id, title, kind, position, '
        'filter_json, bucket_configuration_mode, default_bucket_id, '
        'done_bucket_id) '
        "VALUES (70, 7, 'List', 'list', 100.0, NULL, 'none', 0, 0), "
        "(71, 7, 'Kanban', 'kanban', 400.0, NULL, 'manual', 11, 13)",
      )
      ..execute(
        'INSERT INTO list_snapshots (list_key, loaded_at) '
        "VALUES ('view:70', 1760000000000)",
      )
      ..execute(
        'INSERT INTO list_snapshot_tasks (list_key, task_id, position) '
        "VALUES ('view:70', 60, 2.0), ('view:70', 61, 1.0)",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    final snapshot = await db.listSnapshotsDao.load('view:70');
    expect(snapshot.positions, {61: 1, 60: 2});
    expect(
      snapshot.loadedAt,
      DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true),
    );
    expect((await db.kanbanDao.load(71)).buckets, isEmpty);
    await db.kanbanDao.replaceBoard(
      71,
      buckets: const [
        Bucket(id: 11, viewId: 71, title: 'To-Do', count: 1, position: 100),
      ],
      slots: const {60: (bucketId: 11, position: 65536)},
      loadedPages: const {},
      loadedAt: DateTime.utc(2026, 10, 19, 12),
    );
    final board = await db.kanbanDao.load(71);
    expect(board.buckets.single.title, 'To-Do');
    expect(board.slots, {60: (bucketId: 11, position: 65536.0)});
    expect(board.loadedAt, DateTime.utc(2026, 10, 19, 12));
  });

  test('v7 → v8 keeps the tasks with their queued changes, adds the '
      'comment count and the unread flag and makes the next run a full '
      'one', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(7);
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
        'sync_run_id, pending_changes, pending_delete) '
        "VALUES (60, 7, 'Talked about', '', 0, NULL, NULL, NULL, NULL, "
        "0, 0.0, '', '-1', 1, 0, 0.0, 0, 0, 0, NULL, NULL, 1759000000000, "
        "'run-1', ?, 0)",
        [encodeTaskChanges(const TaskChanges(title: 'Talked about more'))],
      )
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-10-21T12:00:00.000Z'), "
        "('last_full_sync_at', '2026-10-21T11:00:00.000Z')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    final task = (await db.tasksDao.find(60))!;
    expect(task.title, 'Talked about');
    expect(task.commentCount, 0);
    expect(task.isUnread, isFalse);
    expect(
      (await db.tasksDao.findRow(60))!.pendingChanges,
      encodeTaskChanges(const TaskChanges(title: 'Talked about more')),
    );
    final state = await db.syncStateDao.readAll();
    expect(state[SyncStateKeys.lastSyncedAt], '2026-10-21T12:00:00.000Z');
    expect(
      state,
      isNot(contains(SyncStateKeys.lastFullSyncAt)),
      reason: 'the incremental run would not fill in the unchanged tasks',
    );
    await db.tasksDao.storeCommentState(60, commentCount: 3, isUnread: true);
    final talked = (await db.tasksDao.find(60))!;
    expect(talked.commentCount, 3);
    expect(talked.isUnread, isTrue);
  });
  test('v8 → v9 keeps the projects with their views, adds the permission '
      'unknown and makes the next run a full one', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(8);
    schema.rawDatabase
      ..execute(
        'INSERT INTO users (id, username, name) '
        "VALUES (3, 'owner', 'Owner')",
      )
      ..execute(
        'INSERT INTO projects (id, title, description, identifier, hex_color, '
        'parent_project_id, is_archived, is_favorite, position, owner_id, '
        'created, updated) '
        "VALUES (7, 'Shared', '<p>Ours</p>', 'SHR', '1973ff', 0, 0, 1, 2.0, "
        '3, 1759000000000, 1760000000000)',
      )
      ..execute(
        'INSERT INTO project_views (id, project_id, title, kind, position, '
        'filter_json, bucket_configuration_mode, default_bucket_id, '
        'done_bucket_id) '
        "VALUES (71, 7, 'List', 'list', 100.0, NULL, 'none', 0, 0)",
      )
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-10-26T12:00:00.000Z'), "
        "('last_full_sync_at', '2026-10-26T11:00:00.000Z')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    final project = (await db.projectsDao.loadProject(7))!;
    expect(project.title, 'Shared');
    expect(project.description, '<p>Ours</p>');
    expect(project.identifier, 'SHR');
    expect(project.isFavorite, isTrue);
    expect(project.owner?.username, 'owner');
    expect(project.views.single.title, 'List');
    expect(project.maxPermission, isNull, reason: 'unknown, not read only');
    final state = await db.syncStateDao.readAll();
    expect(state[SyncStateKeys.lastSyncedAt], '2026-10-26T12:00:00.000Z');
    expect(state, isNot(contains(SyncStateKeys.lastFullSyncAt)));
    await db.projectsDao.upsertAll([
      project.copyWith(maxPermission: Permission.read),
    ]);
    expect(
      (await db.projectsDao.loadProject(7))!.maxPermission,
      Permission.read,
    );
  });
  test('v9 → v10 keeps the tasks with their queued changes and adds the '
      'imported widget actions', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(9);
    schema.rawDatabase
      ..execute(
        'INSERT INTO projects (id, title, description, identifier, hex_color, '
        'parent_project_id, is_archived, is_favorite, position, owner_id, '
        'created, updated, max_permission) '
        "VALUES (7, 'Work', '', '', '', 0, 0, 0, 1.0, NULL, NULL, NULL, 1)",
      )
      ..execute(
        'INSERT INTO tasks (id, project_id, title, description, done, done_at, '
        'due_date, start_date, end_date, priority, percent_done, hex_color, '
        'identifier, "index", is_favorite, position, repeat_after, '
        'repeat_mode, bucket_id, created_by_id, created, updated, '
        'sync_run_id, pending_changes, pending_delete, comment_count, '
        'is_unread) '
        "VALUES (70, 7, 'Water the plants', '', 1, NULL, NULL, NULL, NULL, "
        "0, 0.0, '', '-1', 1, 0, 0.0, 0, 0, 0, NULL, NULL, 1759000000000, "
        "'run-1', ?, 0, 0, 0)",
        [encodeTaskChanges(const TaskChanges(done: true))],
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    final task = (await db.tasksDao.find(70))!;
    expect(task.title, 'Water the plants');
    expect(task.done, isTrue);
    expect(await db.importedWidgetActionsDao.contains('tap-1'), isFalse);
    final at = DateTime.utc(2026, 10, 26, 12);
    await db.importedWidgetActionsDao.add('tap-1', at: at);
    expect(await db.importedWidgetActionsDao.contains('tap-1'), isTrue);
    expect(
      await db.importedWidgetActionsDao.forgetBefore(
        at.add(const Duration(seconds: 1)),
      ),
      1,
    );
    expect(await db.importedWidgetActionsDao.contains('tap-1'), isFalse);
  });
}

final String _listViewFilter = jsonEncode({
  'filter': 'done = false',
  's': '',
  'sort_by': null,
  'order_by': null,
  'filter_include_nulls': false,
});
