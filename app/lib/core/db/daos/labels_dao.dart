import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/mappers/label_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/label_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/outbox/label_op_json.dart';

part 'labels_dao.g.dart';

/// The labels as this device has them. A label created here has a
/// negative id until its create is answered (see `LabelOpsDao`); the sync
/// never overwrites or purges it.
@DriftAccessor(tables: [Labels, Users, LabelIdRemaps])
final class LabelsDao extends DatabaseAccessor<AppDatabase>
    with _$LabelsDaoMixin {
  new(super.attachedDatabase);

  Stream<List<Label>> watchAll() => watchTables({labels, users}, loadAll);

  Future<List<Label>> loadAll() => _load();

  Future<Label?> find(int id) async =>
      (await _load(where: labels.id.equals(id))).singleOrNull;

  Future<List<Label>> _load({Expression<bool>? where}) async {
    final query = select(labels).join([
      leftOuterJoin(users, users.id.equalsExp(labels.createdById)),
    ])..orderBy([OrderingTerm.asc(labels.id)]);
    if (where != null) query.where(where);
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

  /// The server id a temporary [id] was remapped to, else [id] itself.
  Future<int> resolveId(int id) async {
    if (id > 0) return id;
    final remap = await (select(
      labelIdRemaps,
    )..where((r) => r.localId.equals(id))).getSingleOrNull();
    return remap?.serverId ?? id;
  }

  /// [id] followed to the server id once its label's create is answered.
  Stream<int> watchResolvedId(int id) =>
      watchTables({labelIdRemaps}, () => resolveId(id));

  /// The label, following a temporary id to the server id once the create
  /// is answered; null once it is gone.
  Stream<Label?> watchLabel(int id) => watchTables({
    labels,
    users,
    labelIdRemaps,
  }, () async => await find(await resolveId(id)));

  /// Every temporary id with the server id it got.
  Stream<Map<int, int>> watchRemaps() => watchTables({labelIdRemaps}, () async {
    final rows = await select(labelIdRemaps).get();
    return {for (final row in rows) row.localId: row.serverId};
  });

  /// Every server id a create of this device was remapped to.
  Future<Set<int>> remappedServerIds() async {
    final query = selectOnly(labelIdRemaps)
      ..addColumns([labelIdRemaps.serverId]);
    return {
      for (final row in await query.get()) row.read(labelIdRemaps.serverId)!,
    };
  }

  /// Stores the server's [all], each under the edits still queued for it;
  /// one whose delete is queued is left out.
  Future<void> upsertAll(Iterable<Label> all) async {
    if (all.isEmpty) return;
    await storeRows(await withQueued(all));
  }

  /// [incoming], the server's labels, each with the edits still queued for
  /// it on top, without those whose delete is queued.
  Future<List<Label>> withQueued(Iterable<Label> incoming) async {
    final ops = attachedDatabase.labelOpsDao;
    final deleting = await ops.deletingIds();
    final queued = await ops.queuedChanges();
    return [
      for (final label in incoming)
        if (!deleting.contains(label.id))
          switch (queued[label.id]) {
            final changes? => applyLabelChanges(label, changes),
            null => label,
          },
    ];
  }

  /// Stores [all] as they are, with their creators.
  Future<void> storeRows(Iterable<Label> all) {
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

  /// Removes the server labels not in [ids], and their ids from the queued
  /// edits, see `OutboxDao.forgetLabels`. Labels created here are kept,
  /// and so is one a create of this device got since [remappedBefore], the
  /// remapped server ids when the caller read [ids]: the read may have come
  /// before the create.
  Future<int> purgeNotIn(Iterable<int> ids, {Set<int>? remappedBefore}) =>
      transaction(() async {
        final query = selectOnly(labels)
          ..addColumns([labels.id])
          ..where(labels.id.isNotIn(ids) & labels.id.isBiggerThanValue(0));
        final gone = await query.map((row) => row.read(labels.id)!).get();
        final kept = remappedBefore == null
            ? const <int>{}
            : (await remappedServerIds()).difference(remappedBefore);
        final purged = gone.toSet().difference(kept);
        await _removeAll(purged);
        return purged.length;
      });

  /// Removes the label, from every task through the foreign key, from the
  /// queued edits and with its own queued ops, as [purgeNotIn] does.
  Future<void> remove(int id) => transaction(() => _removeAll({id}));

  Future<void> _removeAll(Set<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(labels)..where((l) => l.id.isIn(ids))).go();
    await attachedDatabase.outboxDao.forgetLabels(ids);
    await attachedDatabase.labelOpsDao.removeOpsOf(ids);
  }
}
