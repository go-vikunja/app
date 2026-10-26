import 'dart:math';

import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

enum GanttArrowKind {
  /// Drawn solid in the error colour.
  blocking,

  /// Drawn dashed in the outline colour.
  precedes,
}

/// Where a shown bar sits: its row and its left and right edges, in day
/// columns (the right edge is the column after the bar's last day).
@immutable
final class GanttAnchor {
  const new({required this.row, required this.start, required this.end});

  final int row;
  final int start;
  final int end;
}

/// A relation drawn from the right edge of one bar to the left edge of
/// another.
@immutable
final class GanttArrow {
  const new({
    required this.fromTaskId,
    required this.toTaskId,
    required this.kind,
    required this.fromRow,
    required this.toRow,
    required this.fromColumn,
    required this.toColumn,
    this.fromOffset = 0,
    this.toOffset = 0,
  });

  final int fromTaskId;
  final int toTaskId;
  final GanttArrowKind kind;
  final int fromRow;
  final int toRow;

  /// The source bar's right edge, in day columns.
  final int fromColumn;

  /// The target bar's left edge, in day columns.
  final int toColumn;

  /// Logical pixels from the source row's centre, so that arrows sharing
  /// an end do not overlap.
  final double fromOffset;

  /// Logical pixels from the target row's centre.
  final double toOffset;

  @override
  bool operator ==(Object other) =>
      other is GanttArrow &&
      other.fromTaskId == fromTaskId &&
      other.toTaskId == toTaskId &&
      other.kind == kind &&
      other.fromRow == fromRow &&
      other.toRow == toRow &&
      other.fromColumn == fromColumn &&
      other.toColumn == toColumn &&
      other.fromOffset == fromOffset &&
      other.toOffset == toOffset;

  @override
  int get hashCode => Object.hash(
    fromTaskId,
    toTaskId,
    kind,
    fromRow,
    toRow,
    fromColumn,
    toColumn,
    fromOffset,
    toOffset,
  );

  @override
  String toString() =>
      'GanttArrow($fromTaskId -> $toTaskId, ${kind.name}, '
      'rows $fromRow -> $toRow, columns $fromColumn -> $toColumn, '
      'offsets $fromOffset -> $toOffset)';
}

/// The web's relation arrows (`ganttRelationArrows.ts`): a `blocking` or
/// `precedes` relation of one of [tasks] (in row order) becomes an arrow
/// when both ends have an anchor, after a task hidden by a collapsed
/// parent is replaced by the ancestor in [hiddenToAncestor]; an arrow from
/// a task to itself is dropped, and each pair of tasks gets one arrow per
/// kind. Arrows sharing a source or a target are spread over
/// min((n − 1) · 6, 24) logical pixels around the row's centre.
List<GanttArrow> ganttArrows({
  required Iterable<Task> tasks,
  required Map<int, GanttAnchor> anchors,
  Map<int, int> hiddenToAncestor = const {},
}) {
  final ends = <({int from, int to, GanttArrowKind kind})>[];
  final seen = <(int, int, GanttArrowKind)>{};
  for (final task in tasks) {
    for (final kind in GanttArrowKind.values) {
      for (final related
          in task.relatedTasks[kind._relation] ?? const <Task>[]) {
        final from = hiddenToAncestor[task.id] ?? task.id;
        final to = hiddenToAncestor[related.id] ?? related.id;
        if (!anchors.containsKey(from) || !anchors.containsKey(to)) continue;
        if (from == to) continue;
        final pair = from < to ? (from, to, kind) : (to, from, kind);
        if (!seen.add(pair)) continue;
        ends.add((from: from, to: to, kind: kind));
      }
    }
  }
  final fromOffsets = _spread([for (final end in ends) end.from]);
  final toOffsets = _spread([for (final end in ends) end.to]);
  return List.unmodifiable([
    for (final (index, end) in ends.indexed)
      GanttArrow(
        fromTaskId: end.from,
        toTaskId: end.to,
        kind: end.kind,
        fromRow: anchors[end.from]!.row,
        toRow: anchors[end.to]!.row,
        fromColumn: anchors[end.from]!.end,
        toColumn: anchors[end.to]!.start,
        fromOffset: fromOffsets[index],
        toOffset: toOffsets[index],
      ),
  ]);
}

const double _preferredSpread = 6;
const double _maxSpread = 24;

/// For each of [ids] in order, its offset among the entries sharing its id.
List<double> _spread(List<int> ids) {
  final counts = <int, int>{};
  for (final id in ids) {
    counts.update(id, (count) => count + 1, ifAbsent: () => 1);
  }
  final placed = <int, int>{};
  return [
    for (final id in ids)
      _offset(
        placed.update(id, (index) => index + 1, ifAbsent: () => 0),
        counts[id]!,
      ),
  ];
}

double _offset(int index, int count) {
  if (count < 2) return 0;
  final total = min((count - 1) * _preferredSpread, _maxSpread);
  return -total / 2 + index * total / (count - 1);
}

extension on GanttArrowKind {
  TaskRelationKind get _relation => switch (this) {
    GanttArrowKind.blocking => TaskRelationKind.blocking,
    GanttArrowKind.precedes => TaskRelationKind.precedes,
  };
}
