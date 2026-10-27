import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/tables/imported_widget_actions.dart';

part 'imported_widget_actions_dao.g.dart';

@DriftAccessor(tables: [ImportedWidgetActions])
final class ImportedWidgetActionsDao extends DatabaseAccessor<AppDatabase>
    with _$ImportedWidgetActionsDaoMixin {
  new(super.attachedDatabase);

  Future<bool> contains(String id) async =>
      await (select(
        importedWidgetActions,
      )..where((row) => row.id.equals(id))).getSingleOrNull() !=
      null;

  Future<void> add(String id, {required DateTime at}) => into(
    importedWidgetActions,
  ).insertOnConflictUpdate(ImportedWidgetActionRow(id: id, importedAt: at));

  /// Forgets the taps imported before [cutoff], whose files are long gone.
  Future<int> forgetBefore(DateTime cutoff) =>
      (delete(importedWidgetActions)..where(
            (row) => row.importedAt.isSmallerThanValue(
              const EpochMillis().toSql(cutoff),
            ),
          ))
          .go();
}
