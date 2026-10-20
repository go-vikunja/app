import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The fields of a task the filter language reads, as the server stores
/// them. A null [done], [priority] or [percentDone] stands for a legacy
/// NULL column, which fails every comparison like an unset date.
@immutable
final class FilterableTask {
  const new({
    required this.id,
    required this.projectId,
    this.title = '',
    this.description = '',
    this.done = false,
    this.doneAt,
    this.dueDate,
    this.startDate,
    this.endDate,
    this.created,
    this.updated,
    this.priority = 0,
    this.percentDone = 0,
    this.hexColor = '',
    this.index = 0,
    this.repeatAfterSeconds = 0,
    this.createdById = 0,
    this.createdByUsername,
    this.labelIds = const <int>{},
    this.assigneeUsernames = const <String>{},
    this.reminders = const [],
    this.bucketIds = const {},
  });

  factory fromTask(Task task, {Map<int, int> bucketIds = const {}}) =>
      FilterableTask(
        id: task.id,
        projectId: task.projectId,
        title: task.title,
        description: task.description,
        done: task.done,
        doneAt: task.doneAt,
        dueDate: task.dueDate,
        startDate: task.startDate,
        endDate: task.endDate,
        created: task.created,
        updated: task.updated,
        priority: task.priority.value,
        percentDone: task.percentDone,
        hexColor: task.hexColor,
        index: task.index,
        repeatAfterSeconds: task.repeatAfter.inSeconds,
        createdById: task.createdBy?.id ?? 0,
        createdByUsername: task.createdBy?.username,
        labelIds: {for (final label in task.labels) label.id},
        assigneeUsernames: {for (final user in task.assignees) user.username},
        reminders: [for (final reminder in task.reminders) ?reminder.reminder],
        bucketIds: bucketIds,
      );

  final int id;
  final int projectId;
  final String title;

  /// HTML, as stored.
  final String description;
  final bool? done;
  final DateTime? doneAt;
  final DateTime? dueDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? created;
  final DateTime? updated;
  final int? priority;

  /// 0..1.
  final double? percentDone;

  /// Six hex digits without `#`, or empty.
  final String hexColor;
  final int index;
  final int repeatAfterSeconds;
  final int createdById;

  /// Null when the creator is unknown.
  final String? createdByUsername;
  final Set<int> labelIds;
  final Set<String> assigneeUsernames;
  final List<DateTime> reminders;

  /// Bucket id by view id; only boards know them.
  final Map<int, int> bucketIds;
}
