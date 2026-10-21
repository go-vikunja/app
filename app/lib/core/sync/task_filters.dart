import 'package:vikunja_domain/vikunja_domain.dart';

/// The filter strings and sorts of the sync's task requests.
abstract final class TaskFilters {
  static const byId = [TaskSort(TaskSortField.id)];

  /// What every request that stores tasks asks for, for the rows' comment
  /// badge. A comment bumps the task's `updated`, so the delta sees new
  /// ones; reading a task does not, so a read elsewhere waits for the next
  /// change of the task or the daily full run.
  static const Set<TaskExpand> commentState = {
    TaskExpand.commentCount,
    TaskExpand.isUnread,
  };

  static const byUpdatedThenId = [
    TaskSort(TaskSortField.updated),
    TaskSort(TaskSortField.id),
  ];

  static const byUpdatedDescending = [
    TaskSort(TaskSortField.updated, descending: true),
  ];

  static String after(int id) => 'id > $id';

  static String updatedSince(DateTime since) =>
      "updated >= '${rfc3339(since)}'";

  static String createdSince(DateTime since) =>
      "created >= '${rfc3339(since)}'";

  static const byCreatedDescending = [
    TaskSort(TaskSortField.created, descending: true),
  ];

  /// Continues a list sorted by `(updated, id)` after its last item.
  ///
  /// The tie clause asks for `updated > U − 1 s` rather than `updated = U`:
  /// Vikunja 2.7.0 compares a date value as if it sat just above its second
  /// (`>=` behaves like `>`, `=` never matches), so equality can never pick
  /// up the rest of a second. Timestamps are whole seconds, so one second
  /// below means `updated >= U` under the server's and the exact semantics.
  static String updatedAfter(DateTime updated, int id) {
    final second = rfc3339(updated);
    final before = rfc3339(updated.subtract(const Duration(seconds: 1)));
    return "(updated > '$second') || (updated > '$before' && id > $id)";
  }

  /// Second precision, like the server's timestamps.
  static String rfc3339(DateTime moment) =>
      '${moment.toUtc().toIso8601String().substring(0, 19)}Z';
}
