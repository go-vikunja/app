import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// Which server id a task created here got: a create runs under a
/// temporary negative id until the server has assigned the real one, and a
/// screen opened on the temporary id follows it here. Never pruned: a
/// screen may still hold the old id, and temporary ids are never reused.
@DataClassName('TaskIdRemapRow')
class TaskIdRemaps extends Table {
  IntColumn get localId => integer()();
  IntColumn get serverId => integer()();
  IntColumn get at => integer().map(const EpochMillis())();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}
