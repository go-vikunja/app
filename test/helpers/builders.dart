/// Entity / DTO builders shared by every test layer.
///
/// Builders keep the *shape* of test data in one place so a constructor change
/// touches one file instead of a hundred tests. They are deliberately dumb:
/// no assertions, no logic worth testing on its own.
library;

import 'dart:ui';

import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/domain/entities/task_reminder.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';

/// A fixed instant so date-dependent expectations stay deterministic.
final DateTime fixedDate = DateTime.utc(2024, 3, 14, 15, 9, 26);

User buildUser({
  int id = 1,
  String username = 'testuser',
  String name = '',
  UserSettings? settings,
}) => User(
  id: id,
  username: username,
  name: name,
  created: fixedDate,
  updated: fixedDate,
  settings: settings,
);

UserSettings buildUserSettings({
  int defaultProjectId = 0,
  Map<String, dynamic>? frontendSettings,
  String language = 'en',
  String name = 'Test User',
}) => UserSettings(
  defaultProjectId: defaultProjectId,
  frontendSettings: frontendSettings,
  language: language,
  name: name,
);

ProjectView buildView({
  int id = 10,
  int projectId = 1,
  ViewKind kind = ViewKind.list,
  String title = 'List',
  int defaultBucketId = 0,
  int doneBucketId = 0,
}) => ProjectView(
  fixedDate,
  defaultBucketId,
  doneBucketId,
  id,
  0.0,
  projectId,
  title,
  fixedDate,
  null,
  null,
  'manual',
  kind,
);

Project buildProject({
  int id = 1,
  String title = 'Test Project',
  int parentProjectId = 0,
  String description = '',
  List<ProjectView>? views,
  Iterable<Project> subprojects = const [],
  bool isArchived = false,
  bool isFavourite = false,
  Color? color,
  double position = 0,
  User? owner,
}) {
  final project = Project(
    id: id,
    title: title,
    parentProjectId: parentProjectId,
    description: description,
    views: views ?? [buildView(projectId: id)],
    isArchived: isArchived,
    isFavourite: isFavourite,
    color: color,
    position: position,
    owner: owner,
    created: fixedDate,
    updated: fixedDate,
  );
  project.subprojects = subprojects;
  return project;
}

/// A project whose only view is a kanban view.
Project buildKanbanProject({int id = 1, String title = 'Kanban Project'}) =>
    buildProject(
      id: id,
      title: title,
      views: [
        buildView(
          id: 20,
          projectId: id,
          kind: ViewKind.kanban,
          title: 'Kanban',
        ),
      ],
    );

Task buildTask({
  int id = 100,
  String title = 'Test Task',
  String description = '',
  String identifier = '#1',
  bool done = false,
  int? projectId = 1,
  int? bucketId,
  int? priority,
  DateTime? dueDate,
  DateTime? startDate,
  DateTime? endDate,
  double? position,
  double? percentDone,
  Color? color,
  Duration? repeatAfter,
  List<Label> labels = const [],
  List<TaskReminder> reminderDates = const [],
  List<TaskAttachment> attachments = const [],
  List<Task> subtasks = const [],
  User? createdBy,
  Project? project,
}) {
  final task = Task(
    id: id,
    title: title,
    description: description,
    identifier: identifier,
    done: done,
    projectId: projectId,
    bucketId: bucketId,
    priority: priority,
    dueDate: dueDate,
    startDate: startDate,
    endDate: endDate,
    position: position,
    percentDone: percentDone,
    color: color,
    repeatAfter: repeatAfter,
    labels: labels,
    reminderDates: reminderDates,
    attachments: attachments,
    subtasks: subtasks,
    createdBy: createdBy ?? buildUser(),
    created: fixedDate,
    updated: fixedDate,
  );
  task.project = project;
  return task;
}

Label buildLabel({
  int id = 5,
  String title = 'Bug',
  String description = '',
  Color? color,
}) => Label(
  id: id,
  title: title,
  description: description,
  color: color,
  createdBy: buildUser(),
  created: fixedDate,
  updated: fixedDate,
);

Bucket buildBucket({
  int id = 50,
  String title = 'Backlog',
  int? projectViewId = 20,
  int limit = 0,
  double? position,
  List<Task>? tasks,
  DateTime? created,
  DateTime? updated,
}) => Bucket(
  id: id,
  title: title,
  projectViewId: projectViewId,
  limit: limit,
  position: position,
  tasks: tasks ?? [],
  createdBy: buildUser(),
  created: created ?? fixedDate,
  updated: updated ?? fixedDate,
);

TaskReminder buildReminder([DateTime? at]) => TaskReminder(at ?? fixedDate);

TaskComment buildComment({
  int id = 7,
  String comment = '<p>Nice work</p>',
  User? author,
  DateTime? created,
  DateTime? updated,
}) => TaskComment(
  id: id,
  comment: comment,
  author: author ?? buildUser(),
  created: created ?? fixedDate,
  updated: updated ?? fixedDate,
);

TaskAttachment buildAttachment({
  int id = 3,
  int taskId = 100,
  String fileName = 'report.pdf',
}) => TaskAttachment(
  id: id,
  taskId: taskId,
  created: fixedDate,
  createdBy: buildUser(),
  file: TaskAttachmentFile(
    id: id,
    created: fixedDate,
    mime: 'application/pdf',
    name: fileName,
    size: 1024,
  ),
);

/// Defaults to a version at or above `minimumServerVersion`, so flows that
/// check compatibility take the happy path unless a test says otherwise.
Server buildServer({String? version = 'v2.4.0'}) => Server(
  true,
  true,
  'https://vikunja.example.com',
  true,
  '20MB',
  '',
  true,
  true,
  true,
  false,
  false,
  version,
);
