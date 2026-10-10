import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/tables/sync_state.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
final class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  new(super.attachedDatabase);

  Future<Map<String, String>> readAll() async => {
    for (final row in await select(syncState).get()) row.key: row.value,
  };

  /// A null value removes the key.
  Future<void> write(Map<String, String?> values) => batch((b) {
    for (final MapEntry(:key, :value) in values.entries) {
      if (value == null) {
        b.deleteWhere(syncState, (s) => s.key.equals(key));
      } else {
        b.insert(
          syncState,
          SyncStateRow(key: key, value: value),
          mode: InsertMode.insertOrReplace,
        );
      }
    }
  });
}
