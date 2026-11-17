import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show OwnTaskSubscription;
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  List<String> schemaOf(Database database) => [
    for (final row in database.select(
      'SELECT type, name, sql FROM sqlite_master ORDER BY type, name',
    ))
      '${row['type']} ${row['name']}: ${row['sql']}',
  ];

  test('a database of the development builds at version 12 keeps its '
      'tables and rows and is at version 1 from then on', () async {
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

    expect(schemaOf(schema.rawDatabase), tables);
    expect(schema.rawDatabase.userVersion, 1);
    await db.validateDatabaseSchema();
  });

  test('a database a later version left behind opens with its tables as '
      'they are', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute(
        'INSERT INTO sync_state (key, value) '
        "VALUES ('last_synced_at', '2026-11-09T12:00:00.000Z')",
      )
      ..userVersion = 2;
    final tables = schemaOf(schema.rawDatabase);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final state = await db.syncStateDao.readAll();

    expect(state[SyncStateKeys.lastSyncedAt], '2026-11-09T12:00:00.000Z');
    expect(schemaOf(schema.rawDatabase), tables);
  });
}
