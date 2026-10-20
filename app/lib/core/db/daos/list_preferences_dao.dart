import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/tables/lists.dart';

part 'list_preferences_dao.g.dart';

@DriftAccessor(tables: [ListPreferenceEntries])
final class ListPreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$ListPreferencesDaoMixin {
  new(super.attachedDatabase);

  Stream<String?> watchValue(String key) =>
      (select(listPreferenceEntries)..where((p) => p.key.equals(key)))
          .map((row) => row.value)
          .watchSingleOrNull();

  Future<String?> read(String key) => (select(
    listPreferenceEntries,
  )..where((p) => p.key.equals(key))).map((row) => row.value).getSingleOrNull();

  Future<void> write(String key, String value) =>
      into(listPreferenceEntries)
          .insertOnConflictUpdate(ListPreferenceRow(key: key, value: value));

  Future<void> removeAll(Iterable<String> keys) =>
      (delete(listPreferenceEntries)..where((p) => p.key.isIn(keys))).go();
}
