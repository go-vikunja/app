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

  /// Emits on every write to the table; callers that only care about a
  /// change of the value deduplicate.
  Stream<String?> watchValue(String key) =>
      (select(syncState)..where((s) => s.key.equals(key)))
          .map((row) => row.value)
          .watchSingleOrNull();

  /// The stored values of [keys], on every write to the table.
  Stream<Map<String, String>> watchValues(Set<String> keys) =>
      (select(syncState)..where((s) => s.key.isIn(keys))).watch().map(
        (rows) => {for (final row in rows) row.key: row.value},
      );

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
