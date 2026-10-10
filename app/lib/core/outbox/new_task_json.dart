import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';

/// A `NewTask` as stored in a create's outbox op: the wire names, dates in
/// UTC, the repeat in seconds.
String encodeNewTask(NewTask task) => jsonEncode(newTaskToJson(task));

NewTask decodeNewTask(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> map => newTaskFromJson(map),
  _ => throw FormatException('not a stored task', json),
};

Map<String, Object?> newTaskToJson(NewTask task) => {
  'project_id': task.projectId,
  'title': task.title,
  'description': task.description,
  'due_date': ?task.dueDate?.toUtc().toIso8601String(),
  'start_date': ?task.startDate?.toUtc().toIso8601String(),
  'end_date': ?task.endDate?.toUtc().toIso8601String(),
  'priority': task.priority.value,
  'percent_done': task.percentDone,
  'hex_color': task.hexColor,
  'repeat_after': task.repeatAfter.inSeconds,
  'repeat_mode': task.repeatMode.value,
  'is_favorite': task.isFavorite,
};

NewTask newTaskFromJson(Map<String, Object?> json) => NewTask(
  projectId: json['project_id']! as int,
  title: json['title']! as String,
  description: json['description'] as String? ?? '',
  dueDate: _date(json['due_date']),
  startDate: _date(json['start_date']),
  endDate: _date(json['end_date']),
  priority: TaskPriority.fromValue(json['priority'] as int? ?? 0),
  percentDone: (json['percent_done'] as num?)?.toDouble() ?? 0,
  hexColor: json['hex_color'] as String? ?? '',
  repeatAfter: Duration(seconds: json['repeat_after'] as int? ?? 0),
  repeatMode: RepeatMode.fromValue(json['repeat_mode'] as int? ?? 0),
  isFavorite: json['is_favorite'] as bool? ?? false,
);

DateTime? _date(Object? value) => switch (value) {
  final String iso => DateTime.parse(iso).toUtc(),
  _ => null,
};
