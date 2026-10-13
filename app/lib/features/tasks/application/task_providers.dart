import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'task_providers.g.dart';

/// Every task, done ones included, without its lists or relations, for a
/// search over titles and identifiers. Stays loading without an account.
@riverpod
Stream<List<Task>> searchableTasks(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchSearchableTasks() ??
    const Stream.empty();

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.
@riverpod
class TaskById extends _$TaskById {
  @override
  Stream<Task?> build(int taskId) =>
      ref.watch(taskRepositoryProvider)?.watchTask(taskId) ??
      const Stream.empty();

  /// `Task ==` leaves out the lists, the relations and the repeat, so an
  /// edit of only those would not reach the screens.
  @override
  bool updateShouldNotify(AsyncValue<Task?> previous, AsyncValue<Task?> next) {
    if (previous != next) return true;
    final (before, after) = (previous.value, next.value);
    if (before == null || after == null) return false;
    return !listEquals(before.labels, after.labels) ||
        !listEquals(before.assignees, after.assignees) ||
        !listEquals(before.reminders, after.reminders) ||
        before.repeatAfter != after.repeatAfter ||
        before.repeatMode != after.repeatMode ||
        !_sameRelations(before.relatedTasks, after.relatedTasks);
  }

  static bool _sameRelations(
    Map<TaskRelationKind, List<Task>> a,
    Map<TaskRelationKind, List<Task>> b,
  ) =>
      a.length == b.length &&
      a.entries.every((entry) => listEquals(entry.value, b[entry.key]));
}
