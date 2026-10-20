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
  List<ProjectView> views = const [],
}) => Project(
  id: id,
  title: title,
  parentProjectId: parent,
  position: position,
  isFavorite: favorite,
  isArchived: archived,
  hexColor: hexColor,
  identifier: identifier,
  views: views,
);

/// [project] at [position] under [parentProjectId] (and with [updated] when
/// given), everything else kept.
Project movedProject(
  Project project, {
  required double position,
  required int parentProjectId,
  DateTime? updated,
}) => Project(
  id: project.id,
  title: project.title,
  description: project.description,
  identifier: project.identifier,
  hexColor: project.hexColor,
  parentProjectId: parentProjectId,
  isArchived: project.isArchived,
  isFavorite: project.isFavorite,
  position: position,
  owner: project.owner,
  views: project.views,
  created: project.created,
  updated: updated ?? project.updated,
);

/// [project] with the given fields replaced, everything else kept.
Project copyProject(
  Project project, {
  int? id,
  String? title,
  String? identifier,
  String? hexColor,
  int? parentProjectId,
  bool? isArchived,
  bool? isFavorite,
  double? position,
  List<ProjectView>? views,
  DateTime? created,
  DateTime? updated,
}) => Project(
  id: id ?? project.id,
  title: title ?? project.title,
  description: project.description,
  identifier: identifier ?? project.identifier,
  hexColor: hexColor ?? project.hexColor,
  parentProjectId: parentProjectId ?? project.parentProjectId,
  isArchived: isArchived ?? project.isArchived,
  isFavorite: isFavorite ?? project.isFavorite,
  position: position ?? project.position,
  owner: project.owner,
  views: views ?? project.views,
  created: created ?? project.created,
  updated: updated ?? project.updated,
);

/// The ids of [projectId] and every project below it in [projects].
Set<int> subtreeIds(Iterable<Project> projects, int projectId) {
  final ids = {projectId};
  for (var grew = true; grew;) {
    grew = false;
    for (final project in projects) {
      if (ids.contains(project.parentProjectId) && ids.add(project.id)) {
        grew = true;
      }
    }
  }
  return ids;
}

/// The four views the server makes for a new project, with ids from
/// [firstViewId] on: List (`done = false`), Gantt, Table and a manual
/// Kanban with [defaultBucketId] and [doneBucketId].
List<ProjectView> defaultViews(
  int projectId, {
  required int firstViewId,
  int defaultBucketId = 0,
  int doneBucketId = 0,
}) => [
  sampleListView(id: firstViewId, projectId: projectId),
  ProjectView(
    id: firstViewId + 1,
    projectId: projectId,
    title: 'Gantt',
    kind: ProjectViewKind.gantt,
    position: 200,
  ),
  ProjectView(
    id: firstViewId + 2,
    projectId: projectId,
    title: 'Table',
    kind: ProjectViewKind.table,
    position: 300,
  ),
  sampleKanbanView(
    id: firstViewId + 3,
    projectId: projectId,
    defaultBucketId: defaultBucketId,
    doneBucketId: doneBucketId,
  ),
];

/// The mode the server stores for a view of [kind] sent with [mode]: a
/// board without a manual or filter mode becomes manual, the other kinds
/// have none.
BucketConfigurationMode storedBucketMode(
  ProjectViewKind kind,
  BucketConfigurationMode? mode,
) => switch ((kind, mode)) {
  (ProjectViewKind.kanban, null || BucketConfigurationMode.none) =>
    BucketConfigurationMode.manual,
  (ProjectViewKind.kanban, final mode?) => mode,
  _ => BucketConfigurationMode.none,
};

/// A list view shaped like the one the server makes for a new project:
/// `done = false` unless [filter] says otherwise ('' for none).
ProjectView sampleListView({
  required int id,
  required int projectId,
  String title = 'List',
  double position = 100,
  String filter = 'done = false',
  String search = '',
  ProjectViewKind kind = ProjectViewKind.list,
}) => ProjectView(
  id: id,
  projectId: projectId,
  title: title,
  kind: kind,
  position: position,
  filter: filter.isEmpty && search.isEmpty
      ? null
      : ViewFilter(filter: filter, search: search),
);

/// A manual kanban view; the server makes one for a new project with
/// To-Do, Doing and Done, the first as the default, the last as the done
/// bucket.
ProjectView sampleKanbanView({
  required int id,
  required int projectId,
  String title = 'Kanban',
  double position = 400,
  int defaultBucketId = 0,
  int doneBucketId = 0,
  BucketConfigurationMode mode = BucketConfigurationMode.manual,
}) => ProjectView(
  id: id,
  projectId: projectId,
  title: title,
  kind: ProjectViewKind.kanban,
  position: position,
  bucketConfigurationMode: mode,
  defaultBucketId: defaultBucketId,
  doneBucketId: doneBucketId,
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
  DateTime? created,
  User? createdBy,
  String hexColor = '',
  Map<TaskRelationKind, List<Task>> relatedTasks = const {},
  List<int> subtaskIds = const [],
  List<int> parentIds = const [],
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
  created: created?.toUtc(),
  createdBy: createdBy,
  hexColor: hexColor,
  relatedTasks: {
    ...relatedTasks,
    if (subtaskIds.isNotEmpty)
      TaskRelationKind.subtask: [
        ...?relatedTasks[TaskRelationKind.subtask],
        for (final other in subtaskIds) _relatedStub(other, projectId),
      ],
    if (parentIds.isNotEmpty)
      TaskRelationKind.parentTask: [
        ...?relatedTasks[TaskRelationKind.parentTask],
        for (final other in parentIds) _relatedStub(other, projectId),
      ],
  },
);

/// An attachment as the task read lists it: a PNG unless [mime] says
/// otherwise.
TaskAttachment sampleAttachment({
  required int id,
  int taskId = 1,
  String name = 'photo.png',
  String mime = 'image/png',
  int size = 2048,
  DateTime? created,
  User? createdBy = const User(id: 9, username: 'anna', name: 'Anna'),
}) => TaskAttachment(
  id: id,
  taskId: taskId,
  name: name,
  mime: mime,
  size: size,
  created: (created ?? DateTime.utc(2026, 10, 12, 9)).toUtc(),
  createdBy: createdBy,
);

/// A comment by [author], created [created] (default: 9:00 plus [id]
/// minutes on 2026-10-12) and edited at [updated] (default: never).
TaskComment sampleComment({
  required int id,
  String html = '<p>Looks good</p>',
  User author = const User(id: 9, username: 'anna', name: 'Anna'),
  DateTime? created,
  DateTime? updated,
  Reactions reactions = const {},
}) {
  final at =
      (created ?? DateTime.utc(2026, 10, 12, 9).add(Duration(minutes: id)))
          .toUtc();
  return TaskComment(
    id: id,
    html: html,
    author: author,
    created: at,
    updated: (updated ?? at).toUtc(),
    reactions: reactions,
  );
}

/// What a list row carries for a related task: the bare task, no relations
/// of its own; lists look the full task up by id.
Task _relatedStub(int id, int projectId) =>
    Task(id: id, title: 'Task $id', projectId: projectId, index: id);

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
