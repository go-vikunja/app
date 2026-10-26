import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// The web's rule: cards move only on a manual board the user may change,
/// in a project not archived and [writable] for the user.
bool boardIsReadOnly(
  ProjectView view, {
  required bool archived,
  bool writable = true,
}) =>
    archived ||
    !writable ||
    view.bucketConfigurationMode == BucketConfigurationMode.filter;

/// A column at its limit takes no more cards, except its own.
bool columnIsFull(BoardColumn column) =>
    column.bucket.limit > 0 && column.shownCount >= column.bucket.limit;

/// What moving a card queues.
@immutable
sealed class CardMove {
  const new();
}

/// The card's placement, with the done state the move changes.
final class PlaceCard extends CardMove {
  const new(this.placement, {this.done});

  final BucketPlacement placement;
  final bool? done;

  @override
  bool operator ==(Object other) =>
      other is PlaceCard && other.placement == placement && other.done == done;

  @override
  int get hashCode => Object.hash(placement, done);

  @override
  String toString() => 'PlaceCard($placement, done: $done)';
}

/// A repeating task dropped into the done column: marked done and placed
/// in [reopensIn], the view's default column, without a position. The
/// server moves its dates on and reopens it there, so the move finds it in
/// place and the board follows it; a move into the done column would mark
/// it done a second time.
final class MarkCardDone extends CardMove {
  const new(this.reopensIn);

  final int reopensIn;

  BucketPlacement get placement => BucketPlacement(bucketId: reopensIn);

  @override
  bool operator ==(Object other) =>
      other is MarkCardDone && other.reopensIn == reopensIn;

  @override
  int get hashCode => reopensIn.hashCode;

  @override
  String toString() => 'MarkCardDone(reopensIn: $reopensIn)';
}

/// The target column is at its limit.
final class ColumnFull extends CardMove {
  const new();

  @override
  bool operator ==(Object other) => other is ColumnFull;

  @override
  int get hashCode => (ColumnFull).hashCode;
}

/// Where the server puts a task it is not told where to put: the view's
/// default column, or the leftmost when it names none.
BoardColumn? defaultColumnOf(ProjectView view, List<BoardColumn> columns) =>
    columns
        .where((column) => column.bucket.id == view.defaultBucketId)
        .firstOrNull ??
    columns.firstOrNull;

/// Moving [task] to [index] of the column of [toBucketId], counted among
/// that column's cards without [task]; null when it stays where it is. The
/// position lies between the cards above and below, as the web computes it
/// from the neighbours (`buildBoard` gives every card a position). In a
/// column with cards not loaded yet, a card goes no lower than above the
/// last one loaded: below it, it would sort onto a page not loaded and
/// vanish at the next download.
CardMove? planCardMove({
  required ProjectView view,
  required List<BoardColumn> columns,
  required Task task,
  required int toBucketId,
  required int index,
}) {
  final from = columns
      .where((column) => column.tasks.any((card) => card.id == task.id))
      .firstOrNull;
  final to = columns
      .where((column) => column.bucket.id == toBucketId)
      .firstOrNull;
  if (from == null || to == null) return null;
  final sameColumn = identical(from, to);
  if (!sameColumn && columnIsFull(to)) return const ColumnFull();
  final doneBucketId = view.doneBucketId;
  final intoDoneColumn = doneBucketId != 0 && to.bucket.id == doneBucketId;
  if (intoDoneColumn && task.repeats) {
    final reopensIn = defaultColumnOf(view, columns)!.bucket.id;
    return sameColumn ? null : MarkCardDone(reopensIn);
  }
  final others = [
    for (final card in to.tasks)
      if (card.id != task.id) card,
  ];
  final current = sameColumn
      ? from.tasks.indexWhere((card) => card.id == task.id)
      : null;
  var at = index.clamp(0, others.length);
  if (at == current) return null;
  if (to.hasMore && others.isNotEmpty && at == others.length) at--;
  if (at == current) return null;
  final position = calculateItemPosition(
    at > 0 ? others[at - 1].position : null,
    at < others.length ? others[at].position : null,
  );
  final intoDone = intoDoneColumn && !sameColumn;
  final outOfDone =
      doneBucketId != 0 && !sameColumn && from.bucket.id == doneBucketId;
  return PlaceCard(
    BucketPlacement(bucketId: to.bucket.id, position: position),
    done: intoDone ? true : (outOfDone ? false : null),
  );
}

/// The positions of [count] tasks added on top of a column whose first
/// card is at [topPosition], the first on top: spread below it (half of it
/// for one task), or 2^16 apart in an empty column.
List<double> positionsOnTop(double? topPosition, {required int count}) => [
  for (var i = 1; i <= count; i++)
    if (topPosition == null)
      calculateItemPosition(null, null) * i
    else
      topPosition * i / (count + 1),
];
