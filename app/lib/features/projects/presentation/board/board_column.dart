import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/count_badge.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/presentation/reorder_slot.dart';

/// One column of a kanban board: the bucket's title, done marker, count and
/// menu pinned above its cards, then the next page's loader and "Add a task",
/// all in one scroll view so that nothing overflows a short column. A board
/// drives the drag through its state: where a card would go and the
/// scrolling near the column's ends.
class BoardColumnView extends StatefulWidget {
  const new({
    required this.column,
    required this.width,
    required this.isDoneColumn,
    required this.cardBuilder,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onNearEnd,
    this.onAddTask,
    this.menu,
    this.headerActions = const {},
    this.draggedTaskId,
    this.dropIndex,
    this.endPadding = 0,
    super.key,
  });

  final BoardColumn column;
  final double width;
  final bool isDoneColumn;
  final Widget Function(BuildContext context, Task task, int index) cardBuilder;
  final bool loadingMore;
  final VoidCallback onLoadMore;

  /// Scrolled close to the last card loaded.
  final VoidCallback onNearEnd;

  /// Null hides "Add a task", e.g. on a board whose cards cannot move.
  final VoidCallback? onAddTask;

  /// At the header's end, a node of its own beside the header's.
  final Widget? menu;

  /// The header's screen reader actions.
  final Map<CustomSemanticsAction, VoidCallback> headerActions;

  /// The card being dragged, which stays alive while it scrolls away.
  final int? draggedTaskId;

  /// Where a drop line shows, as an index into the column's cards.
  final int? dropIndex;

  /// Room after the last item, e.g. to scroll it above a floating button.
  final double endPadding;

  @override
  State<BoardColumnView> createState() => BoardColumnViewState();
}

class BoardColumnViewState extends State<BoardColumnView> {
  final _scroll = ScrollController();
  final GlobalKey _header = GlobalKey();
  final _slots = <int, BuildContext>{};
  DragEdgeScroller? _edgeScroller;

  @override
  void dispose() {
    _edgeScroller?.stop();
    _scroll.dispose();
    super.dispose();
  }

  /// The index among the column's cards a card dropped at the global
  /// [pointer] goes to: before the first card whose middle lies below it,
  /// the pointer taken no higher than the pinned header's bottom, as cards
  /// scrolled under the header are out of sight. The dragged card itself is
  /// skipped; it may be kept alive out of view. While the server has more
  /// cards, nothing goes below the last one loaded: it would sort onto a
  /// page not loaded yet.
  int insertionIndexAt(Offset pointer) {
    final tasks = widget.column.tasks;
    final index = _insertionIndexAt(pointer);
    return widget.column.hasMore && tasks.isNotEmpty && index == tasks.length
        ? tasks.length - 1
        : index;
  }

  int _insertionIndexAt(Offset pointer) {
    final header = _header.currentContext?.findRenderObject();
    final y = header is RenderBox && header.hasSize
        ? math.max(
            pointer.dy,
            header.localToGlobal(Offset(0, header.size.height)).dy,
          )
        : pointer.dy;
    final tasks = widget.column.tasks;
    int? lastLaidOut;
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].id == widget.draggedTaskId) continue;
      final box = _slots[tasks[i].id]?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (y < top + box.size.height / 2) return i;
      lastLaidOut = i;
    }
    return lastLaidOut == null ? tasks.length : lastLaidOut + 1;
  }

  /// Scrolls the cards while the global [pointer] is near the column's top
  /// or bottom; the first [onScrolled] given runs after each step.
  void autoScrollNear(Offset pointer, {required VoidCallback onScrolled}) =>
      (_edgeScroller ??= DragEdgeScroller(
        onScrolled: onScrolled,
      )).followController(_scroll, pointer);

  void stopAutoScroll() => _edgeScroller?.stop();

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (notification is ScrollUpdateNotification &&
        metrics.axis == Axis.vertical &&
        metrics.extentAfter < metrics.viewportDimension * 0.25) {
      widget.onNearEnd();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final column = widget.column;
    final tasks = column.tasks;
    final full = columnIsFull(column);
    final dropIndex = widget.dropIndex;
    final addTask = widget.onAddTask;

    return SizedBox(
      width: widget.width,
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              PinnedHeaderSliver(
                child: ColoredBox(
                  key: _header,
                  color: colors.surfaceContainerLow,
                  child: _ColumnHeader(
                    bucket: column.bucket,
                    count: column.shownCount,
                    full: full,
                    isDoneColumn: widget.isDoneColumn,
                    menu: widget.menu,
                    actions: widget.headerActions,
                  ),
                ),
              ),
              if (tasks.isEmpty && dropIndex == 0)
                const SliverToBoxAdapter(child: _dropLine),
              SliverList.builder(
                itemCount: tasks.length,
                findChildIndexCallback: (key) {
                  if (key case ValueKey<int>(:final value)) {
                    final index = tasks.indexWhere((task) => task.id == value);
                    return index < 0 ? null : index;
                  }
                  return null;
                },
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _CardSlot(
                    key: ValueKey(task.id),
                    taskId: task.id,
                    slots: _slots,
                    held: task.id == widget.draggedTaskId,
                    lineAbove: dropIndex == index,
                    lineBelow:
                        dropIndex == tasks.length && index == tasks.length - 1,
                    child: widget.cardBuilder(context, task, index),
                  );
                },
              ),
              if (column.hasMore)
                SliverToBoxAdapter(
                  child: _LoadMore(
                    loading: widget.loadingMore,
                    onPressed: widget.onLoadMore,
                  ),
                ),
              if (addTask != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                    child: _AddTaskButton(
                      label: tasks.isEmpty
                          ? l10n.boardAddTask
                          : l10n.boardAddAnotherTask,
                      semanticsLabel: tasks.isEmpty
                          ? l10n.boardAddTaskTo(column.bucket.title)
                          : l10n.boardAddAnotherTaskTo(column.bucket.title),
                      onPressed: full ? null : addTask,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: 4 + widget.endPadding),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const new({
    required this.bucket,
    required this.count,
    required this.full,
    required this.isDoneColumn,
    required this.menu,
    required this.actions,
  });

  final Bucket bucket;
  final int count;
  final bool full;
  final bool isDoneColumn;
  final Widget? menu;
  final Map<CustomSemanticsAction, VoidCallback> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final limited = bucket.limit > 0;
    final spoken = [
      bucket.title,
      if (limited)
        l10n.boardColumnTaskCountOfLimit(count, bucket.limit)
      else
        l10n.boardColumnTaskCount(count),
      if (full) l10n.boardColumnFull,
      if (isDoneColumn) l10n.boardDoneColumnHint,
    ].join('\n');
    final heading = Semantics(
      header: true,
      headingLevel: 2,
      container: true,
      label: spoken,
      customSemanticsActions: actions.isEmpty ? null : actions,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDoneColumn) ...[
              Tooltip(
                message: l10n.boardDoneColumnHint,
                child: Icon(Icons.done_all, size: 20, color: colors.primary),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(bucket.title, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: 8),
            CountBadge(
              count: count,
              limit: limited ? bucket.limit : null,
              alert: full,
            ),
          ],
        ),
      ),
    );
    final menu = this.menu;
    if (menu == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: heading,
      );
    }
    // The button's own padding stands in for the header's at its end; at
    // the top, where a short column keeps it in sight under a long title.
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: heading,
            ),
          ),
          menu,
        ],
      ),
    );
  }
}

/// "Add a task" at the bottom of a column; disabled, with the web's limit
/// text as its tooltip, while the column is full.
class _AddTaskButton extends StatelessWidget {
  const new({
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String label;

  /// The shown text and the column's title, as every column has the
  /// button.
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label, semanticsLabel: semanticsLabel),
      style: TextButton.styleFrom(alignment: AlignmentDirectional.centerStart),
    );
    return onPressed == null
        ? Tooltip(
            message: context.l10n.boardColumnLimitReached,
            triggerMode: TooltipTriggerMode.tap,
            child: button,
          )
        : button;
  }
}

class _LoadMore extends StatelessWidget {
  const new({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Center(
        child: loading
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    semanticsLabel: l10n.boardLoadingMore,
                  ),
                ),
              )
            : TextButton(onPressed: onPressed, child: Text(l10n.boardLoadMore)),
      ),
    );
  }
}

/// Where a dragged card would go: a bar in the gap between two cards.
const _dropLine = DropLine(indent: 8, end: 8);

/// A card's place in its column ([SlotRegistration]): paints the drop
/// line into the gap above or below without moving any card.
class _CardSlot extends StatelessWidget {
  const new({
    required this.taskId,
    required this.slots,
    required this.held,
    required this.lineAbove,
    required this.lineBelow,
    required this.child,
    super.key,
  });

  static const _gap = 4.0;

  final int taskId;
  final Map<int, BuildContext> slots;
  final bool held;
  final bool lineAbove;
  final bool lineBelow;
  final Widget child;

  @override
  Widget build(BuildContext context) => SlotRegistration(
    id: taskId,
    slots: slots,
    keepAlive: held,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: _gap),
          child: child,
        ),
        if (lineAbove)
          const Positioned(left: 0, right: 0, top: 0, child: _dropLine),
        if (lineBelow)
          const Positioned(left: 0, right: 0, bottom: 0, child: _dropLine),
      ],
    ),
  );
}
