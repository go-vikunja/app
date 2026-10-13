import 'package:vikunja_domain/vikunja_domain.dart';

Project sampleProject({
  required int id,
  required String title,
  int parent = 0,
  double position = 0,
  bool favorite = false,
  bool archived = false,
  String hexColor = '',
  String identifier = '',
}) => Project(
  id: id,
  title: title,
  parentProjectId: parent,
  position: position,
  isFavorite: favorite,
  isArchived: archived,
  hexColor: hexColor,
  identifier: identifier,
);

Label sampleLabel({
  required int id,
  required String title,
  String hexColor = '',
}) => Label(id: id, title: title, hexColor: hexColor);

Task sampleTask({
  required int id,
  required String title,
  int projectId = 1,
  DateTime? due,
  DateTime? start,
  DateTime? end,
  DateTime? doneAt,
  bool done = false,
  TaskPriority priority = TaskPriority.unset,
  double percentDone = 0,
  List<Label> labels = const [],
  List<User> assignees = const [],
  List<TaskReminder> reminders = const [],
  Duration repeatAfter = Duration.zero,
  RepeatMode repeatMode = RepeatMode.afterAmount,
  bool favorite = false,
  String? identifier,
  String description = '',
  double position = 0,
  DateTime? updated,
}) => Task(
  id: id,
  title: title,
  projectId: projectId,
  index: id,
  identifier: identifier ?? '-$id',
  dueDate: due?.toUtc(),
  startDate: start?.toUtc(),
  endDate: end?.toUtc(),
  doneAt: doneAt?.toUtc(),
  updated: updated?.toUtc(),
  done: done,
  priority: priority,
  percentDone: percentDone,
  labels: labels,
  assignees: assignees,
  reminders: reminders,
  repeatAfter: repeatAfter,
  repeatMode: repeatMode,
  isFavorite: favorite,
  description: description,
  position: position,
);

/// A server notification shaped like 2.7.0's: `task.assigned` by default,
/// with the doer, the task and its project in the payload; [extra] adds
/// or replaces payload entries (a `comment`, an `assignee`, a `team`).
ServerNotification sampleNotification({
  required int id,
  String name = 'task.assigned',
  DateTime? created,
  DateTime? readAt,
  User doer = const User(id: 9, username: 'anna', name: 'Anna'),
  int? taskId = 1,
  String taskTitle = 'Water the plants',
  int projectId = 7,
  String projectTitle = 'Garden',
  Map<String, Object?> extra = const {},
}) => ServerNotification(
  id: id,
  name: name,
  payload: {
    'doer': {'id': doer.id, 'username': doer.username, 'name': doer.name},
    if (taskId != null)
      'task': {
        'id': taskId,
        'title': taskTitle,
        'identifier': '#$taskId',
        'index': taskId,
        'project_id': projectId,
      },
    'project': {'id': projectId, 'title': projectTitle},
    ...extra,
  },
  created: created ?? DateTime.utc(2026, 10, 13, 9).add(Duration(minutes: id)),
  readAt: readAt,
);
