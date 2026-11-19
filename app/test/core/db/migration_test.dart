import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show OwnTaskSubscription;
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/sample_data.dart';
import 'generated/schema.dart';

const _storedDetailsTables = [
  'task_attachments',
  'task_comment_reactions',
  'task_comments',
  'task_detail_loads',
  'task_reactions',
];

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  List<String> schemaOf(Database database) => [
    for (final row in database.select(
      'SELECT type, name, sql FROM sqlite_master ORDER BY type, name',
    ))
      '${row['type']} ${row['name']}: ${row['sql']}',
  ];

  List<String> tablesOf(Database database) => [
    for (final row in database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    ))
      row['name'] as String,
  ];

  Map<String, List<Map<String, Object?>>> rowsOf(
    Database database,
    Iterable<String> tables,
  ) => {
    for (final table in tables)
      table: [
        for (final row in database.select(
          'SELECT * FROM "$table" ORDER BY rowid',
        ))
          {...row},
      ],
  };

  test('a version 1 database upgrades to version 2 with every row kept, the '
      'tables of the stored details and the label remaps added and a label '
      'column in the outbox', () async {
    final schema = await verifier.schemaAt(1);
    final changes = encodeTaskChanges(const TaskChanges(done: true));
    _fillVersion1(schema.rawDatabase, changes);
    final tables = tablesOf(schema.rawDatabase);
    final before = rowsOf(schema.rawDatabase, tables);
    expect(tables, isNot(contains('task_comments')));
    expect(tables, isNot(contains('label_id_remaps')));
    expect(before.values.where((rows) => rows.isEmpty), isEmpty);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 2);

    expect(rowsOf(schema.rawDatabase, tables), {
      ...before,
      'outbox': [
        for (final row in before['outbox']!) {...row, 'label_id': null},
      ],
    });
    expect(
      tablesOf(schema.rawDatabase),
      [...tables, ..._storedDetailsTables, 'label_id_remaps']..sort(),
    );
    expect(schema.rawDatabase.userVersion, 2);
    final queued = await db.labelOpsDao.queueCreate(
      const NewLabel(title: 'Garden'),
      now: DateTime.utc(2026, 11, 19, 8),
    );
    expect(queued.id, -1);
    expect((await db.outboxDao.all()).last.labelId, -1);
    expect(await db.labelsDao.resolveId(-1), -1);
    final task = (await db.tasksDao.find(70))!;
    expect(task.title, 'Water the plants');
    expect(task.labels.map((label) => label.title), ['Errand']);
    expect(task.assignees.map((user) => user.username), ['anna']);
    expect((await db.tasksDao.findRow(70))!.pendingChanges, changes);
    expect((await db.outboxDao.nextInLine())!.id, 'op-1');
    expect(await db.taskDetailsDao.storedDetails(70), isNull);
    final at = DateTime.utc(2026, 11, 19, 8);
    await db.taskDetailsDao.storeDetails(
      70,
      TaskDetails(attachments: [sampleAttachment(id: 3, taskId: 70)]),
      at: at,
    );
    final stored = (await db.taskDetailsDao.storedDetails(70))!;
    expect(stored.value.attachments, [sampleAttachment(id: 3, taskId: 70)]);
    expect(stored.value.commentCount, 2);
    expect(stored.readAt, at);
  });

  test(
    'on an upgraded database the stored details go with their task',
    () async {
      final schema = await verifier.schemaAt(1);
      _fillVersion1(
        schema.rawDatabase,
        encodeTaskChanges(const TaskChanges(done: true)),
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 2);
      const anna = User(id: 9, username: 'anna', name: 'Anna');
      final at = DateTime.utc(2026, 11, 19, 8);
      for (final id in [70, 71]) {
        await db.taskDetailsDao.storeDetails(
          id,
          TaskDetails(
            attachments: [sampleAttachment(id: id, taskId: id)],
            reactions: const {
              '👍': [anna],
            },
          ),
          at: at,
        );
        await db.taskDetailsDao.storeComments(
          id,
          [
            sampleComment(
              id: id,
              reactions: const {
                '👍': [anna],
              },
            ),
          ],
          replace: true,
          at: at,
        );
      }
      Map<String, List<Object?>> taskIds() => {
        for (final table in _storedDetailsTables)
          table: [
            for (final row in schema.rawDatabase.select(
              'SELECT task_id FROM "$table" ORDER BY task_id',
            ))
              row['task_id'],
          ],
      };
      expect(taskIds(), {
        for (final table in _storedDetailsTables) table: [70, 71],
      });

      await (db.delete(db.tasks)..where((t) => t.id.equals(70))).go();

      expect(taskIds(), {
        for (final table in _storedDetailsTables) table: [71],
      });
    },
  );

  test('a database of the development builds at version 12 keeps its '
      'tables and rows, gains those of version 2 and is at version 2 from '
      'then on', () async {
    final schema = await verifier.schemaAt(1);
    final changes = encodeTaskChanges(const TaskChanges(done: true));
    schema.rawDatabase
      ..execute(
        'INSERT INTO projects (id, title, description, identifier, hex_color, '
        'parent_project_id, is_archived, is_favorite, position, owner_id, '
        'created, updated, max_permission, subscribed_via) '
        "VALUES (7, 'Work', '', 'WRK', '', 0, 0, 0, 1.0, NULL, NULL, "
        '1760000000000, 1, 7)',
      )
      ..execute(
        'INSERT INTO tasks (id, project_id, title, description, done, done_at, '
        'due_date, start_date, end_date, priority, percent_done, hex_color, '
        'identifier, "index", is_favorite, position, repeat_after, '
        'repeat_mode, bucket_id, created_by_id, created, updated, '
        'comment_count, is_unread, sync_run_id, pending_changes, '
        'pending_delete, own_subscription) '
        "VALUES (70, 7, 'Water the plants', '', 1, NULL, 1760100000000, NULL, "
        "NULL, 0, 0.0, '', 'WRK-1', 1, 0, 0.0, 0, 0, 0, NULL, NULL, "
        "1759000000000, 2, 1, 'run-1', ?, 0, 'subscribed')",
        [changes],
      )
      ..execute(
        'INSERT INTO outbox (id, sequence, kind, task_id, payload, created_at, '
        'attempts, next_attempt_at, last_attempt_at, state, last_error, '
        'sent_at) '
        "VALUES ('op-1', 1, 'updateTask', 70, ?, 1760100000000, 0, NULL, "
        "NULL, 'pending', NULL, NULL)",
        [changes],
      )
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-11-09T12:00:00.000Z'), "
        "('last_full_sync_at', '2026-11-09T11:00:00.000Z')",
      )
      ..userVersion = 12;
    final tables = schemaOf(schema.rawDatabase);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final project = (await db.projectsDao.loadProject(7))!;
    expect(project.title, 'Work');
    expect(project.maxPermission, Permission.write);
    expect(project.subscription?.entityId, 7);
    final task = (await db.tasksDao.findRow(70))!;
    expect(task.title, 'Water the plants');
    expect(task.pendingChanges, changes);
    expect(task.commentCount, 2);
    expect(task.isUnread, isTrue);
    expect(await db.tasksDao.ownSubscriptions(), {
      70: OwnTaskSubscription.subscribed,
    });
    final op = (await db.outboxDao.nextInLine())!;
    expect(op.id, 'op-1');
    expect(op.state, OutboxState.pending.name);
    final state = await db.syncStateDao.readAll();
    expect(state[SyncStateKeys.lastFullSyncAt], '2026-11-09T11:00:00.000Z');

    // Adding the column rewrites the outbox's statement.
    bool notOutbox(String entry) => !entry.startsWith('table outbox:');
    expect(
      schemaOf(schema.rawDatabase).where(notOutbox),
      containsAll(tables.where(notOutbox)),
    );
    expect(
      tablesOf(schema.rawDatabase),
      containsAll([..._storedDetailsTables, 'label_id_remaps']),
    );
    expect(op.labelId, isNull);
    expect(schema.rawDatabase.userVersion, 2);
    await db.validateDatabaseSchema();
  });

  test('a database a later version left behind opens with its tables as '
      'they are', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-11-09T12:00:00.000Z')",
      )
      ..userVersion = 3;
    final tables = schemaOf(schema.rawDatabase);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final state = await db.syncStateDao.readAll();

    expect(state[SyncStateKeys.lastSyncedAt], '2026-11-09T12:00:00.000Z');
    expect(schemaOf(schema.rawDatabase), tables);
  });
}

/// A row in every table of version 1.
void _fillVersion1(Database database, String changes) {
  database
    ..execute(
      'INSERT INTO projects (id, title, description, identifier, hex_color, '
      'parent_project_id, is_archived, is_favorite, position, owner_id, '
      'created, updated, max_permission, subscribed_via) '
      "VALUES (7, 'Work', '', 'WRK', '', 0, 0, 0, 1.0, NULL, NULL, "
      '1760000000000, 1, NULL)',
    )
    ..execute(
      'INSERT INTO project_views (id, project_id, title, kind, position, '
      'filter_json, bucket_configuration_mode, default_bucket_id, '
      'done_bucket_id) '
      "VALUES (30, 7, 'Board', 'kanban', 1.0, NULL, 'manual', 2, 0)",
    )
    ..execute(
      'INSERT INTO labels (id, title, description, hex_color, created_by_id, '
      'created, updated) '
      "VALUES (3, 'Errand', '', 'ff0000', 9, NULL, NULL)",
    )
    ..execute(
      "INSERT INTO users (id, username, name) VALUES (9, 'anna', 'Anna')",
    )
    ..execute(
      'INSERT INTO task_id_remaps (local_id, server_id, at) '
      'VALUES (-1, 71, 1760100000000)',
    )
    ..execute(
      'INSERT INTO scheduled_notifications (key, os_id, task_id, kind, '
      'fire_at, title, body, snoozed_until, snooze_original_fire_at, exact, '
      'hidden_on_lock_screen, done_needs_unlock) '
      "VALUES ('due:70', 1, 70, 'due', 1760100000000, 'Water the plants', "
      "'Due now', NULL, NULL, 0, 0, 0)",
    )
    ..execute(
      'INSERT INTO server_notifications (id, name, payload, created, read_at, '
      'read_pending, notified) '
      "VALUES (5, 'task.comment', '{}', 1760100000000, NULL, NULL, 1)",
    )
    ..execute(
      'INSERT INTO list_snapshots (list_key, loaded_at) '
      "VALUES ('view:30', 1760100000000)",
    )
    ..execute(
      'INSERT INTO list_snapshot_tasks (list_key, task_id, position, '
      "bucket_id) VALUES ('view:30', 70, 1.0, 2)",
    )
    ..execute(
      'INSERT INTO list_preferences (key, value) '
      "VALUES ('view:30', '{\"sort\":\"due\"}')",
    )
    ..execute(
      'INSERT INTO kanban_buckets (view_id, bucket_id, title, "limit", count, '
      "position, loaded_pages) VALUES (30, 2, 'To do', 0, 1, 1.0, 1)",
    )
    ..execute(
      'INSERT INTO imported_widget_actions (id, imported_at) '
      "VALUES ('w-1', 1760100000000)",
    )
    ..execute(
      'INSERT INTO sync_state (key, value) '
      "VALUES ('last_synced_at', '2026-11-09T12:00:00.000Z')",
    );
  for (final (id, title) in [(70, 'Water the plants'), (71, 'Buy soil')]) {
    database.execute(
      'INSERT INTO tasks (id, project_id, title, description, done, done_at, '
      'due_date, start_date, end_date, priority, percent_done, hex_color, '
      'identifier, "index", is_favorite, position, repeat_after, '
      'repeat_mode, bucket_id, created_by_id, created, updated, '
      'comment_count, is_unread, sync_run_id, pending_changes, '
      'pending_delete, own_subscription) '
      "VALUES (?, 7, ?, '<p>Soon</p>', 0, NULL, 1760100000000, NULL, NULL, "
      "2, 0.5, '', '', ?, 0, 1.0, 0, 0, 2, 9, 1759000000000, "
      "1759000000000, 2, 0, 'run-1', ?, 0, NULL)",
      [id, title, id, if (id == 70) changes else null],
    );
  }
  database
    ..execute('INSERT INTO task_labels (task_id, label_id) VALUES (70, 3)')
    ..execute('INSERT INTO task_assignees (task_id, user_id) VALUES (70, 9)')
    ..execute(
      'INSERT INTO task_reminders (task_id, ordinal, reminder, '
      "relative_period, relative_to) VALUES (70, 0, NULL, -3600, 'due_date')",
    )
    ..execute(
      'INSERT INTO task_relations (task_id, other_task_id, kind) '
      "VALUES (70, 71, 'subtask')",
    )
    ..execute(
      'INSERT INTO outbox (id, sequence, kind, task_id, payload, created_at, '
      'attempts, next_attempt_at, last_attempt_at, state, last_error, '
      'sent_at) '
      "VALUES ('op-1', 1, 'updateTask', 70, ?, 1760100000000, 0, NULL, "
      "NULL, 'pending', NULL, NULL)",
      [changes],
    );
}
