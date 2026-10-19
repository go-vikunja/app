import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/kanban/item_position.dart';
import 'package:vikunja_logic/src/lists/task_order.dart';
import 'package:vikunja_logic/src/lists/view_filter_kind.dart';

@immutable
final class BoardColumn {
  const new({
    required this.bucket,
    required this.tasks,
    required this.shownCount,
    required this.hasMore,
  });

  final Bucket bucket;

  /// In board order, each with its position in this view: the queued or
  /// downloaded one, and for the cards on top that have none, positions
  /// spread below the first card that has one, so that the neighbours of a
  /// drop always have a position.
  final List<Task> tasks;

  /// The server's count with the cards moved in and out here, never fewer
  /// than [tasks].
  final int shownCount;

  /// The server holds more tasks in this bucket than were downloaded.
  final bool hasMore;
}

typedef _Listed = ({int bucketId, double position});

/// The board of a kanban [view] as the device knows it: [buckets] and
/// [snapshot] (task id to bucket and position) from the last download at
/// [loadedAt], the project's local tasks in [projectTasks] (with their
/// unsent changes applied) and the unsent placements on this view by task
/// id in [queued].
///
/// A task's column is its queued placement; else, when its done state may
/// have changed after the download (a done change in [queuedDoneChanges];
/// for a done task, done after [loadedAt], or `updated` after it when the
/// done moment is unknown; for an open one, `updated` after it), the done
/// bucket for a done task when the view has one and the default bucket
/// (the leftmost when the view names none) for an open task downloaded in
/// the done bucket, as the server moves them; else the downloaded bucket,
/// or the default bucket when that is gone. Choosing or clearing the done
/// bucket moves no task on the server, so a done task downloaded elsewhere
/// stays there, and so does an open one in the done bucket. Tasks the
/// download did not list show only when they are newer than it (a
/// temporary id, created or updated after [loadedAt], as a task moved into
/// the project is, or in [movedHere], whose move into the project is not
/// sent yet), on top of the default bucket or, done, the done bucket; older
/// ones are on pages not downloaded yet. A view filter the device can
/// evaluate (none, `done = false`, `done = true`) is applied to every card;
/// under any other filter newer tasks wait for the next download. A
/// filter-mode view shows the download only: the server decides its
/// buckets and refuses moves.
List<BoardColumn> buildBoard({
  required ProjectView view,
  required List<Bucket> buckets,
  required Map<int, ({int bucketId, double position})> snapshot,
  required DateTime? loadedAt,
  required List<Task> projectTasks,
  required Map<int, BucketPlacement> queued,
  Set<int> movedHere = const {},
  Set<int> queuedDoneChanges = const {},
}) {
  final columns = [...buckets]..sort(compareBucketOrder);
  if (columns.isEmpty) return const [];
  final columnIds = {for (final bucket in columns) bucket.id};
  final byFilter =
      view.bucketConfigurationMode == BucketConfigurationMode.filter;
  final filter = classifyViewFilter(view.filter);
  final defaultId = columnIds.contains(view.defaultBucketId)
      ? view.defaultBucketId
      : columns.first.id;
  final doneId =
      !byFilter &&
          view.doneBucketId != 0 &&
          columnIds.contains(view.doneBucketId)
      ? view.doneBucketId
      : null;

  _Card? place(Task task) {
    final listed = snapshot[task.id];
    if (byFilter) {
      if (listed == null || !columnIds.contains(listed.bucketId)) return null;
      return _Card(task, listed.bucketId, listed.position, listed);
    }
    if (!_matches(task, filter)) return null;
    if (queued[task.id] case final placement?
        when columnIds.contains(placement.bucketId)) {
      return _Card(task, placement.bucketId, placement.position, listed);
    }
    if (listed == null) {
      if (filter == ViewFilterKind.other ||
          !(movedHere.contains(task.id) || _isNewer(task, loadedAt))) {
        return null;
      }
      return _Card(
        task,
        task.done ? doneId ?? defaultId : defaultId,
        null,
        null,
      );
    }
    final doneMayHaveChanged =
        queuedDoneChanges.contains(task.id) ||
        _doneChangedAfter(task, loadedAt);
    final bucketId = switch (listed.bucketId) {
      _ when doneMayHaveChanged && task.done && doneId != null => doneId,
      final listedId
          when doneMayHaveChanged && !task.done && listedId == doneId =>
        defaultId,
      final listedId when columnIds.contains(listedId) => listedId,
      _ => defaultId,
    };
    return _Card(task, bucketId, listed.position, listed);
  }

  final cardsByBucket = {for (final id in columnIds) id: <_Card>[]};
  for (final task in projectTasks) {
    if (task.projectId != view.projectId) continue;
    if (place(task) case final card?) cardsByBucket[card.bucketId]!.add(card);
  }

  final downloaded = <int, int>{};
  for (final listed in snapshot.values) {
    downloaded.update(listed.bucketId, (n) => n + 1, ifAbsent: () => 1);
  }

  return [
    for (final bucket in columns)
      _column(bucket, cardsByBucket[bucket.id]!, downloaded[bucket.id] ?? 0),
  ];
}

BoardColumn _column(Bucket bucket, List<_Card> cards, int downloaded) {
  cards.sort(_compareCards);
  final stayed = cards.where((card) => card.listedIn == bucket.id).length;
  final movedIn = cards.length - stayed;
  final movedOut = downloaded - stayed;
  return BoardColumn(
    bucket: bucket,
    tasks: List.unmodifiable(_withPositions(cards)),
    shownCount: math.max(bucket.count + movedIn - movedOut, cards.length),
    hasMore: bucket.count > downloaded,
  );
}

Iterable<Task> _withPositions(List<_Card> cards) sync* {
  final unplaced = cards.takeWhile((card) => card.position == null).length;
  final firstPosition = unplaced < cards.length
      ? cards[unplaced].position!
      : calculateItemPosition(null, null) * (unplaced + 1);
  for (final (index, card) in cards.indexed) {
    yield card.task.copyWith(
      position: card.position ?? firstPosition * (index + 1) / (unplaced + 1),
    );
  }
}

bool _matches(Task task, ViewFilterKind filter) => switch (filter) {
  ViewFilterKind.openOnly => !task.done,
  ViewFilterKind.doneOnly => task.done,
  ViewFilterKind.none || ViewFilterKind.other => true,
};

bool _isNewer(Task task, DateTime? loadedAt) {
  if (loadedAt == null || task.id < 0) return true;
  return _after(task.created, loadedAt) || _after(task.updated, loadedAt);
}

/// Every edit moves `updated`; `done_at` dates a done state exactly.
bool _doneChangedAfter(Task task, DateTime? loadedAt) {
  if (loadedAt == null) return true;
  if (task.doneAt case final doneAt? when task.done) {
    return doneAt.isAfter(loadedAt);
  }
  return _after(task.updated, loadedAt);
}

bool _after(DateTime? time, DateTime loadedAt) =>
    time != null && time.isAfter(loadedAt);

/// The board's column order: position, then id, as the server keeps
/// positions as sent and lists ties in storage order.
int compareBucketOrder(Bucket a, Bucket b) {
  final byPosition = a.position.compareTo(b.position);
  return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
}

int _compareCards(_Card a, _Card b) => switch ((a.position, b.position)) {
  (null, null) => compareNewestFirst(a.task, b.task),
  (null, _) => -1,
  (_, null) => 1,
  (final double aPosition, final double bPosition) =>
    aPosition != bPosition
        ? aPosition.compareTo(bPosition)
        : a.task.id.compareTo(b.task.id),
};

final class _Card {
  new(this.task, this.bucketId, this.position, _Listed? listed)
    : listedIn = listed?.bucketId;

  final Task task;
  final int bucketId;
  final double? position;
  final int? listedIn;
}
