import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';

/// `TaskChanges` as stored in the outbox and in `tasks.pending_changes`:
/// the wire names, absent for unchanged, an empty string for a cleared date.
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
);

String _dateJson(DateChange change) => switch (change) {
  SetDate(:final value) => value.toUtc().toIso8601String(),
  ClearDate() => '',
};

DateChange? _dateChange(Object? value) => switch (value) {
  '' => const DateChange.clear(),
  final String iso => DateChange.set(DateTime.parse(iso).toUtc()),
  _ => null,
};
