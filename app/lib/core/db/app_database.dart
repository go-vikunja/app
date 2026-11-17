import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/daos/imported_widget_actions_dao.dart';
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
import 'package:vikunja_mobile/core/db/tables/imported_widget_actions.dart';
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
    ImportedWidgetActions,
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
  ],
)
final class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // At version 1 only a newer database gets here: the development builds'
    // 12, which has these same tables, or a later version's after a
    // rollback, whose tables stay as they are.
    onUpgrade: (m, from, to) async {},
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
