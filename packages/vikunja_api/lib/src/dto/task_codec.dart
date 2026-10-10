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
