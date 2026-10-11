import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';

/// `TaskChanges` as stored in the outbox and in `tasks.pending_changes`:
/// the wire names, absent for unchanged, an empty string for a cleared date,
/// label and assignee deltas as `{"added": [...], "removed": [...]}`.
String encodeTaskChanges(TaskChanges changes) =>
    jsonEncode(taskChangesToJson(changes));

TaskChanges decodeTaskChanges(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> map => taskChangesFromJson(map),
  _ => const TaskChanges(),
};

Map<String, Object?> taskChangesToJson(TaskChanges changes) => {
  'title': ?changes.title,
  'description': ?changes.description,
  'done': ?changes.done,
  'is_favorite': ?changes.isFavorite,
  'priority': ?changes.priority,
  'percent_done': ?changes.percentDone,
  'hex_color': ?changes.hexColor,
  if (changes.dueDate case final date?) 'due_date': _dateJson(date),
  if (changes.startDate case final date?) 'start_date': _dateJson(date),
  if (changes.endDate case final date?) 'end_date': _dateJson(date),
  'repeat_after': ?changes.repeatAfter?.inSeconds,
  'repeat_mode': ?changes.repeatMode?.value,
  'project_id': ?changes.projectId,
  if (changes.labels case final labels?) 'labels': _idSetJson(labels),
  if (changes.assignees case final assignees?)
    'assignees': _idSetJson(assignees),
  if (changes.reminders case final reminders?)
    'reminders': remindersToJson(reminders),
};

TaskChanges taskChangesFromJson(Map<String, Object?> json) => TaskChanges(
  title: json['title'] as String?,
  description: json['description'] as String?,
  done: json['done'] as bool?,
  isFavorite: json['is_favorite'] as bool?,
  priority: json['priority'] as int?,
  percentDone: (json['percent_done'] as num?)?.toDouble(),
  hexColor: json['hex_color'] as String?,
  dueDate: _dateChange(json['due_date']),
  startDate: _dateChange(json['start_date']),
  endDate: _dateChange(json['end_date']),
  repeatAfter: switch (json['repeat_after']) {
    final int seconds => Duration(seconds: seconds),
    _ => null,
  },
  repeatMode: switch (json['repeat_mode']) {
    final int value => RepeatMode.fromValue(value),
    _ => null,
  },
  projectId: json['project_id'] as int?,
  labels: _idSetChange(json['labels']),
  assignees: _idSetChange(json['assignees']),
  reminders: switch (json['reminders']) {
    final List<Object?> list => remindersFromJson(list),
    _ => null,
  },
);

/// Instants in UTC; `reminder` is absent while a relative one has none.
List<Map<String, Object?>> remindersToJson(List<TaskReminder> reminders) => [
  for (final reminder in reminders)
    {
      'reminder': ?reminder.reminder?.toUtc().toIso8601String(),
      'relative_period': reminder.relativePeriod.inSeconds,
      'relative_to': ?reminder.relativeTo?.wireName,
    },
];

List<TaskReminder> remindersFromJson(List<Object?> json) => [
  for (final item in json)
    if (item is Map<String, Object?>)
      TaskReminder(
        reminder: switch (item['reminder']) {
          final String iso => DateTime.parse(iso).toUtc(),
          _ => null,
        },
        relativePeriod: Duration(seconds: item['relative_period'] as int? ?? 0),
        relativeTo: ReminderRelativeTo.fromWire(item['relative_to'] as String?),
      ),
];

Map<String, Object?> _idSetJson(IdSetChange change) => {
  'added': [...change.added]..sort(),
  'removed': [...change.removed]..sort(),
};

IdSetChange? _idSetChange(Object? value) => switch (value) {
  final Map<String, Object?> map => IdSetChange(
    added: _ids(map['added']),
    removed: _ids(map['removed']),
  ),
  _ => null,
};

Set<int> _ids(Object? value) => {
  if (value is List<Object?>)
    for (final id in value)
      if (id is int) id,
};

String _dateJson(DateChange change) => switch (change) {
  SetDate(:final value) => value.toUtc().toIso8601String(),
  ClearDate() => '',
};

DateChange? _dateChange(Object? value) => switch (value) {
  '' => const DateChange.clear(),
  final String iso => DateChange.set(DateTime.parse(iso).toUtc()),
  _ => null,
};
