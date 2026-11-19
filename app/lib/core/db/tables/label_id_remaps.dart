import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// Which server id a label created here got: a create runs under a
/// temporary negative id until the server has assigned the real one, and a
/// screen, a picker or a home-screen widget holding the temporary id
/// follows it here. Never pruned: temporary ids are never reused.
@DataClassName('LabelIdRemapRow')
class LabelIdRemaps extends Table {
  IntColumn get localId => integer()();
  IntColumn get serverId => integer()();
  IntColumn get at => integer().map(const EpochMillis())();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}
