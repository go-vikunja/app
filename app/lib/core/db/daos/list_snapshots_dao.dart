import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/tables/lists.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

part 'list_snapshots_dao.g.dart';

@DriftAccessor(tables: [ListSnapshots, ListSnapshotTasks])
final class ListSnapshotsDao extends DatabaseAccessor<AppDatabase>
    with _$ListSnapshotsDaoMixin {
  new(super.attachedDatabase);

  /// The list's snapshot replaced in one transaction, so a reader sees
  /// either the old download or the new one.
  Future<void> replace(
    String listKey,
    Map<int, double> positions, {
    required DateTime loadedAt,
  }) => transaction(() async {
    await (delete(
      listSnapshotTasks,
    )..where((t) => t.listKey.equals(listKey))).go();
    await batch(
      (b) => b.insertAll(listSnapshotTasks, [
        for (final MapEntry(key: taskId, value: position) in positions.entries)
          ListSnapshotTaskRow(
            listKey: listKey,
            taskId: taskId,
            position: position,
          ),
      ]),
    );
    await into(listSnapshots).insertOnConflictUpdate(
      ListSnapshotRow(listKey: listKey, loadedAt: loadedAt),
    );
  });

  /// In list order (by position, then id); an empty snapshot without
  /// `loadedAt` when the list was never downloaded.
  Future<ListSnapshot> load(String listKey) async {
    final header = await (select(
      listSnapshots,
    )..where((s) => s.listKey.equals(listKey))).getSingleOrNull();
    if (header == null) return const ListSnapshot();
    final rows =
        await (select(listSnapshotTasks)
              ..where((t) => t.listKey.equals(listKey))
              ..orderBy([
                (t) => OrderingTerm.asc(t.position),
                (t) => OrderingTerm.asc(t.taskId),
              ]))
            .get();
    return ListSnapshot(
      positions: {for (final row in rows) row.taskId: row.position},
      loadedAt: header.loadedAt,
    );
  }

  Stream<ListSnapshot> watch(String listKey) =>
      watchTables({listSnapshots, listSnapshotTasks}, () => load(listKey));

  /// The server accepted these list positions of the task, by view id:
  /// each downloaded view takes its position until the next download,
  /// which brings the server's (it may have spread equal positions apart).
  /// A view never downloaded is left alone.
  Future<void> applySentPositions(int taskId, Map<int, double> positions) =>
      transaction(() async {
        for (final MapEntry(key: viewId, value: position)
            in positions.entries) {
          final listKey = 'view:$viewId';
          final header = await (select(
            listSnapshots,
          )..where((s) => s.listKey.equals(listKey))).getSingleOrNull();
          if (header == null) continue;
          await into(listSnapshotTasks).insert(
            ListSnapshotTaskRow(
              listKey: listKey,
              taskId: taskId,
              position: position,
            ),
            onConflict: DoUpdate(
              (_) => ListSnapshotTasksCompanion(position: Value(position)),
            ),
          );
        }
      });

  /// Removes the snapshots whose key starts with [prefix], except [keep].
  Future<void> removeAll(String prefix, {Set<String> keep = const {}}) =>
      transaction(() async {
        Expression<bool> doomed(GeneratedColumn<String> key) {
          final matches = key.like('${_escaped(prefix)}%', escapeChar: r'\');
          return keep.isEmpty ? matches : matches & key.isNotIn(keep);
        }

        await (delete(listSnapshotTasks)..where((t) => doomed(t.listKey))).go();
        await (delete(listSnapshots)..where((s) => doomed(s.listKey))).go();
      });

  static String _escaped(String pattern) =>
      pattern.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
}
