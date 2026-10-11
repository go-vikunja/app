import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/task/task.dart';
import 'package:vikunja_domain/src/task/task_reminder.dart';

/// What the app sends to create a task; the server assigns id, index,
/// identifier and timestamps.
@immutable
final class NewTask {
  const new({
    required this.projectId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.startDate,
    this.endDate,
    this.priority = TaskPriority.unset,
    this.percentDone = 0,
    this.hexColor = '',
    this.repeatAfter = Duration.zero,
    this.repeatMode = RepeatMode.afterAmount,
    this.isFavorite = false,
    this.reminders = const [],
  });

  final int projectId;
  final String title;
  final String description;
  final DateTime? dueDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final TaskPriority priority;
  final double percentDone;

  /// Six hex digits without `#`, or empty.
  final String hexColor;
  final Duration repeatAfter;
  final RepeatMode repeatMode;
  final bool isFavorite;

  /// Sent with the create on both API versions. Labels and assignees are
  /// not: the server ignores labels in a create body, and both go through
  /// their own endpoints once the task exists.
  final List<TaskReminder> reminders;

  @override
  bool operator ==(Object other) =>
      other is NewTask &&
      other.projectId == projectId &&
      other.title == title &&
      other.description == description &&
      other.dueDate == dueDate &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.priority == priority &&
      other.percentDone == percentDone &&
      other.hexColor == hexColor &&
      other.repeatAfter == repeatAfter &&
      other.repeatMode == repeatMode &&
      other.isFavorite == isFavorite &&
      _sameReminders(other.reminders, reminders);

  static bool _sameReminders(List<TaskReminder> a, List<TaskReminder> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    projectId,
    title,
    description,
    dueDate,
    startDate,
    endDate,
    priority,
    percentDone,
    hexColor,
    repeatAfter,
    repeatMode,
    isFavorite,
    Object.hashAll(reminders),
  );
}
