import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/list_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/projects/presentation/reorder_slot.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

@immutable
final class _RowDrag {
  const new(this.task);

  final Task task;
}

/// The rows of a project's list view: the open part, then the done part
/// under its heading, or the view's empty state. A long press selects a row
/// ([onSelect]), as in every list. While the list can be put in order by
/// hand ([onReorder]), a top-level row of the open part lifts with its
/// subtasks at that long press and, moved before it is let go, drops
/// between two others (the list scrolls near its ends); let go where it
/// was lifted, it is selected instead. Screen readers move it with the
/// row's actions. The done part, nested rows and the tasks in [leavingIds]
/// stay where they are; while the list selects ([selection]) no row
/// lifts.
class ProjectListBody extends StatefulWidget {
  const new({
    required this.projectId,
    required this.projectsById,
    required this.model,
    required this.source,
    required this.kind,
    required this.view,
    required this.preferences,
    required this.offline,
    required this.downloadFailed,
    required this.header,
    required this.now,
    required this.minimumPriority,
    required this.pendingIds,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
    this.leavingIds = const {},
    this.onReorder,
    this.onDueDate,
    this.onSelect,
    this.selection,
    super.key,
  });

  final int projectId;
  final Map<int, Project> projectsById;
  final ProjectListModel model;
  final ProjectListSource source;
  final ViewFilterKind kind;
  final ProjectView? view;
  final ViewPreferences preferences;

  /// The device is offline, as far as the last sync or download knows.
  final bool offline;

  /// The view's download failed for a reason other than the connection.
  final bool downloadFailed;
  final Widget? header;
  final DateTime now;
  final int minimumPriority;
  final Set<int> pendingIds;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;

  /// The tasks marked done here whose Undo is still offered.
  final Set<int> leavingIds;

  /// Puts top-level tasks at positions of the view, by task id, in the
  /// map's order, and completes with whether the device stored them; null
  /// while the list cannot be put in order by hand.
  final Future<bool> Function(Map<int, double> positions)? onReorder;
  final void Function(Task task)? onDueDate;
  final void Function(Task task)? onSelect;

  /// Each row's selection while the list selects; null otherwise.
  final TaskRowSelection? Function(Task task)? selection;

  @override
  State<ProjectListBody> createState() => _ProjectListBodyState();
}

class _ProjectListBodyState extends State<ProjectListBody> {
  static const _divider = Divider(height: 1);

  final GlobalKey _openRowsKey = GlobalKey();
  final _slots = <int, BuildContext>{};
  late final _edgeScroller = DragEdgeScroller(onScrolled: _followPointer);

  List<ListGroup> _groups = const [];
  ({ProjectListModel model, ProjectListSource source})? _groupedFrom;
  int? _held;
  Offset? _pointer;
  int? _dropIndex;

  /// How far the held row has moved since it was lifted.
  Offset _travel = Offset.zero;

  /// Whether the held row ever went further than a touch slop: until then
  /// it neither scrolls the list nor shows where it would land, and once
  /// it has, letting go never selects, even back where it started.
  bool _moved = false;

  @override
  void didUpdateWidget(ProjectListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_held == null) return;
    // A sync that took the held row out of the list's top level unmounts
    // its draggable: the finger's moves no longer reach the list. Checked
    // once the list is rebuilt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final held = _held;
      if (mounted && held != null && _groupIndexOf(held) < 0) _endDrag();
    });
  }

  @override
  void dispose() {
    _edgeScroller.stop();
    super.dispose();
  }

  /// Again only for another model or source: the screen builds on every
  /// selection tap and clock tick, which change neither.
  List<ListGroup> _groupsOf(ProjectListModel model, ProjectListSource source) {
    if (_groupedFrom case (model: final last, source: final lastSource)
        when identical(last, model) &&
            identical(lastSource, source) &&
            _groups.isNotEmpty) {
      return _groups;
    }
    _groupedFrom = (model: model, source: source);
    return listGroupsOf(model.rows, effectivePositionsOf(source));
  }

  int _groupIndexOf(int taskId) =>
      _groups.indexWhere((group) => group.task.id == taskId);

  bool _movable(Task task) =>
      widget.onReorder != null &&
      widget.selection == null &&
      task.projectId == widget.projectId &&
      !widget.leavingIds.contains(task.id);

  /// Puts [task]'s group at [index] of the groups, counted without it, and
  /// announces [moved] once it is queued.
  Future<void> _move(Task task, int index, {required String moved}) async {
    final onReorder = widget.onReorder;
    if (onReorder == null) return;
    final positions = planListMove(_groups, task.id, index);
    if (positions == null) return;
    unawaited(HapticFeedback.selectionClick());
    final announcer = Announcer.of(context);
    if (await onReorder(positions)) announcer.say(moved);
  }

  Map<CustomSemanticsAction, VoidCallback> _actionsFor(int index) {
    final l10n = context.l10n;
    final task = _groups[index].task;
    return {
      if (index > 0 && planListMove(_groups, task.id, index - 1) != null)
        CustomSemanticsAction(label: l10n.moveUp): () =>
            unawaited(_move(task, index - 1, moved: l10n.movedUp)),
      if (index < _groups.length - 1 &&
          planListMove(_groups, task.id, index + 1) != null)
        CustomSemanticsAction(label: l10n.moveDown): () =>
            unawaited(_move(task, index + 1, moved: l10n.movedDown)),
    };
  }

  void _startDrag(Task task) {
    _travel = Offset.zero;
    _moved = false;
    setState(() => _held = task.id);
  }

  void _heldMoved(DragUpdateDetails details) {
    _travel += details.delta;
    _moved = _moved || _travel.distance > kTouchSlop;
    if (_moved) _dragMoved(details.globalPosition);
  }

  /// A row let go without ever moving was only held: it is selected, as a
  /// long press does in every other list. A touch the system took is not.
  void _released(Task task, DraggableDetails details) {
    final held = !_moved && details.wasAccepted;
    _endDrag();
    if (held && mounted) widget.onSelect?.call(task);
  }

  void _endDrag() {
    _edgeScroller.stop();
    _pointer = null;
    if (!mounted || (_held == null && _dropIndex == null)) return;
    setState(() {
      _held = null;
      _dropIndex = null;
    });
  }

  void _dragMoved(Offset pointer) {
    _pointer = pointer;
    _followPointer();
  }

  /// Where the held rows would go, and the scrolling near the list's ends;
  /// again after each scroll step.
  void _followPointer() {
    final pointer = _pointer;
    if (!mounted || pointer == null || _held == null) return;
    final inside = _openRowsKey.currentContext;
    final list = inside
        ?.findAncestorStateOfType<ScrollableState>()
        ?.context
        .findRenderObject();
    if (list is! RenderBox ||
        !list.hasSize ||
        !(list.localToGlobal(Offset.zero) & list.size).contains(pointer)) {
      _edgeScroller.stop();
      _setDropIndex(null);
      return;
    }
    _edgeScroller.follow(inside, pointer);
    _setDropIndex(_insertionIndexAt(pointer));
  }

  /// Before the first group whose middle lies below [pointer], skipping the
  /// held one, which keeps its place.
  int _insertionIndexAt(Offset pointer) {
    int? lastLaidOut;
    for (var index = 0; index < _groups.length; index++) {
      final id = _groups[index].task.id;
      if (id == _held) continue;
      final box = _slots[id]?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (pointer.dy < top + box.size.height / 2) return index;
      lastLaidOut = index;
    }
    return lastLaidOut == null ? _groups.length : lastLaidOut + 1;
  }

  void _setDropIndex(int? index) {
    if (index == _dropIndex) return;
    setState(() => _dropIndex = index);
  }

  /// The index of the held group, and where it would go counted without
  /// it; null for no move.
  ({int from, int to})? get _pendingDrop {
    final index = _dropIndex;
    final held = _held;
    if (index == null || held == null) return null;
    final from = _groupIndexOf(held);
    if (from < 0) return null;
    // The index counted the held group itself, which still holds its place.
    final to = from < index ? index - 1 : index;
    return to == from ? null : (from: from, to: to);
  }

  /// Moves the held row as the list shows it now, and nothing once a sync
  /// took it out of the list's top level.
  void _drop() {
    final drop = _pendingDrop;
    _endDrag();
    if (drop == null) return;
    final l10n = context.l10n;
    unawaited(
      _move(
        _groups[drop.from].task,
        drop.to,
        moved: drop.to < drop.from ? l10n.movedUp : l10n.movedDown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final model = widget.model;
    if (model.isEmpty) {
      _groups = const [];
      return CenteredScrollView(
        header: widget.header,
        maxWidth: ReadableWidth.list,
        child: ViewEmptyState(
          kind: widget.kind,
          source: widget.source,
          view: widget.view,
          showDone: widget.preferences.showDone,
          offline: widget.offline,
          downloadFailed: widget.downloadFailed,
        ),
      );
    }
    final reorderable = widget.onReorder != null && model.rows.isNotEmpty;
    _groups = reorderable ? _groupsOf(model, widget.source) : const [];
    final doneRows = model.doneRows ?? const [];
    final doneCount = doneRows.where((row) => row.depth == 0).length;
    return ReadableWidth.builder(
      maxWidth: ReadableWidth.list,
      builder: (context, contentWidth, inset) => DragTarget<_RowDrag>(
        onWillAcceptWithDetails: (_) => widget.onReorder != null,
        onAcceptWithDetails: (_) => _drop(),
        onLeave: (_) => _setDropIndex(null),
        builder: (context, _, _) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              sliver: SliverMainAxisGroup(
                slivers: [
                  if (widget.header case final header?)
                    NoticeSliver(notice: header),
                  if (reorderable)
                    _groupList(width: contentWidth)
                  else
                    _rows(model.rows, key: _openRowsKey),
                  if (doneRows.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: ListSectionHeader(
                        title: l10n.projectTasksDoneSection,
                        count: doneCount,
                        countLabel: l10n.sectionTaskCount(doneCount),
                      ),
                    ),
                    _rows(doneRows),
                  ],
                  // Room for the floating action button below the last row.
                  const SliverSafeArea(
                    top: false,
                    sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupList({required double width}) {
    final groups = _groups;
    final drop = _pendingDrop;
    final lineAt = drop != null && planListMove(groups, _held!, drop.to) != null
        ? _dropIndex
        : null;
    return SliverList.builder(
      key: _openRowsKey,
      itemCount: groups.length,
      findChildIndexCallback: (key) {
        if (key case ValueKey<int>(:final value)) {
          final index = groups.indexWhere((group) => group.task.id == value);
          return index < 0 ? null : index;
        }
        return null;
      },
      itemBuilder: (context, index) {
        final group = groups[index];
        final task = group.task;
        final keys = _rowKeys(group.rows);
        final movable = _movable(task);
        final top = _row(
          context,
          group.rows.first,
          key: keys.first,
          actions: movable ? _actionsFor(index) : const {},
          // Its long press is the lift's, which selects when let go.
          selectOnLongPress: !movable,
        );
        return ReorderSlot<int>(
          key: ValueKey(task.id),
          id: task.id,
          slots: _slots,
          held: task.id == _held,
          lineAbove: lineAt == index ? 16 : null,
          lineBelow: lineAt == groups.length && index == groups.length - 1
              ? 16
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Also around a row that does not move, so that a task
              // turning into the copy of one just marked done keeps its row.
              LongPressDraggable<_RowDrag>(
                data: _RowDrag(task),
                maxSimultaneousDrags: movable ? 1 : 0,
                dragAnchorStrategy: liftedAboveFinger,
                feedback: LiftedRows(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, row) in group.rows.indexed)
                        _row(context, row, key: keys[i]),
                    ],
                  ),
                ),
                onDragStarted: () => _startDrag(task),
                onDragUpdate: _heldMoved,
                onDragEnd: (details) => _released(task, details),
                // Unlike onDragEnd, also called once the draggable is
                // unmounted.
                onDraggableCanceled: (_, _) {
                  if (mounted) _endDrag();
                },
                child: LiftableRow(liftable: movable, child: top),
              ),
              for (final (i, row) in group.rows.indexed.skip(1)) ...[
                _divider,
                _row(context, row, key: keys[i]),
              ],
              if (index < groups.length - 1) _divider,
            ],
          ),
        );
      },
    );
  }

  /// A subtask with two parents in the list is in it twice.
  static List<Key> _rowKeys(List<ProjectListRow> rows) {
    final occurrences = <int, int>{};
    return [
      for (final row in rows)
        ValueKey((
          row.task.id,
          occurrences.update(
            row.task.id,
            (count) => count + 1,
            ifAbsent: () => 0,
          ),
        )),
    ];
  }

  Widget _rows(List<ProjectListRow> rows, {Key? key}) {
    final keys = _rowKeys(rows);
    return SliverList.builder(
      key: key,
      itemCount: rows.length,
      // The last row is wrapped too: a row that stops being the last
      // keeps its key, its place and so its state.
      itemBuilder: (context, index) => Column(
        key: ValueKey(('divided', keys[index])),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(context, rows[index], key: keys[index]),
          if (index < rows.length - 1) _divider,
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ProjectListRow row, {
    required Key key,
    Map<CustomSemanticsAction, VoidCallback> actions = const {},
    bool selectOnLongPress = true,
  }) {
    final task = row.task;
    final projectsById = widget.projectsById;
    final elsewhere = task.projectId == widget.projectId
        ? null
        : projectsById[task.projectId];
    // The server refuses changes to the tasks of an archived project.
    final archived = isArchivedInTree(task.projectId, projectsById);
    return TaskRow(
      key: key,
      task: task,
      now: widget.now,
      minimumPriority: widget.minimumPriority,
      depth: row.depth,
      parentTitle: row.parent?.title,
      projectTitle: elsewhere?.displayTitle(context.l10n),
      projectHexColor: elsewhere?.hexColor,
      pending: widget.pendingIds.contains(task.id),
      onTap: () => openTaskDetail(context, task: task),
      onDoneChanged: archived
          ? null
          : (done) => widget.onDoneChanged(task, done: done),
      onFavoriteChanged: archived
          ? null
          : (favorite) => widget.onFavoriteChanged(task, favorite: favorite),
      onDueDate: widget.onDueDate == null
          ? null
          : () => widget.onDueDate!(task),
      onSelect: widget.onSelect == null ? null : () => widget.onSelect!(task),
      selectOnLongPress: selectOnLongPress,
      selection: widget.selection?.call(task),
      actions: actions,
    );
  }
}

/// Why a list or table view shows no task: by its filter, and for one the
/// device cannot evaluate, whether it was downloaded.
class ViewEmptyState extends StatelessWidget {
  const new({
    required this.kind,
    required this.source,
    required this.view,
    required this.showDone,
    required this.offline,
    required this.downloadFailed,
    super.key,
  });

  final ViewFilterKind kind;
  final ProjectListSource source;
  final ProjectView? view;
  final bool showDone;

  /// The device is offline, as far as the last sync or download knows.
  final bool offline;

  /// The view's download failed for a reason other than the connection.
  final bool downloadFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = describeViewFilter(view?.filter);
    final loaded = source.snapshot.loadedAt != null;
    return switch (kind) {
      ViewFilterKind.other when source.matchingIds != null => EmptyState(
        icon: Icons.filter_alt_outlined,
        title: l10n.projectViewEmptyTitle,
        body: l10n.projectViewEmptyMatchingBody,
      ),
      ViewFilterKind.other when !loaded && offline => EmptyState(
        icon: Icons.cloud_download_outlined,
        title: l10n.projectViewNotLoadedTitle,
        body: l10n.projectViewNotLoadedBody(filter),
      ),
      ViewFilterKind.other when !loaded && downloadFailed => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.projectViewDownloadFailedTitle,
        body: l10n.projectViewDownloadFailedBody(filter),
      ),
      ViewFilterKind.other when !loaded => EmptyState(
        icon: Icons.cloud_download_outlined,
        title: l10n.projectViewDownloadingTitle,
        body: l10n.projectViewDownloadingBody(filter),
      ),
      ViewFilterKind.other => EmptyState(
        icon: Icons.filter_alt_outlined,
        title: l10n.projectViewEmptyTitle,
        body: l10n.projectViewEmptyBody,
      ),
      ViewFilterKind.doneOnly => EmptyState(
        icon: Icons.task_alt,
        title: l10n.projectTasksEmptyDoneTitle,
        body: l10n.projectTasksEmptyDoneBody,
      ),
      ViewFilterKind.openOnly
          when !showDone &&
              (source.projectTasks.isNotEmpty || source.omitsDoneTasks) =>
        EmptyState(
          icon: Icons.task_alt,
          title: l10n.projectTasksEmptyTitle,
          body: l10n.projectTasksEmptyBody,
        ),
      _ => EmptyState(
        icon: Icons.task_alt,
        title: l10n.projectTasksEmptyAllTitle,
        body: l10n.projectTasksEmptyAllBody,
      ),
    };
  }
}
