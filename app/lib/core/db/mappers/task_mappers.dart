import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

/// Without queued changes; `upsertAll` keeps a row's own.
TaskRow taskRow(Task task, {String? syncRunId}) => TaskRow(
  id: task.id,
  projectId: task.projectId,
  title: task.title,
  description: task.description,
  done: task.done,
  doneAt: task.doneAt,
  dueDate: task.dueDate,
  startDate: task.startDate,
  endDate: task.endDate,
  priority: task.priority.value,
  percentDone: task.percentDone,
  hexColor: task.hexColor,
  identifier: task.identifier,
  taskIndex: task.index,
  isFavorite: task.isFavorite,
  position: task.position,
  repeatAfter: task.repeatAfter.inSeconds,
  repeatMode: task.repeatMode.value,
  bucketId: task.bucketId,
  createdById: task.createdBy?.id,
  created: task.created,
  updated: task.updated,
  commentCount: task.commentCount,
  isUnread: task.isUnread,
  syncRunId: syncRunId,
  pendingDelete: false,
);

List<TaskLabelRow> taskLabelRows(Task task) => [
  for (final label in task.labels)
    TaskLabelRow(taskId: task.id, labelId: label.id),
];

List<TaskAssigneeRow> taskAssigneeRows(Task task) => [
  for (final user in task.assignees)
    TaskAssigneeRow(taskId: task.id, userId: user.id),
];

List<TaskReminderRow> taskReminderRows(Task task) =>
    reminderRows(task.id, task.reminders);

List<TaskReminderRow> reminderRows(int taskId, List<TaskReminder> reminders) =>
    [
      for (final (ordinal, reminder) in reminders.indexed)
        TaskReminderRow(
          taskId: taskId,
          ordinal: ordinal,
          reminder: reminder.reminder,
          relativePeriod: reminder.relativePeriod.inSeconds,
          relativeTo: reminder.relativeTo?.wireName,
        ),
    ];

/// Only the edges; the related tasks themselves are rows of their own.
List<TaskRelationRow> taskRelationRows(Task task) => [
  for (final MapEntry(key: kind, value: others) in task.relatedTasks.entries)
    for (final other in others)
      TaskRelationRow(
        taskId: task.id,
        otherTaskId: other.id,
        kind: kind.wireName,
      ),
];

Task taskFromRow(
  TaskRow row, {
  User? createdBy,
  List<Label> labels = const [],
  List<User> assignees = const [],
  List<TaskReminder> reminders = const [],
  Map<TaskRelationKind, List<Task>> relatedTasks = const {},
}) => Task(
  id: row.id,
  title: row.title,
  projectId: row.projectId,
  description: row.description,
  done: row.done,
  doneAt: row.doneAt,
  dueDate: row.dueDate,
  startDate: row.startDate,
  endDate: row.endDate,
  priority: TaskPriority.fromValue(row.priority),
  percentDone: row.percentDone,
  hexColor: row.hexColor,
  identifier: row.identifier,
  index: row.taskIndex,
  isFavorite: row.isFavorite,
  position: row.position,
  labels: labels,
  assignees: assignees,
  reminders: reminders,
  repeatAfter: Duration(seconds: row.repeatAfter),
  repeatMode: RepeatMode.fromValue(row.repeatMode),
  relatedTasks: relatedTasks,
  bucketId: row.bucketId,
  createdBy: createdBy,
  created: row.created,
  updated: row.updated,
  commentCount: row.commentCount,
  isUnread: row.isUnread,
);

TaskReminder reminderFromRow(TaskReminderRow row) => TaskReminder(
  reminder: row.reminder,
  relativePeriod: Duration(seconds: row.relativePeriod),
  relativeTo: ReminderRelativeTo.fromWire(row.relativeTo),
);
