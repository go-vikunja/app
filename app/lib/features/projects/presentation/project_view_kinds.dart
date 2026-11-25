import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/time/today_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/local_change.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/application/list_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/project_rows.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_table_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_content.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/projects/presentation/table_columns_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/project_timeline_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_controls.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// What sets a kind of a project's views apart on the project screen: the
/// providers it watches, the controls above it and its body.
sealed class ProjectViewDelegate {
  const new();

  factory of(ProjectViewKind kind) => switch (kind) {
    ProjectViewKind.list => const ListViewDelegate(),
    ProjectViewKind.table => const TableViewDelegate(),
    ProjectViewKind.gantt => const TimelineViewDelegate(),
    ProjectViewKind.kanban => const BoardViewDelegate(),
  };

  /// The view downloads its board (`refreshBoard`), not its tasks.
  bool get board => false;

  /// Several of its tasks can be selected at once.
  bool get selects => false;

  /// The scrolls a pull to refresh starts from.
  ScrollNotificationPredicate get notificationPredicate =>
      defaultScrollNotificationPredicate;

  AsyncValue<ViewPreferences> watchPreferences(WidgetRef ref, String listKey) =>
      ref.watch(viewPreferencesProvider(listKey));

  /// The columns of every table view; the defaults where none show.
  AsyncValue<Set<TableColumn>> watchColumns(WidgetRef ref) =>
      const AsyncData(TableColumn.defaults);

  /// The source of the view with [kind] and [preferences]; [onQueued] hears
  /// the tasks of its own moves still queued, where it has any.
  WatchedViewSource<Object> watchSource(
    WidgetRef ref, {
    required int projectId,
    required int viewId,
    required ViewFilterKind kind,
    required ViewPreferences preferences,
    required void Function(Set<int>? queued) onQueued,
  });

  /// The controls above the body, the same [key] in every kind so the
  /// chips that move between the body and its loading and failure states
  /// keep their focus. Null where the view has none.
  Widget? controls(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required int viewId,
    required String listKey,
    required ViewPreferences preferences,
    required Set<TableColumn> columns,
    required Set<TableColumn> storedColumns,
    required VoidCallback? onShowDoneChanged,
  }) => null;

  void _savePreferences(
    WidgetRef ref,
    String listKey,
    ViewPreferences preferences,
  ) => unawaited(
    ref.read(listPreferencesProvider)?.saveView(listKey, preferences),
  );
}

/// What the project screen puts around the body of the view it shows,
/// whichever kind that is.
final class ProjectViewFrame {
  const new({
    required this.projectId,
    required this.projectsById,
    required this.archived,
    required this.access,
    required this.repository,
    required this.offline,
    required this.downloadFailed,
    required this.notice,
    required this.archivedNote,
    required this.controls,
    required this.columns,
    required this.now,
    required this.minimumPriority,
    required this.pendingIds,
    required this.bottomPadding,
    required this.leavingIn,
    required this.rows,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
    required this.onDueDate,
    required this.onSelect,
    required this.selection,
  });

  final int projectId;
  final Map<int, Project> projectsById;
  final bool archived;
  final ProjectAccess access;
  final TaskRepository? repository;

  /// The device is offline, as far as the last sync or download knows.
  final bool offline;

  /// The view's download failed for a reason other than the connection.
  final bool downloadFailed;

  /// The refresh's failure or the offline notice, from `buildRefreshable`.
  final Widget? notice;
  final Widget? archivedNote;

  /// Of the view chosen, also while the one before still shows.
  final Widget? controls;
  final Set<TableColumn> columns;
  final DateTime now;
  final int minimumPriority;
  final Set<int> pendingIds;

  /// Below a board's columns and a timeline's rows, to scroll them clear
  /// of the floating action button.
  final double bottomPadding;

  /// The copies of the tasks marked done here that stay while their Undo
  /// is offered, for a list's tasks (`TaskListActions.leavingTasksIn`).
  final Map<int, Task> Function(Map<int, Task> listed) leavingIn;

  /// The list model or table rows of the view, kept while unchanged.
  final ProjectRows rows;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;
  final void Function(Task task) onDueDate;
  final void Function(Task task) onSelect;

  /// Each row's selection while the list selects; null otherwise.
  final TaskRowSelection? Function(Task task)? selection;
}

/// The body of [content], the view chosen or, while that one loads, the
/// one shown before, in [frame].
Widget projectViewBody(
  BuildContext context,
  ProjectViewContent content,
  ProjectViewFrame frame,
) => switch (content) {
  final BoardViewContent board => const BoardViewDelegate()._body(board, frame),
  final TaskViewContent tasks => _taskViewBody(context, tasks, frame),
};

/// A list, table or Gantt view's body, under the controls, the screen's
/// notes and, for a filter only the server can evaluate, when its answer
/// was downloaded.
Widget _taskViewBody(
  BuildContext context,
  TaskViewContent content,
  ProjectViewFrame frame,
) {
  final l10n = context.l10n;
  final now = frame.now;
  final source = content.source;
  final leaving = frame.leavingIn(source.tasksById);
  final loadedAt = content.loadedAt;
  final filterNotice =
      content.kind == ViewFilterKind.other &&
          source.matchingIds == null &&
          loadedAt != null
      ? ListNote(
          icon: Icons.filter_alt_outlined,
          text: l10n.projectViewFilterNotice(
            describeViewFilter(content.view?.filter),
            formatRelativeTime(
              l10n,
              // The tick may lag behind a download just finished.
              loadedAt.isAfter(now) ? now : loadedAt,
              now: now,
            ),
          ),
        )
      : null;
  final header = stackedNotes([
    ?frame.controls,
    ?frame.notice,
    ?frame.archivedNote,
    ?filterNotice,
  ]);
  return switch (content) {
    final TableViewContent table => const TableViewDelegate()._body(
      table,
      frame,
      header: header,
      leaving: leaving,
    ),
    final TimelineViewContent timeline => const TimelineViewDelegate()._body(
      timeline,
      frame,
      header: header,
    ),
    final ListViewContent list => const ListViewDelegate()._body(
      context,
      list,
      frame,
      header: header,
      leaving: leaving,
    ),
  };
}

bool _verticalOnly(ScrollNotification notification) =>
    notification.metrics.axis == Axis.vertical;

/// A list view: the web's subtask nesting and sort, put in order by hand
/// where the sort allows it.
final class ListViewDelegate extends ProjectViewDelegate {
  const new();

  @override
  bool get selects => true;

  @override
  WatchedViewSource<ProjectListSource> watchSource(
    WidgetRef ref, {
    required int projectId,
    required int viewId,
    required ViewFilterKind kind,
    required ViewPreferences preferences,
    required void Function(Set<int>? queued) onQueued,
  }) {
    final listSource = projectListSourceProvider(
      projectId,
      viewId: viewId,
      includeDone: showsDoneTasks(kind, preferences),
    );
    ref.listen(
      listSource,
      (_, next) => onQueued(next.value?.queuedPositions.keys.toSet()),
    );
    return WatchedViewSource(ref.watch(listSource), ListViewContent.new);
  }

  @override
  Widget controls(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required int viewId,
    required String listKey,
    required ViewPreferences preferences,
    required Set<TableColumn> columns,
    required Set<TableColumn> storedColumns,
    required VoidCallback? onShowDoneChanged,
  }) => ProjectListControls(
    key: key,
    sort: preferences.sort,
    onSort: () => unawaited(_chooseSort(context, ref, listKey, preferences)),
    showDone: preferences.showDone,
    onShowDoneChanged: onShowDoneChanged,
  );

  Future<void> _chooseSort(
    BuildContext context,
    WidgetRef ref,
    String listKey,
    ViewPreferences current,
  ) async {
    final l10n = context.l10n;
    final sort = await showOptionSheet<TaskListSort>(
      context,
      title: l10n.projectSort,
      options: [
        for (final sort in sortsInMenuOrder(l10n))
          SheetOption(
            value: sort,
            label: sortLabel(l10n, sort),
            selected: sort == current.sort,
          ),
      ],
    );
    if (sort == null || !context.mounted) return;
    _savePreferences(ref, listKey, current.copyWith(sort: sort));
  }

  Widget _body(
    BuildContext context,
    ListViewContent content,
    ProjectViewFrame frame, {
    required Widget? header,
    required Map<int, Task> leaving,
  }) {
    final view = content.view;
    final preferences = content.preferences;
    final model = frame.rows.listModel(
      content.source,
      kind: content.kind,
      preferences: preferences,
      leaving: leaving,
    );
    // Before its first download the view's order is made up.
    final reorderView =
        content.loadedAt != null &&
            listIsReorderable(
              projectId: frame.projectId,
              view: view,
              sort: preferences.sort,
              archived: frame.archived,
              writable: frame.access.canReorderOrBoard,
            )
        ? view
        : null;
    final repository = frame.repository;
    return ProjectListBody(
      projectId: frame.projectId,
      projectsById: frame.projectsById,
      model: model,
      source: content.source,
      kind: content.kind,
      view: view,
      preferences: preferences,
      offline: frame.offline,
      downloadFailed: frame.downloadFailed,
      header: header,
      now: frame.now,
      minimumPriority: frame.minimumPriority,
      pendingIds: frame.pendingIds,
      onDoneChanged: frame.onDoneChanged,
      onFavoriteChanged: frame.onFavoriteChanged,
      onDueDate: frame.onDueDate,
      onSelect: frame.onSelect,
      selection: frame.selection,
      leavingIds: leaving.keys.toSet(),
      onReorder: reorderView == null || repository == null
          ? null
          : (positions) => saveLocalChange(context, () async {
              for (final MapEntry(key: taskId, value: position)
                  in positions.entries) {
                await repository.positionTask(
                  taskId,
                  viewId: reorderView.id,
                  position: position,
                );
              }
            }, action: 'Reordering a list'),
    );
  }
}

/// A table view: the list view's tasks flat, with the chosen columns and
/// the web table's sort.
final class TableViewDelegate extends ProjectViewDelegate {
  const new();

  @override
  bool get selects => true;

  @override
  AsyncValue<Set<TableColumn>> watchColumns(WidgetRef ref) =>
      ref.watch(tableColumnsProvider);

  @override
  WatchedViewSource<ProjectListSource> watchSource(
    WidgetRef ref, {
    required int projectId,
    required int viewId,
    required ViewFilterKind kind,
    required ViewPreferences preferences,
    required void Function(Set<int>? queued) onQueued,
  }) => WatchedViewSource(
    ref.watch(
      projectListSourceProvider(
        projectId,
        viewId: viewId,
        includeDone: showsDoneTasks(kind, preferences),
      ),
    ),
    TableViewContent.new,
  );

  @override
  Widget controls(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required int viewId,
    required String listKey,
    required ViewPreferences preferences,
    required Set<TableColumn> columns,
    required Set<TableColumn> storedColumns,
    required VoidCallback? onShowDoneChanged,
  }) => ProjectTableControls(
    key: key,
    sortLabel: tableSortLabel(
      context.l10n,
      preferences.tableSort.forColumns(columns),
    ),
    onSort: () => unawaited(
      _chooseTableSort(
        context,
        ref,
        listKey,
        preferences,
        columns: columns,
        storedColumns: storedColumns,
      ),
    ),
    onColumns: () => unawaited(_chooseTableColumns(context, ref, columns)),
    showDone: preferences.showDone,
    onShowDoneChanged: onShowDoneChanged,
  );

  Future<void> _chooseTableSort(
    BuildContext context,
    WidgetRef ref,
    String listKey,
    ViewPreferences current, {
    required Set<TableColumn> columns,
    required Set<TableColumn> storedColumns,
  }) async {
    final l10n = context.l10n;
    final applied = current.tableSort.forColumns(columns);
    final sort = await showOptionSheet<TableSort>(
      context,
      title: l10n.projectSort,
      options: [
        for (final sort in tableSortsInMenuOrder)
          SheetOption(
            value: sort,
            label: tableSortLabel(l10n, sort),
            selected: sort == applied,
          ),
      ],
    );
    if (sort == null || !context.mounted) return;
    _savePreferences(ref, listKey, current.copyWith(tableSort: sort));
    // Only a shown column sorts the table, so the chosen one shows.
    if (sort.forColumns(columns) != sort) {
      final column = TableColumn.values.firstWhere(
        (column) => column.sortField == sort.field,
      );
      unawaited(
        ref.read(listPreferencesProvider)?.saveTableColumns({
          ...storedColumns,
          column,
        }),
      );
    }
  }

  Future<void> _chooseTableColumns(
    BuildContext context,
    WidgetRef ref,
    Set<TableColumn> current,
  ) => showTableColumnsSheet(
    context,
    columns: current,
    onChanged: (columns) =>
        unawaited(ref.read(listPreferencesProvider)?.saveTableColumns(columns)),
  );

  Widget _body(
    TableViewContent content,
    ProjectViewFrame frame, {
    required Widget? header,
    required Map<int, Task> leaving,
  }) {
    final preferences = content.preferences;
    final sort = preferences.tableSort.forColumns(frame.columns);
    return ProjectTableBody(
      projectId: frame.projectId,
      projectsById: frame.projectsById,
      rows: frame.rows.tableRows(
        content.source,
        kind: content.kind,
        showDone: preferences.showDone,
        sort: sort,
        leaving: leaving,
      ),
      columns: frame.columns,
      source: content.source,
      kind: content.kind,
      view: content.view,
      showDone: preferences.showDone,
      offline: frame.offline,
      downloadFailed: frame.downloadFailed,
      header: header,
      now: frame.now,
      minimumPriority: frame.minimumPriority,
      pendingIds: frame.pendingIds,
      onDoneChanged: frame.onDoneChanged,
      onFavoriteChanged: frame.onFavoriteChanged,
      onDueDate: frame.onDueDate,
      onSelect: frame.onSelect,
      selection: frame.selection,
    );
  }
}

/// A Gantt view: a timeline of the tasks in its range.
final class TimelineViewDelegate extends ProjectViewDelegate {
  const new();

  /// Its rows scroll inside a horizontal scroll.
  @override
  ScrollNotificationPredicate get notificationPredicate => _verticalOnly;

  @override
  WatchedViewSource<ProjectListSource> watchSource(
    WidgetRef ref, {
    required int projectId,
    required int viewId,
    required ViewFilterKind kind,
    required ViewPreferences preferences,
    required void Function(Set<int>? queued) onQueued,
  }) {
    final timeline = preferences.timeline;
    return WatchedViewSource(
      ref.watch(
        timelineSourceProvider(
          projectId,
          viewId: viewId,
          range: timeline.range(ref.watch(todayProvider)),
          withoutDates: timeline.withoutDates,
        ),
      ),
      TimelineViewContent.new,
    );
  }

  @override
  Widget controls(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required int viewId,
    required String listKey,
    required ViewPreferences preferences,
    required Set<TableColumn> columns,
    required Set<TableColumn> storedColumns,
    required VoidCallback? onShowDoneChanged,
  }) => ProjectTimelineControls(
    key: key,
    viewId: viewId,
    listKey: listKey,
    preferences: preferences,
  );

  Widget _body(
    TimelineViewContent content,
    ProjectViewFrame frame, {
    required Widget? header,
  }) {
    final view = content.view!;
    return ProjectTimelineBody(
      // Collapsed rows belong to one view.
      key: ValueKey(view.id),
      view: view,
      source: content.source,
      preferences: content.preferences,
      offline: frame.offline,
      downloadFailed: frame.downloadFailed,
      header: header,
      bottomPadding: frame.bottomPadding,
    );
  }
}

/// A kanban view: a board as of its last download with this device's
/// changes on top. It has no preferences and no controls.
final class BoardViewDelegate extends ProjectViewDelegate {
  const new();

  @override
  bool get board => true;

  /// Its columns scroll inside a horizontal scroll.
  @override
  ScrollNotificationPredicate get notificationPredicate => _verticalOnly;

  @override
  AsyncValue<ViewPreferences> watchPreferences(WidgetRef ref, String listKey) =>
      const AsyncData(ViewPreferences());

  @override
  WatchedViewSource<BoardSource> watchSource(
    WidgetRef ref, {
    required int projectId,
    required int viewId,
    required ViewFilterKind kind,
    required ViewPreferences preferences,
    required void Function(Set<int>? queued) onQueued,
  }) {
    final boardSource = boardSourceProvider(projectId, viewId);
    ref.listen(
      boardSource,
      (_, next) => onQueued(next.value?.queued.keys.toSet()),
    );
    return WatchedViewSource(ref.watch(boardSource), BoardViewContent.new);
  }

  Widget _body(BoardViewContent content, ProjectViewFrame frame) {
    final view = content.view ?? content.source.view;
    if (view == null) return const SizedBox.shrink();
    return _BoardBody(
      projectId: frame.projectId,
      view: view,
      source: content.source,
      archived: frame.archived,
      writable: frame.access.canReorderOrBoard,
      canChangeView: frame.access.canChooseDoneAndDefaultColumn,
      offline: frame.offline,
      downloadFailed: frame.downloadFailed,
      notes: [?frame.notice, ?frame.archivedNote],
      now: frame.now,
      minimumPriority: frame.minimumPriority,
      pendingIds: frame.pendingIds,
      bottomPadding: frame.bottomPadding,
    );
  }
}

/// A kanban view's body: the board as of its last download, or why there
/// is none yet in the words of a list view never downloaded.
class _BoardBody extends StatelessWidget {
  const new({
    required this.projectId,
    required this.view,
    required this.source,
    required this.archived,
    required this.writable,
    required this.canChangeView,
    required this.offline,
    required this.downloadFailed,
    required this.notes,
    required this.now,
    required this.minimumPriority,
    required this.pendingIds,
    required this.bottomPadding,
  });

  final int projectId;
  final ProjectView view;
  final BoardSource source;
  final bool archived;

  /// The user may change the board: move cards, manage columns.
  final bool writable;

  /// The user, or a guest by its share, may also change the view: the done
  /// and the default column, and a new default before a delete.
  final bool canChangeView;

  /// The device is offline, as far as the last sync or download knows.
  final bool offline;

  /// The board's download failed for a reason other than the connection.
  final bool downloadFailed;
  final List<Widget> notes;
  final DateTime now;
  final int minimumPriority;
  final Set<int> pendingIds;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloaded = source.loadedAt != null;
    final header = stackedNotes([
      ...notes,
      if (downloaded &&
          view.bucketConfigurationMode == BucketConfigurationMode.filter)
        ListNote(
          icon: Icons.filter_alt_outlined,
          text: l10n.boardFilterColumnsNote,
        ),
    ]);
    if (!downloaded) {
      return CenteredScrollView(
        header: header,
        child: switch ((offline, downloadFailed)) {
          (true, _) => EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.projectViewNotLoadedTitle,
            body: l10n.boardNotLoadedBody,
          ),
          (_, true) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.projectViewDownloadFailedTitle,
            body: l10n.boardDownloadFailedBody,
          ),
          _ => EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.projectViewDownloadingTitle,
            body: l10n.boardDownloadingBody,
          ),
        },
      );
    }
    return ProjectBoard(
      key: ValueKey(view.id),
      projectId: projectId,
      view: view,
      source: source,
      readOnly: boardIsReadOnly(view, archived: archived, writable: writable),
      canChangeView: canChangeView,
      offline: offline,
      now: now,
      minimumPriority: minimumPriority,
      pendingIds: pendingIds,
      header: header,
      bottomPadding: bottomPadding,
    );
  }
}
