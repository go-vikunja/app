import 'package:vikunja_app/domain/entities/task.dart';

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
      return aHas ? -1 : 1;
    }

    return b.id.compareTo(a.id);
  });
  return sorted;
}
