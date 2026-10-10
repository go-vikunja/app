import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/daos/labels_dao.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/db/daos/projects_dao.dart';
import 'package:vikunja_mobile/core/db/daos/sync_state_dao.dart';
import 'package:vikunja_mobile/core/db/daos/tasks_dao.dart';
import 'package:vikunja_mobile/core/db/daos/users_dao.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/outbox.dart';
import 'package:vikunja_mobile/core/db/tables/projects.dart';
import 'package:vikunja_mobile/core/db/tables/sync_state.dart';
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
  ],
  daos: [ProjectsDao, LabelsDao, UsersDao, TasksDao, SyncStateDao, OutboxDao],
)
final class AppDatabase extends _$AppDatabase {
  new(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tasks, tasks.pendingChanges);
        await m.addColumn(tasks, tasks.pendingDelete);
        await m.createTable(outbox);
        await m.createIndex(outboxStateSequence);
      }
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
