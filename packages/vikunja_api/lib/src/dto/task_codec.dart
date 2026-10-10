import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/label_codec.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

Task parseTask(Object? json) {
  final map = objectOf(json, 'task');
  return Task(
    id: requireInt(map, 'id', 'task'),
    title: requireString(map, 'title', 'task'),
    projectId: requireInt(map, 'project_id', 'task'),
    description: stringOr(map, 'description', ''),
    done: boolOr(map, 'done', fallback: false),
    doneAt: dateOf(map['done_at']),
    dueDate: dateOf(map['due_date']),
    startDate: dateOf(map['start_date']),
    endDate: dateOf(map['end_date']),
    priority: TaskPriority.fromValue(intOr(map, 'priority', 0)),
    percentDone: doubleOr(map, 'percent_done', 0),
    hexColor: hexColorOf(map['hex_color']),
    identifier: stringOr(map, 'identifier', ''),
    index: intOr(map, 'index', 0),
    isFavorite: boolOr(map, 'is_favorite', fallback: false),
    position: doubleOr(map, 'position', 0),
    labels: List.unmodifiable(objectListOf(map['labels']).map(parseLabel)),
    assignees: List.unmodifiable(
      objectListOf(map['assignees']).map(parseUser).nonNulls,
    ),
    reminders: List.unmodifiable(
      objectListOf(map['reminders']).map(parseReminder),
    ),
    repeatAfter: Duration(seconds: intOr(map, 'repeat_after', 0)),
    repeatMode: RepeatMode.fromValue(intOr(map, 'repeat_mode', 0)),
    relatedTasks: _relatedTasksOf(map['related_tasks']),
    bucketId: intOr(map, 'bucket_id', 0),
    createdBy: parseUser(map['created_by']),
    created: dateOf(map['created']),
    updated: dateOf(map['updated']),
    commentCount: switch (map['comment_count']) {
      final int count => count,
      _ => null,
    },
    isUnread: switch (map['is_unread']) {
      final bool unread => unread,
      _ => null,
    },
  );
}

const mergePatchContentType = 'application/merge-patch+json';

/// The set fields of [changes] under their wire names: a v2 merge-patch, or
/// the overlay for a v1 full replace. The zero date clears a date.
Map<String, Object?> encodeTaskChanges(TaskChanges changes) => {
  'title': ?changes.title,
  'description': ?changes.description,
  'done': ?changes.done,
  'is_favorite': ?changes.isFavorite,
  'priority': ?changes.priority,
  'percent_done': ?changes.percentDone,
  if (changes.hexColor case final hexColor?)
    'hex_color': _hexColorWire(hexColor),
  if (changes.dueDate case final dueDate?)
    'due_date': _encodeDateChange(dueDate),
  if (changes.startDate case final startDate?)
    'start_date': _encodeDateChange(startDate),
  if (changes.endDate case final endDate?)
    'end_date': _encodeDateChange(endDate),
  'repeat_after': ?changes.repeatAfter?.inSeconds,
  'repeat_mode': ?changes.repeatMode?.value,
  'project_id': ?changes.projectId,
};

/// The create body for both versions. The project is only in the path: a
/// `project_id` in a v1 body overrides the path (v2 ignores it). Unset
/// dates are omitted; the server stores the zero date for them.
Map<String, Object?> encodeNewTask(NewTask task) => {
  'title': task.title,
  'description': task.description,
  if (task.dueDate case final dueDate?) 'due_date': encodeDate(dueDate),
  if (task.startDate case final startDate?) 'start_date': encodeDate(startDate),
  if (task.endDate case final endDate?) 'end_date': encodeDate(endDate),
  'priority': task.priority.value,
  'percent_done': task.percentDone,
  'hex_color': _hexColorWire(task.hexColor),
  'repeat_after': task.repeatAfter.inSeconds,
  'repeat_mode': task.repeatMode.value,
  'is_favorite': task.isFavorite,
};

String _hexColorWire(String hexColor) =>
    hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;

String _encodeDateChange(DateChange change) => switch (change) {
  SetDate(:final value) => encodeDate(value),
  ClearDate() => zeroDate,
};

TaskReminder parseReminder(Object? json) {
  final map = objectOf(json, 'reminder');
  return TaskReminder(
    reminder: dateOf(map['reminder']),
    relativePeriod: Duration(seconds: intOr(map, 'relative_period', 0)),
    relativeTo: ReminderRelativeTo.fromWire(stringOr(map, 'relative_to', '')),
  );
}

/// `{}` or `null` for no relations; kinds this client does not know are
/// dropped. Nested tasks arrive with `related_tasks: null`.
Map<TaskRelationKind, List<Task>> _relatedTasksOf(Object? value) {
  if (value is! Map<String, Object?>) return const {};
  final related = <TaskRelationKind, List<Task>>{};
  for (final MapEntry(:key, value: tasks) in value.entries) {
    final kind = TaskRelationKind.fromWire(key);
    if (kind == null) continue;
    related[kind] = List.unmodifiable(objectListOf(tasks).map(parseTask));
  }
  return Map.unmodifiable(related);
}
