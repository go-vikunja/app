import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/daos/kanban_dao.dart';
import 'package:vikunja_mobile/core/db/daos/labels_dao.dart';
import 'package:vikunja_mobile/core/db/daos/list_preferences_dao.dart';
import 'package:vikunja_mobile/core/db/daos/list_snapshots_dao.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/db/daos/projects_dao.dart';
import 'package:vikunja_mobile/core/db/daos/scheduled_notifications_dao.dart';
import 'package:vikunja_mobile/core/db/daos/server_notifications_dao.dart';
import 'package:vikunja_mobile/core/db/daos/sync_state_dao.dart';
import 'package:vikunja_mobile/core/db/daos/tasks_dao.dart';
import 'package:vikunja_mobile/core/db/daos/users_dao.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/tables/kanban.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/lists.dart';
import 'package:vikunja_mobile/core/db/tables/outbox.dart';
import 'package:vikunja_mobile/core/db/tables/projects.dart';
import 'package:vikunja_mobile/core/db/tables/scheduled_notifications.dart';
import 'package:vikunja_mobile/core/db/tables/server_notifications.dart';
import 'package:vikunja_mobile/core/db/tables/sync_state.dart';
import 'package:vikunja_mobile/core/db/tables/task_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';

part 'app_database.g.dart';

/// One account's data. Schema changes bump [schemaVersion], get a migration
/// and a new dump under `drift_schemas/` (see the README).
@DriftDatabase(
  tables: [
    Projects,
    ProjectViews,
    Labels,
    Users,
    Tasks,
    TaskLabels,
    TaskAssignees,
    TaskReminders,
    TaskRelations,
    SyncState,
    Outbox,
    TaskIdRemaps,
    ScheduledNotifications,
    ServerNotifications,
    ListSnapshots,
    ListSnapshotTasks,
    ListPreferenceEntries,
    KanbanBuckets,
  ],
  daos: [
    ProjectsDao,
    LabelsDao,
    UsersDao,
    TasksDao,
    SyncStateDao,
    OutboxDao,
    ScheduledNotificationsDao,
    ServerNotificationsDao,
    ListSnapshotsDao,
    ListPreferencesDao,
    KanbanDao,
  ],
)
final class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tasks, tasks.pendingChanges);
        await m.addColumn(tasks, tasks.pendingDelete);
        await m.createTable(outbox);
        await m.createIndex(outboxStateSequence);
      }
      if (from < 3) {
        // A database from before 2 got the outbox in its current shape.
        if (from == 2) await m.addColumn(outbox, outbox.sentAt);
        await m.createTable(taskIdRemaps);
      }
      if (from < 4) await m.createTable(scheduledNotifications);
      if (from < 5) await m.createTable(serverNotifications);
      if (from < 6) {
        await m.createTable(listSnapshots);
        await m.createTable(listSnapshotTasks);
        await m.createTable(listPreferenceEntries);
        // Before v6 a child's pull could move its edge to the end of the
        // parent's relations; the next run is a full one, so every parent
        // gets its subtasks back in the server's order.
        await (delete(
          syncState,
        )..where((row) => row.key.equals('last_full_sync_at'))).go();
      }
      if (from < 7) {
        await m.createTable(kanbanBuckets);
        // A database from before 6 got the snapshot rows in their current
        // shape.
        if (from == 6) {
          await m.addColumn(listSnapshotTasks, listSnapshotTasks.bucketId);
        }
      }
      if (from < 8) {
        await m.addColumn(tasks, tasks.commentCount);
        await m.addColumn(tasks, tasks.isUnread);
        // The incremental run only sees tasks that change, so the next run
        // is a full one that fills both in for every task.
        await (delete(
          syncState,
        )..where((row) => row.key.equals('last_full_sync_at'))).go();
      }
      if (from < 9) {
        await m.addColumn(projects, projects.maxPermission);
        // The next run is a full one, which writes every project with it.
        await (delete(
          syncState,
        )..where((row) => row.key.equals('last_full_sync_at'))).go();
      }
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
