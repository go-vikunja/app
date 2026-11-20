import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/daos/imported_widget_actions_dao.dart';
import 'package:vikunja_mobile/core/db/daos/kanban_dao.dart';
import 'package:vikunja_mobile/core/db/daos/label_ops_dao.dart';
import 'package:vikunja_mobile/core/db/daos/labels_dao.dart';
import 'package:vikunja_mobile/core/db/daos/list_preferences_dao.dart';
import 'package:vikunja_mobile/core/db/daos/list_snapshots_dao.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/db/daos/projects_dao.dart';
import 'package:vikunja_mobile/core/db/daos/scheduled_notifications_dao.dart';
import 'package:vikunja_mobile/core/db/daos/server_notifications_dao.dart';
import 'package:vikunja_mobile/core/db/daos/sync_state_dao.dart';
import 'package:vikunja_mobile/core/db/daos/task_details_dao.dart';
import 'package:vikunja_mobile/core/db/daos/tasks_dao.dart';
import 'package:vikunja_mobile/core/db/daos/users_dao.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/tables/imported_widget_actions.dart';
import 'package:vikunja_mobile/core/db/tables/kanban.dart';
import 'package:vikunja_mobile/core/db/tables/label_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/lists.dart';
import 'package:vikunja_mobile/core/db/tables/outbox.dart';
import 'package:vikunja_mobile/core/db/tables/projects.dart';
import 'package:vikunja_mobile/core/db/tables/scheduled_notifications.dart';
import 'package:vikunja_mobile/core/db/tables/server_notifications.dart';
import 'package:vikunja_mobile/core/db/tables/sync_state.dart';
import 'package:vikunja_mobile/core/db/tables/task_details.dart';
import 'package:vikunja_mobile/core/db/tables/task_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';

part 'app_database.g.dart';

/// One account's data. Schema changes bump [schemaVersion], get a migration
/// and a new dump under `drift_schemas/` (docs/development.md#generated-code).
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
    LabelIdRemaps,
    ScheduledNotifications,
    ServerNotifications,
    ListSnapshots,
    ListSnapshotTasks,
    ListPreferenceEntries,
    KanbanBuckets,
    ImportedWidgetActions,
    TaskDetailLoads,
    TaskAttachments,
    TaskReactions,
    TaskComments,
    TaskCommentReactions,
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
    ImportedWidgetActionsDao,
    TaskDetailsDao,
    LabelOpsDao,
  ],
)
final class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // From 1, and from the development builds' 12, which has version 1's
    // tables, version 2 adds the stored details, the label remaps and the
    // outbox's label column. A later version's database after a rollback
    // keeps its tables: `createTable` creates only what is missing, and the
    // column is added only when it is.
    onUpgrade: (m, from, to) async {
      for (final table in <TableInfo<Table, Object?>>[
        taskDetailLoads,
        taskAttachments,
        taskReactions,
        taskComments,
        taskCommentReactions,
        labelIdRemaps,
      ]) {
        await m.createTable(table);
      }
      if (!await _hasColumn(outbox.actualTableName, outbox.labelId.name)) {
        await m.addColumn(outbox, outbox.labelId);
      }
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<bool> _hasColumn(String table, String column) async {
    final found = await customSelect(
      'SELECT 1 FROM pragma_table_info(?) WHERE name = ?',
      variables: [Variable.withString(table), Variable.withString(column)],
    ).get();
    return found.isNotEmpty;
  }
}
