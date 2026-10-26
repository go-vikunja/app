import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';

/// The web's rule for putting a list's tasks in order by hand: a project's
/// list view (not the stand-in for a project without one), sorted
/// manually, the project not archived and [writable] for the user.
bool listIsReorderable({
  required int projectId,
  required ProjectView? view,
  required TaskListSort sort,
  required bool archived,
  bool writable = true,
}) =>
    projectId > 0 &&
    view?.kind == ProjectViewKind.list &&
    sort == TaskListSort.manual &&
    !archived &&
    writable;

/// A top-level row with the rows nested under it, which move with it, and
/// its position in the view.
@immutable
final class ListGroup {
  const new(this.rows, {required this.position, this.madeUp = false});

  /// The top-level row first.
  final List<ProjectListRow> rows;
  final double position;

  /// The view has no position for the task yet: [position] is where the
  /// order shows it.
  final bool madeUp;

  Task get task => rows.first.task;
}

/// [rows], a part of a manually sorted list, as groups with the positions
/// the order used: from [positions], else, for the tasks without one (they
/// sort first), made up below the first placed one, as the board places
/// its cards.
List<ListGroup> listGroupsOf(
  List<ProjectListRow> rows,
  Map<int, double> positions,
) {
  final starts = [
    for (final (index, row) in rows.indexed)
      if (row.depth == 0) index,
  ];
  final tops = [for (final start in starts) rows[start].task];
  final unplaced = tops
      .takeWhile((task) => !positions.containsKey(task.id))
      .length;
  final firstPlaced = unplaced < tops.length
      ? positions[tops[unplaced].id]!
      : calculateItemPosition(null, null) * (unplaced + 1);
  final groups = <ListGroup>[];
  for (final (index, start) in starts.indexed) {
    final end = index + 1 < starts.length ? starts[index + 1] : rows.length;
    final position = index < unplaced
        ? firstPlaced * (index + 1) / (unplaced + 1)
        : positions[tops[index].id] ?? groups.last.position;
    groups.add(
      ListGroup(
        rows.sublist(start, end),
        position: position,
        madeUp: !positions.containsKey(tops[index].id),
      ),
    );
  }
  return groups;
}

/// The positions, by task id, that put the group of [taskId] at [index] of
/// [groups], counted without it. Its own lies between its new neighbours
/// as the web computes it, else is a neighbour's own when both share it
/// and the task's id sorts between theirs (ties sort by id). The groups
/// that end up below it with a made-up position take that one, as without
/// a position they would still sort above it; they come first, so that
/// the list keeps its order until the task's own is queued. Null when it
/// is there already, not among [groups], or cannot land there.
Map<int, double>? planListMove(List<ListGroup> groups, int taskId, int index) {
  final from = groups.indexWhere((group) => group.task.id == taskId);
  if (from < 0) return null;
  final others = [...groups]..removeAt(from);
  final to = index.clamp(0, others.length);
  if (to == from) return null;
  final before = to > 0 ? others[to - 1] : null;
  final after = to < others.length ? others[to] : null;
  bool fits(double position) =>
      (before == null ||
          _sortsBefore(before.position, before.task.id, position, taskId)) &&
      (after == null ||
          _sortsBefore(position, taskId, after.position, after.task.id));

  final between = calculateItemPosition(before?.position, after?.position);
  final position = fits(between)
      ? between
      : before != null && after != null && fits(before.position)
      ? before.position
      : null;
  if (position == null) return null;
  return {
    for (final group in others.skip(to))
      if (group.madeUp) group.task.id: group.position,
    taskId: position,
  };
}

bool _sortsBefore(double a, int aId, double b, int bId) =>
    a != b ? a < b : aId < bId;
