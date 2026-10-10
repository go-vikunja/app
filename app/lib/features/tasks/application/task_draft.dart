import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/repeat_editor.dart';

/// The web colour picker's defaults, six lowercase hex digits without `#`.
const defaultTaskColors = [
  '1973ff',
  '7f23ff',
  'ff4136',
  'ff851b',
  'ffeb10',
  '00db60',
];

/// What the edit page holds while the user edits; [diff] turns it into the
/// fields that differ from the task it started from. Dates are UTC instants.
@immutable
final class TaskDraft {
  const new({
    required this.title,
    required this.projectId,
    required this.dueDate,
    required this.startDate,
    required this.endDate,
    required this.priority,
    required this.percentDone,
    required this.hexColor,
    required this.repeat,
  });

  factory fromTask(Task task) => TaskDraft(
    title: task.title,
    projectId: task.projectId,
    dueDate: task.dueDate?.toUtc(),
    startDate: task.startDate?.toUtc(),
    endDate: task.endDate?.toUtc(),
    priority: task.priority,
    percentDone: task.percentDone,
    hexColor: task.hexColor.toLowerCase(),
    repeat: RepeatSetting.fromTask(task),
  );

  final String title;
  final int projectId;
  final DateTime? dueDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final TaskPriority priority;

  /// 0..1.
  final double percentDone;

  /// Six lowercase hex digits without `#`, or empty.
  final String hexColor;
  final RepeatSetting repeat;

  bool get hasTitle => title.trim().isNotEmpty;

  bool get isValid => hasTitle && repeat.isValid;

  static const _unset = Object();

  TaskDraft copyWith({
    String? title,
    int? projectId,
    Object? dueDate = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    TaskPriority? priority,
    double? percentDone,
    String? hexColor,
    RepeatSetting? repeat,
  }) => TaskDraft(
    title: title ?? this.title,
    projectId: projectId ?? this.projectId,
    dueDate: _date(dueDate, this.dueDate),
    startDate: _date(startDate, this.startDate),
    endDate: _date(endDate, this.endDate),
    priority: priority ?? this.priority,
    percentDone: percentDone ?? this.percentDone,
    hexColor: hexColor?.toLowerCase() ?? this.hexColor,
    repeat: repeat ?? this.repeat,
  );

  static DateTime? _date(Object? given, DateTime? current) => switch (given) {
    _unset => current,
    final DateTime date => date.toUtc(),
    _ => null,
  };

  static final _lineBreaks = RegExp(r'\s*\n\s*');

  /// The title as sent: trimmed, and any line break a paste brought in
  /// becomes a space, because a title is one line everywhere.
  String get normalizedTitle => title.trim().replaceAll(_lineBreaks, ' ');

  /// Only what differs from [original]; empty when nothing does. A changed
  /// repeat sends the seconds and the mode that differ from the task's
  /// own, so removing a repeat is `0` and mode `0`.
  TaskChanges diff(Task original) {
    final base = TaskDraft.fromTask(original);
    final trimmedTitle = normalizedTitle;
    final repeatChanged = repeat != base.repeat;
    final repeatAfter = repeat.repeatAfter;
    final repeatMode = repeat.repeatMode;
    return TaskChanges(
      title: trimmedTitle != base.title ? trimmedTitle : null,
      projectId: projectId != base.projectId ? projectId : null,
      dueDate: _dateChange(dueDate, base.dueDate),
      startDate: _dateChange(startDate, base.startDate),
      endDate: _dateChange(endDate, base.endDate),
      priority: priority != base.priority ? priority.value : null,
      percentDone: percentDone != base.percentDone ? percentDone : null,
      hexColor: hexColor != base.hexColor ? hexColor : null,
      repeatAfter: repeatChanged && repeatAfter != original.repeatAfter
          ? repeatAfter
          : null,
      repeatMode: repeatChanged && repeatMode != original.repeatMode
          ? repeatMode
          : null,
    );
  }

  static DateChange? _dateChange(DateTime? value, DateTime? base) {
    if (value == base) return null;
    return value == null ? const DateChange.clear() : DateChange.set(value);
  }

  @override
  bool operator ==(Object other) =>
      other is TaskDraft &&
      other.title == title &&
      other.projectId == projectId &&
      other.dueDate == dueDate &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.priority == priority &&
      other.percentDone == percentDone &&
      other.hexColor == hexColor &&
      other.repeat == repeat;

  @override
  int get hashCode => Object.hash(
    title,
    projectId,
    dueDate,
    startDate,
    endDate,
    priority,
    percentDone,
    hexColor,
    repeat,
  );
}
