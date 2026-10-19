import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

/// The project's views the app shows, its list and kanban views, as the
/// web orders its view tabs.
List<ProjectView> shownViewsOf(Project? project) =>
    [
      for (final view in project?.views ?? const <ProjectView>[])
        if (view.kind == ProjectViewKind.list ||
            view.kind == ProjectViewKind.kanban)
          view,
    ]..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
    });

/// The view to show, the web's way: the remembered one while [views] still
/// has it, else the first of the user's default kind (null: the first by
/// position), else the first; 0 without views. Fed the views the app
/// shows, so a default of a kind it hides falls back to the first view.
int resolveViewId(
  List<ProjectView> views, {
  required int? remembered,
  ProjectViewKind? defaultKind,
}) {
  if (views.any((view) => view.id == remembered)) return remembered!;
  final ofDefaultKind = defaultKind == null
      ? null
      : views.where((view) => view.kind == defaultKind).firstOrNull;
  return (ofDefaultKind ?? views.firstOrNull)?.id ?? 0;
}

@immutable
final class ProjectListRow {
  const new(this.task, this.depth, {this.parent});

  final Task task;

  /// 0 for a top-level row.
  final int depth;

  /// The row this one is nested under; null at the top level.
  final Task? parent;
}

@immutable
final class ProjectListModel {
  const new({this.rows = const [], this.doneRows});

  /// The open rows of a view that splits off its done tasks; every row of
  /// one that does not (`doneOnly`, `other`).
  final List<ProjectListRow> rows;

  /// The done top-level tasks with their subtasks, below [rows]; null when
  /// the view shows no done part.
  final List<ProjectListRow>? doneRows;

  bool get isEmpty => rows.isEmpty && (doneRows?.isEmpty ?? true);
}

/// Whether the source of a view needs the project's done tasks that are
/// not in its last download: only where they can show at the top level.
bool showsDoneTasks(ViewFilterKind kind, ViewPreferences preferences) =>
    switch (kind) {
      ViewFilterKind.none || ViewFilterKind.doneOnly => true,
      ViewFilterKind.openOnly => preferences.showDone,
      ViewFilterKind.other => false,
    };

/// The rows of a project's list view, the web's way: the tasks the view
/// matches, each top-level one followed by its subtasks, the top-level ones
/// in the view's sort.
///
/// - [ViewFilterKind.openOnly]: the open tasks (the web's List view). With
///   `showDone` it shows like [ViewFilterKind.none] instead, so that an open
///   subtask of a done task is listed once, under its parent.
/// - [ViewFilterKind.none]: every task, the done top-level ones in the done
///   part, each part with its subtasks whether done or not.
/// - [ViewFilterKind.doneOnly]: the done tasks, in the view's positions.
/// - [ViewFilterKind.other]: the tasks of the view's last download that
///   this device still has, in its positions.
///
/// [leaving] are the tasks marked done here whose Undo is still offered,
/// by id, as the rows showed them: they keep their place among the open
/// rows meanwhile, standing in for the task where the source no longer has
/// it.
ProjectListModel buildProjectListModel(
  ProjectListSource source, {
  required ViewFilterKind kind,
  required ViewPreferences preferences,
  Map<int, Task> leaving = const {},
}) {
  Task placed(Task task) => task.done && leaving.containsKey(task.id)
      ? task.copyWith(done: false, doneAt: null)
      : task;
  final standIns = {
    for (final copy in leaving.values)
      if (!source.tasksById.containsKey(copy.id)) copy.id: copy,
  };
  final shownById = {...source.tasksById, ...standIns};
  final tasks = [
    for (final task in source.projectTasks) placed(task),
    for (final copy in standIns.values) placed(copy),
  ];
  final positions = effectivePositionsOf(source);
  final separateDone =
      kind == ViewFilterKind.openOnly || kind == ViewFilterKind.none;

  List<ProjectListRow> rowsOf(Iterable<Task> matching) {
    final sorted = matching.toList()
      ..sort(
        (a, b) => compareTasksForList(
          a,
          b,
          preferences.sort,
          positions: positions,
          separateDone: separateDone,
        ),
      );
    final rows = <ProjectListRow>[];
    void add(TaskTreeNode node, Task? parent) {
      final task = shownById[node.task.id] ?? node.task;
      rows.add(ProjectListRow(task, node.depth, parent: parent));
      for (final child in node.children) {
        add(child, task);
      }
    }

    for (final node in buildTaskTree(matching: sorted, tasksById: shownById)) {
      add(node, null);
    }
    return rows;
  }

  final allIds = {for (final task in tasks) task.id};
  switch (kind) {
    case ViewFilterKind.openOnly when !preferences.showDone:
      return ProjectListModel(rows: rowsOf(tasks.where((task) => !task.done)));
    case ViewFilterKind.openOnly || ViewFilterKind.none:
      final topLevel = tasks
          .where((task) => showsAtTopLevel(_parentIds(task), allIds))
          .toList();
      return ProjectListModel(
        rows: rowsOf(topLevel.where((task) => !task.done)),
        doneRows: rowsOf(topLevel.where((task) => task.done)),
      );
    case ViewFilterKind.doneOnly:
      return ProjectListModel(rows: rowsOf(tasks.where((task) => task.done)));
    case ViewFilterKind.other:
      return ProjectListModel(
        rows: rowsOf([
          for (final id in source.snapshot.taskIds)
            if (shownById[id] case final task?) placed(task),
        ]),
      );
  }
}

/// The view's positions by task id as the manual order uses them: a queued
/// one wins over the downloaded one. Membership stays the download's.
Map<int, double> effectivePositionsOf(ProjectListSource source) =>
    source.queuedPositions.isEmpty
    ? source.snapshot.positions
    : {...source.snapshot.positions, ...source.queuedPositions};

Iterable<int> _parentIds(Task task) =>
    task.parentTasks.map((parent) => parent.id);
