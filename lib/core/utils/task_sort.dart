import 'package:vikunja_app/domain/entities/task.dart';

/// Returns a new list of tasks sorted for the overview page.
///
/// Ordering rules:
/// 1) Tasks with a due date first (soonest due date at the top)
/// 2) Tasks without a due date afterwards
/// 3) Tie-breaker within groups: newest first by id (desc)
List<Task> sortTasksForOverview(List<Task> tasks) {
  final sorted = [...tasks];
  sorted.sort((a, b) {
    final aHasDue = a.hasDueDate;
    final bHasDue = b.hasDueDate;

    if (aHasDue != bHasDue) {
      return aHasDue ? -1 : 1;
    }

    if (aHasDue && bHasDue) {
      final cmpDue = a.dueDate!.compareTo(b.dueDate!);
      if (cmpDue != 0) return cmpDue;
      return b.id.compareTo(a.id);
    }

    return b.id.compareTo(a.id);
  });
  return sorted;
}

/// Returns a new list of tasks sorted by their position value (ascending),
/// putting tasks without a position at the end. Ties are broken by id desc.
List<Task> sortTasksByPosition(List<Task> tasks) {
  final sorted = [...tasks];
  sorted.sort((a, b) {
    final ap = a.position;
    final bp = b.position;

    final aHas = ap != null;
    final bHas = bp != null;

    if (aHas && bHas) {
      final cmp = ap.compareTo(bp);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    }

    if (aHas != bHas) {
      // Items with a position come first
      return aHas ? -1 : 1;
    }

    // Neither has a position: newest first by id desc
    return b.id.compareTo(a.id);
  });
  return sorted;
}
