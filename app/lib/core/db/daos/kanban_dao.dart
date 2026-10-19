import 'dart:math';

import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/tables/kanban.dart';
import 'package:vikunja_mobile/core/db/tables/lists.dart';
import 'package:vikunja_mobile/core/db/tables/projects.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

part 'kanban_dao.g.dart';

/// A kanban view's board as of its downloads: the buckets, and the cards
/// as the view's snapshot (`view:<id>`) rows with their bucket.
typedef StoredBoard = ({
  List<Bucket> buckets,
  Map<int, BoardSlot> slots,
  DateTime? loadedAt,
});

@DriftAccessor(
  tables: [KanbanBuckets, ListSnapshots, ListSnapshotTasks, ProjectViews],
)
final class KanbanDao extends DatabaseAccessor<AppDatabase>
    with _$KanbanDaoMixin {
  new(super.attachedDatabase);

  static String boardKey(int viewId) => 'view:$viewId';

  /// The view's buckets and cards replaced in one transaction, so a reader
  /// sees either the old board or the new one. [loadedPages] by bucket id;
  /// a bucket without an entry holds one page.
  Future<void> replaceBoard(
    int viewId, {
    required List<Bucket> buckets,
    required Map<int, BoardSlot> slots,
    required Map<int, int> loadedPages,
    required DateTime loadedAt,
  }) => transaction(() async {
    final key = boardKey(viewId);
    await (delete(kanbanBuckets)..where((b) => b.viewId.equals(viewId))).go();
    await (delete(listSnapshotTasks)..where((t) => t.listKey.equals(key))).go();
    await batch(
      (b) => b
        ..insertAll(kanbanBuckets, [
          for (final bucket in buckets)
            KanbanBucketRow(
              viewId: viewId,
              bucketId: bucket.id,
              title: bucket.title,
              taskLimit: bucket.limit,
              taskCount: bucket.count,
              position: bucket.position,
              loadedPages: loadedPages[bucket.id] ?? 1,
            ),
        ])
        ..insertAll(listSnapshotTasks, [
          for (final MapEntry(key: taskId, value: slot) in slots.entries)
            ListSnapshotTaskRow(
              listKey: key,
              taskId: taskId,
              position: slot.position,
              bucketId: slot.bucketId,
            ),
        ]),
    );
    await into(
      listSnapshots,
    ).insertOnConflictUpdate(ListSnapshotRow(listKey: key, loadedAt: loadedAt));
  });

  /// The next page of one bucket's cards: a card listed in another bucket
  /// moves here, as the server's answer is newer, and leaves that bucket's
  /// count. [count] is the server's new total when the page reported one;
  /// after the [last] page the bucket counts the cards it holds, so that a
  /// card the server lists in two buckets (filter mode) cannot leave it
  /// wanting more for good. False when the board no longer has the bucket,
  /// and nothing is written then.
  Future<bool> appendToBucket(
    int viewId,
    int bucketId, {
    required Map<int, double> positions,
    required int loadedPages,
    int? count,
    bool last = false,
  }) => transaction(() async {
    final target = await _bucket(viewId, bucketId);
    if (target == null) return false;
    final key = boardKey(viewId);
    final movedFrom =
        await (select(listSnapshotTasks)..where(
              (t) =>
                  t.listKey.equals(key) &
                  t.taskId.isIn(positions.keys) &
                  t.bucketId.equals(bucketId).not(),
            ))
            .get();
    for (final row in movedFrom) {
      if (row.bucketId case final from?) {
        if (await _bucket(viewId, from) case final source?) {
          await _setCount(source, max(source.taskCount - 1, 0));
        }
      }
    }
    await batch(
      (b) => b.insertAllOnConflictUpdate(listSnapshotTasks, [
        for (final MapEntry(key: taskId, value: position) in positions.entries)
          ListSnapshotTaskRow(
            listKey: key,
            taskId: taskId,
            position: position,
            bucketId: bucketId,
          ),
      ]),
    );
    final held = last ? await _cardsIn(key, bucketId) : null;
    await (update(kanbanBuckets)
          ..where((b) => b.viewId.equals(viewId) & b.bucketId.equals(bucketId)))
        .write(
          KanbanBucketsCompanion(
            loadedPages: Value(loadedPages),
            taskCount: switch ((held, count)) {
              (final held?, _) => Value(held),
              (null, final count?) => Value(count),
              (null, null) => const Value.absent(),
            },
          ),
        );
    return true;
  });

  /// In bucket position order (then id); empty without a download.
  Future<StoredBoard> load(int viewId) async {
    final key = boardKey(viewId);
    final header = await (select(
      listSnapshots,
    )..where((s) => s.listKey.equals(key))).getSingleOrNull();
    final buckets =
        await (select(kanbanBuckets)
              ..where((b) => b.viewId.equals(viewId))
              ..orderBy([
                (b) => OrderingTerm.asc(b.position),
                (b) => OrderingTerm.asc(b.bucketId),
              ]))
            .get();
    final rows = await (select(
      listSnapshotTasks,
    )..where((t) => t.listKey.equals(key) & t.bucketId.isNotNull())).get();
    return (
      buckets: [
        for (final row in buckets)
          Bucket(
            id: row.bucketId,
            viewId: viewId,
            title: row.title,
            limit: row.taskLimit,
            count: row.taskCount,
            position: row.position,
          ),
      ],
      slots: {
        for (final row in rows)
          row.taskId: (bucketId: row.bucketId!, position: row.position),
      },
      loadedAt: header?.loadedAt,
    );
  }

  /// How many pages of each bucket's cards the board holds, by bucket id.
  Future<Map<int, int>> loadedPages(int viewId) async {
    final rows = await (select(
      kanbanBuckets,
    )..where((b) => b.viewId.equals(viewId))).get();
    return {for (final row in rows) row.bucketId: row.loadedPages};
  }

  /// The server accepted these placements of the task: its card moves on
  /// each downloaded board, and the counts of the buckets it left and
  /// entered follow, until the next download says otherwise. A placement
  /// without a position keeps the card's, and a card new to the board
  /// goes on top of its bucket, as the server keeps a task's position on a
  /// move.
  Future<void> applySentPlacements(
    int taskId,
    Map<int, BucketPlacement> placements,
  ) => transaction(() async {
    for (final MapEntry(key: viewId, value: placement) in placements.entries) {
      final key = boardKey(viewId);
      final target = await _bucket(viewId, placement.bucketId);
      if (target == null) continue;
      final current =
          await (select(listSnapshotTasks)
                ..where((t) => t.listKey.equals(key) & t.taskId.equals(taskId)))
              .getSingleOrNull();
      final position =
          placement.position ??
          current?.position ??
          await _topOf(key, placement.bucketId);
      await into(listSnapshotTasks).insertOnConflictUpdate(
        ListSnapshotTaskRow(
          listKey: key,
          taskId: taskId,
          position: position,
          bucketId: placement.bucketId,
        ),
      );
      final from = current?.bucketId;
      if (from == placement.bucketId) continue;
      await _setCount(target, target.taskCount + 1);
      if (from == null) continue;
      if (await _bucket(viewId, from) case final source?) {
        await _setCount(source, max(source.taskCount - 1, 0));
      }
    }
  });

  /// Removes the boards and list snapshots of views this device no longer
  /// has; the sync's project phase calls it after writing the views.
  Future<void> removeGoneViews() async {
    final viewKeys = selectOnly(projectViews)
      ..addColumns([const Constant('view:') + projectViews.id.cast<String>()]);
    Expression<bool> gone(GeneratedColumn<String> key) =>
        key.like('view:%') & key.isNotInQuery(viewKeys);
    await (delete(listSnapshotTasks)..where((t) => gone(t.listKey))).go();
    await (delete(listSnapshots)..where((s) => gone(s.listKey))).go();
    await (delete(kanbanBuckets)..where(
          (b) => b.viewId.isNotInQuery(
            selectOnly(projectViews)..addColumns([projectViews.id]),
          ),
        ))
        .go();
  }

  Future<KanbanBucketRow?> _bucket(int viewId, int bucketId) =>
      (select(kanbanBuckets)..where(
            (b) => b.viewId.equals(viewId) & b.bucketId.equals(bucketId),
          ))
          .getSingleOrNull();

  Future<int> _cardsIn(String key, int bucketId) {
    final cards = listSnapshotTasks.taskId.count();
    final query = selectOnly(listSnapshotTasks)
      ..addColumns([cards])
      ..where(
        listSnapshotTasks.listKey.equals(key) &
            listSnapshotTasks.bucketId.equals(bucketId),
      );
    return query.map((row) => row.read(cards)!).getSingle();
  }

  Future<void> _setCount(KanbanBucketRow bucket, int count) =>
      (update(kanbanBuckets)..where(
            (b) =>
                b.viewId.equals(bucket.viewId) &
                b.bucketId.equals(bucket.bucketId),
          ))
          .write(KanbanBucketsCompanion(taskCount: Value(count)));

  /// Above the bucket's first card, as the server puts a task on top.
  Future<double> _topOf(String key, int bucketId) async {
    final lowest = listSnapshotTasks.position.min();
    final query = selectOnly(listSnapshotTasks)
      ..addColumns([lowest])
      ..where(
        listSnapshotTasks.listKey.equals(key) &
            listSnapshotTasks.bucketId.equals(bucketId),
      );
    final value = await query.map((row) => row.read(lowest)).getSingle();
    return calculateItemPosition(null, value);
  }
}
