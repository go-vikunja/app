import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/task/task.dart';

/// A date field edit: set to an instant or cleared. Null in [TaskChanges]
/// means "unchanged".
@immutable
sealed class DateChange {
  const new();

  const factory set(DateTime value) = SetDate;

  const factory clear() = ClearDate;
}

final class SetDate extends DateChange {
  const new(this.value);

  final DateTime value;

  @override
  bool operator ==(Object other) => other is SetDate && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class ClearDate extends DateChange {
  const new();

  @override
  bool operator ==(Object other) => other is ClearDate;

  @override
  int get hashCode => 0;
}

/// The fields of one task edit. Every null field is left as it is on the
/// server; the adapters send only what is set (v2 merge-patch) or overlay
/// it on a fresh read (v1 full replace).
@immutable
final class TaskChanges {
  const new({
    this.title,
    this.description,
    this.done,
    this.isFavorite,
    this.priority,
    this.percentDone,
    this.hexColor,
    this.dueDate,
    this.startDate,
    this.endDate,
    this.repeatAfter,
    this.repeatMode,
    this.projectId,
  });

  final String? title;
  final String? description;
  final bool? done;
  final bool? isFavorite;
  final int? priority;
  final double? percentDone;
  final String? hexColor;
  final DateChange? dueDate;
  final DateChange? startDate;
  final DateChange? endDate;

  /// `Duration.zero` with [RepeatMode.afterAmount] removes the repeat.
  final Duration? repeatAfter;
  final RepeatMode? repeatMode;

  /// Moves the task; the server reassigns `index` and `identifier`.
  final int? projectId;

  bool get isEmpty =>
      title == null &&
      description == null &&
      done == null &&
      isFavorite == null &&
      priority == null &&
      percentDone == null &&
      hexColor == null &&
      dueDate == null &&
      startDate == null &&
      endDate == null &&
      repeatAfter == null &&
      repeatMode == null &&
      projectId == null;

  /// [later] wins where both set a field.
  TaskChanges merge(TaskChanges later) => TaskChanges(
    title: later.title ?? title,
    description: later.description ?? description,
    done: later.done ?? done,
    isFavorite: later.isFavorite ?? isFavorite,
    priority: later.priority ?? priority,
    percentDone: later.percentDone ?? percentDone,
    hexColor: later.hexColor ?? hexColor,
    dueDate: later.dueDate ?? dueDate,
    startDate: later.startDate ?? startDate,
    endDate: later.endDate ?? endDate,
    repeatAfter: later.repeatAfter ?? repeatAfter,
    repeatMode: later.repeatMode ?? repeatMode,
    projectId: later.projectId ?? projectId,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskChanges &&
      other.title == title &&
      other.description == description &&
      other.done == done &&
      other.isFavorite == isFavorite &&
      other.priority == priority &&
      other.percentDone == percentDone &&
      other.hexColor == hexColor &&
      other.dueDate == dueDate &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.repeatAfter == repeatAfter &&
      other.repeatMode == repeatMode &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    done,
    isFavorite,
    priority,
    percentDone,
    hexColor,
    dueDate,
    startDate,
    endDate,
    repeatAfter,
    repeatMode,
    projectId,
  );
}
