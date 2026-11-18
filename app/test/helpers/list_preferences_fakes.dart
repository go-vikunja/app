import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';

/// [ListPreferences] in memory, with streams that replay the current value
/// and follow every save, like the database's.
final class FakeListPreferences implements ListPreferences {
  final Map<String, ViewPreferences> views = {};
  final Map<int, int> lastViews = {};
  bool newTaskKeepOpen = false;
  UpcomingPreferences upcoming = const UpcomingPreferences();
  ProjectTreePreferences projectTree = const ProjectTreePreferences();
  Set<TableColumn> tableColumns = TableColumn.defaults;

  /// Every save, in order: `view <listKey>`, `lastView <projectId>`,
  /// `newTaskKeepOpen`, `upcoming`, `projectTree` or `tableColumns`.
  final List<String> saves = [];

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<ViewPreferences> watchView(String listKey) =>
      _watch(() => views[listKey] ?? const ViewPreferences());

  @override
  Future<void> saveView(String listKey, ViewPreferences preferences) async {
    saves.add('view $listKey');
    views[listKey] = preferences;
    _changes.add(null);
  }

  /// Holds back every [watchLastView] until it completes, like a slow read.
  Future<void>? lastViewsHeld;

  @override
  Stream<int?> watchLastView(int projectId) async* {
    if (lastViewsHeld case final held?) await held;
    yield* _watch(() => lastViews[projectId]);
  }

  @override
  Future<void> saveLastView(int projectId, int viewId) async {
    saves.add('lastView $projectId');
    lastViews[projectId] = viewId;
    _changes.add(null);
  }

  @override
  Stream<bool> watchNewTaskKeepOpen() => _watch(() => newTaskKeepOpen);

  @override
  Future<void> saveNewTaskKeepOpen({required bool keepOpen}) async {
    saves.add('newTaskKeepOpen');
    newTaskKeepOpen = keepOpen;
    _changes.add(null);
  }

  @override
  Stream<UpcomingPreferences> watchUpcoming() => _watch(() => upcoming);

  @override
  Future<void> saveUpcoming(UpcomingPreferences preferences) async {
    saves.add('upcoming');
    upcoming = preferences;
    _changes.add(null);
  }

  /// Sets [upcoming] for every watcher without recording a save.
  void setUpcoming(UpcomingPreferences preferences) {
    upcoming = preferences;
    _changes.add(null);
  }

  /// Sets a view's preferences for every watcher without recording a save.
  void setView(String listKey, ViewPreferences preferences) {
    views[listKey] = preferences;
    _changes.add(null);
  }

  Stream<T> _watch<T>(T Function() current, {bool Function(T a, T b)? equals}) {
    late StreamController<T> controller;
    StreamSubscription<void>? subscription;
    T? last;
    var emitted = false;
    void emit() {
      final value = current();
      if (emitted && (equals?.call(value, last as T) ?? value == last)) return;
      emitted = true;
      last = value;
      controller.add(value);
    }

    controller = StreamController<T>(
      onListen: () {
        emit();
        subscription = _changes.stream.listen((_) => emit());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<ProjectTreePreferences> watchProjectTree() =>
      _watch(() => projectTree);

  @override
  Future<void> saveProjectTree(ProjectTreePreferences preferences) async {
    saves.add('projectTree');
    projectTree = preferences;
    _changes.add(null);
  }

  /// Sets [projectTree] for every watcher without recording a save.
  void setProjectTree(ProjectTreePreferences preferences) {
    projectTree = preferences;
    _changes.add(null);
  }

  @override
  Stream<Set<TableColumn>> watchTableColumns() =>
      _watch(() => tableColumns, equals: setEquals);

  @override
  Future<void> saveTableColumns(Set<TableColumn> columns) async {
    saves.add('tableColumns');
    tableColumns = columns.isEmpty ? TableColumn.defaults : {...columns};
    _changes.add(null);
  }

  /// Sets [tableColumns] for every watcher without recording a save.
  void setTableColumns(Set<TableColumn> columns) {
    tableColumns = columns;
    _changes.add(null);
  }
}
