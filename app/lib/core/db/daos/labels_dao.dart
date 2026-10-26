import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/mappers/label_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';

part 'labels_dao.g.dart';

@DriftAccessor(tables: [Labels, Users])
final class LabelsDao extends DatabaseAccessor<AppDatabase>
    with _$LabelsDaoMixin {
  new(super.attachedDatabase);

  Stream<List<Label>> watchAll() => watchTables({labels, users}, loadAll);

  Future<List<Label>> loadAll() async {
    final query = select(labels).join([
      leftOuterJoin(users, users.id.equalsExp(labels.createdById)),
    ])..orderBy([OrderingTerm.asc(labels.id)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        labelFromRow(
          row.readTable(labels),
          createdBy: switch (row.readTableOrNull(users)) {
            final user? => userFromRow(user),
            null => null,
          },
        ),
    ];
  }

  Future<void> upsertAll(Iterable<Label> all) {
    if (all.isEmpty) return Future.value();
    return batch((b) {
      b
        ..insertAllOnConflictUpdate(users, [
          for (final label in all)
            if (label.createdBy case final user?) userRow(user),
        ])
        ..insertAllOnConflictUpdate(labels, [
          for (final label in all) labelRow(label).toCompanion(false),
        ]);
    });
  }

  /// Removes the labels not in [ids], and their ids from the queued edits,
  /// see `OutboxDao.forgetLabels`.
  Future<int> purgeNotIn(Iterable<int> ids) => transaction(() async {
    final query = selectOnly(labels)
      ..addColumns([labels.id])
      ..where(labels.id.isNotIn(ids));
    final gone = await query.map((row) => row.read(labels.id)!).get();
    await _removeAll(gone.toSet());
    return gone.length;
  });

  /// Removes the label, from every task through the foreign key and from
  /// the queued edits, as [purgeNotIn] does.
  Future<void> remove(int id) => transaction(() => _removeAll({id}));

  Future<void> _removeAll(Set<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(labels)..where((l) => l.id.isIn(ids))).go();
    await attachedDatabase.outboxDao.forgetLabels(ids);
  }
}
