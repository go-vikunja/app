import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_column.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

/// A card picked up from the column of [bucketId].
@immutable
final class _CardDrag {
  const new(this.task, this.bucketId);

  final Task task;
  final int bucketId;
}

typedef _DropTarget = ({int bucketId, int index});

/// A kanban view as a board: fixed-width columns side by side, snapping to
/// a column on a phone. Unless [readOnly], a long press lifts a card to
/// drop it elsewhere (the board and the column scroll near their edges),
/// screen readers move cards with the card's actions, and each column adds
/// tasks on its top. Moves queue through the repository like every write.
class ProjectBoard extends ConsumerStatefulWidget {
  const new({
    required this.projectId,
    required this.view,
    required this.source,
    required this.readOnly,
    required this.offline,
    required this.now,
    required this.minimumPriority,
    required this.pendingIds,
    this.header,
    this.bottomPadding = 0,
    super.key,
  });

  final int projectId;
  final ProjectView view;
  final BoardSource source;

  /// A filter-mode board or an archived project's: nothing moves or adds.
  final bool readOnly;

  /// Further pages then load only when asked for.
  final bool offline;
  final DateTime now;
  final int minimumPriority;
  final Set<int> pendingIds;

  /// Above the board; on a short screen it gets what the board can spare
  /// and scrolls on its own, so that the columns end on screen.
  final Widget? header;

  /// Room below each column's last item, e.g. to scroll it above a
  /// floating action button.
  final double bottomPadding;

  @override
  ConsumerState<ProjectBoard> createState() => _ProjectBoardState();
}

class _ProjectBoardState extends ConsumerState<ProjectBoard> {
  static const _gap = 8.0;
  static const _sidePadding = 12.0;
  static const _maxColumnWidth = 340.0;
  static const _minBoardHeight = 320.0;
  static const _autoScrollEdge = 48.0;

  /// [NoticeSliver]'s space above the notes.
  static const _noticeTop = 8.0;

  /// Room for the next column to peek in on a phone, at most 340 wide.
  static double _columnWidthIn(double boardWidth) =>
      math.min(boardWidth - 48, _maxColumnWidth);

  final _horizontal = ScrollController();
  final _snapGrid = _SnapGrid();
  var _snaps = false;
  late final _snapPhysics = _ColumnSnapPhysics(_snapGrid);
  var _followScheduled = false;
  final GlobalKey _boardKey = GlobalKey();
  final _columnKeys = <int, GlobalKey<BoardColumnViewState>>{};

  List<BoardColumn> _columns = const [];
  BoardSource? _builtFrom;
  ProjectView? _builtFor;

  _CardDrag? _dragging;
  Offset? _pointer;
  _DropTarget? _dropTarget;
  EdgeDraggingAutoScroller? _boardScroller;
  BoardColumnViewState? _scrollingColumn;

  final _loadingMore = <int>{};

  /// By bucket, how many cards the column had when scrolling last loaded
  /// more: it loads again only once that changed, so a page that brought
  /// nothing or failed is not asked for on every scroll step.
  final _scrollLoadedAt = <int, int>{};

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(_boardScrolled);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _horizontal.dispose();
    super.dispose();
  }

  List<BoardColumn> get _board {
    final source = widget.source;
    final view = widget.view;
    if (!identical(source, _builtFrom) || !identical(view, _builtFor)) {
      _builtFrom = source;
      _builtFor = view;
      _columns = buildBoard(
        view: view,
        buckets: source.buckets,
        snapshot: source.snapshot,
        loadedAt: source.loadedAt,
        projectTasks: source.projectTasks,
        queued: source.queued,
        movedHere: source.movedHere,
      );
    }
    return _columns;
  }

  BoardColumn? _columnOf(int bucketId) =>
      _columns.where((column) => column.bucket.id == bucketId).firstOrNull;

  void _announce(String message) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );

  void _refuseFullColumn() {
    unawaited(HapticFeedback.heavyImpact());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.boardColumnLimitReached)),
      );
  }

  /// Puts [task] at [index] of the column of [toBucketId], counted without
  /// the card itself, and announces [moved] once it is queued.
  Future<void> _move(
    Task task, {
    required int toBucketId,
    required int index,
    required String moved,
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    final move = planCardMove(
      view: widget.view,
      columns: _columns,
      task: task,
      toBucketId: toBucketId,
      index: index,
    );
    switch (move) {
      case null:
        return;
      case ColumnFull():
        _refuseFullColumn();
      case MarkCardDone(:final placement):
        unawaited(HapticFeedback.selectionClick());
        _announce(moved);
        await repository.placeTask(
          task.id,
          viewId: widget.view.id,
          placement: placement,
          done: true,
        );
      case PlaceCard(:final placement, :final done):
        unawaited(HapticFeedback.selectionClick());
        _announce(moved);
        await repository.placeTask(
          task.id,
          viewId: widget.view.id,
          placement: placement,
          done: done,
        );
    }
  }

  Map<CustomSemanticsAction, VoidCallback> _actionsFor(
    BoardColumn column,
    Task task,
    int index,
  ) {
    final l10n = context.l10n;
    void moveTo(int bucketId, int index, String moved) => unawaited(
      _move(task, toBucketId: bucketId, index: index, moved: moved),
    );
    final titleUses = <String, int>{};
    for (final other in _columns) {
      titleUses.update(other.bucket.title, (n) => n + 1, ifAbsent: () => 1);
    }
    // Actions with the same label are one action to the semantics tree, so
    // columns of the same title are told apart by their place.
    String nameOf(int place, Bucket bucket) => titleUses[bucket.title]! > 1
        ? '${bucket.title} (${place + 1})'
        : bucket.title;
    // A repeating task keeps no place in the done column (it reopens), and
    // nothing goes below the last card loaded of a column with more.
    final doneBucketId = widget.view.doneBucketId;
    final reorders =
        !(task.repeats &&
            doneBucketId != 0 &&
            column.bucket.id == doneBucketId);
    final lowest = column.tasks.length - (column.hasMore ? 2 : 1);
    return {
      for (final (place, other) in _columns.indexed)
        if (other.bucket.id != column.bucket.id)
          CustomSemanticsAction(
            label: l10n.boardMoveTo(nameOf(place, other.bucket)),
          ): () => moveTo(
            other.bucket.id,
            0,
            l10n.boardMovedTo(nameOf(place, other.bucket)),
          ),
      if (reorders && index > 0)
        CustomSemanticsAction(label: l10n.boardMoveUp): () =>
            moveTo(column.bucket.id, index - 1, l10n.boardMovedUp),
      if (reorders && index < lowest)
        CustomSemanticsAction(label: l10n.boardMoveDown): () =>
            moveTo(column.bucket.id, index + 1, l10n.boardMovedDown),
    };
  }

  void _startDrag(Task task, int bucketId) {
    _snapGrid.holding = true;
    setState(() => _dragging = _CardDrag(task, bucketId));
  }

  /// [droppedOn]: the column that took the card, which the board then
  /// settles on.
  void _endDrag({int? droppedOn}) {
    _stopAutoScroll();
    _boardScroller = null;
    _scrollingColumn = null;
    _pointer = null;
    if (_snapGrid.holding) {
      _snapGrid.holding = false;
      if (mounted && _horizontal.hasClients) {
        final column = droppedOn == null
            ? -1
            : _board.indexWhere((c) => c.bucket.id == droppedOn);
        final position = _horizontal.position;
        if (_snaps && column >= 0) {
          _horizontal.animateTo(
            (column * _snapGrid.step).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          // A jump ends ballistic: with no card held, the board settles on
          // a column.
          _horizontal.jumpTo(_horizontal.offset);
        }
      }
    }
    if (!mounted || (_dragging == null && _dropTarget == null)) return;
    setState(() {
      _dragging = null;
      _dropTarget = null;
    });
  }

  /// While a card is held, the drop target follows the columns moving
  /// under the finger, once they are laid out at the new offset.
  void _boardScrolled() {
    if (_dragging == null || _followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      _followPointer();
    });
  }

  void _stopAutoScroll() {
    _boardScroller?.stopAutoScroll();
    _scrollingColumn?.stopAutoScroll();
  }

  void _dragMoved(Offset pointer) {
    _pointer = pointer;
    _followPointer();
  }

  /// Where the card under the finger would go, and the scrolling near the
  /// board's sides and the column's ends; again after each scroll step, as
  /// the cards move under a finger that holds still.
  void _followPointer() {
    final pointer = _pointer;
    if (!mounted || pointer == null || _dragging == null) return;
    final boardBox = _boardKey.currentContext?.findRenderObject();
    if (boardBox is! RenderBox ||
        !(boardBox.localToGlobal(Offset.zero) & boardBox.size).contains(
          pointer,
        )) {
      _stopAutoScroll();
      _setDropTarget(null);
      return;
    }
    _autoScrollBoard(pointer);
    final (bucketId, columnState) = _columnAt(pointer);
    if (!identical(columnState, _scrollingColumn)) {
      _scrollingColumn?.stopAutoScroll();
      _scrollingColumn = columnState;
    }
    if (bucketId == null || columnState == null) {
      _setDropTarget(null);
      return;
    }
    columnState.autoScrollNear(pointer, onScrolled: _followPointer);
    _setDropTarget((
      bucketId: bucketId,
      index: columnState.insertionIndexAt(pointer),
    ));
  }

  void _autoScrollBoard(Offset pointer) {
    if (!_horizontal.hasClients) return;
    final scrollable = switch (_horizontal.position.context) {
      final ScrollableState state => state,
      _ => null,
    };
    if (scrollable == null) return;
    if (_boardScroller?.scrollable != scrollable) {
      _boardScroller?.stopAutoScroll();
      _boardScroller = EdgeDraggingAutoScroller(
        scrollable,
        onScrollViewScrolled: _followPointer,
        velocityScalar: 50,
      );
    }
    _boardScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: pointer, width: _autoScrollEdge * 2, height: 1),
    );
  }

  /// The column under [pointer]; the gap between two columns counts half to
  /// each.
  (int?, BoardColumnViewState?) _columnAt(Offset pointer) {
    for (final column in _columns) {
      final key = _columnKeys[column.bucket.id];
      final box = key?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final left = box.localToGlobal(Offset.zero).dx;
      if (pointer.dx >= left - _gap / 2 &&
          pointer.dx < left + box.size.width + _gap / 2) {
        return (column.bucket.id, key!.currentState);
      }
    }
    return (null, null);
  }

  void _setDropTarget(_DropTarget? target) {
    if (target == _dropTarget) return;
    setState(() => _dropTarget = target);
  }

  /// Where [column] shows the drop line: not for a drop that changes
  /// nothing, nor on a full column the card comes from elsewhere.
  int? _dropLineIn(BoardColumn column) {
    final target = _dropTarget;
    final drag = _dragging;
    if (target == null || drag == null) return null;
    if (target.bucketId != column.bucket.id) return null;
    if (drag.bucketId != column.bucket.id) {
      return columnIsFull(column) ? null : target.index;
    }
    final from = column.tasks.indexWhere((task) => task.id == drag.task.id);
    return target.index == from || target.index == from + 1
        ? null
        : target.index;
  }

  void _drop(_CardDrag drag) {
    final target = _dropTarget;
    _endDrag(droppedOn: target?.bucketId);
    final column = target == null ? null : _columnOf(target.bucketId);
    if (target == null || column == null) return;
    final l10n = context.l10n;
    if (target.bucketId != drag.bucketId) {
      unawaited(
        _move(
          drag.task,
          toBucketId: target.bucketId,
          index: target.index,
          moved: l10n.boardMovedTo(column.bucket.title),
        ),
      );
      return;
    }
    final from = column.tasks.indexWhere((task) => task.id == drag.task.id);
    // The index counted the card itself, which still held its place.
    final index = from >= 0 && from < target.index
        ? target.index - 1
        : target.index;
    unawaited(
      _move(
        drag.task,
        toBucketId: target.bucketId,
        index: index,
        moved: index < from ? l10n.boardMovedUp : l10n.boardMovedDown,
      ),
    );
  }

  void _loadMoreOnScroll(BoardColumn column) {
    final bucketId = column.bucket.id;
    if (!column.hasMore ||
        widget.offline ||
        _scrollLoadedAt[bucketId] == column.tasks.length) {
      return;
    }
    _scrollLoadedAt[bucketId] = column.tasks.length;
    unawaited(_loadMore(bucketId));
  }

  Future<void> _loadMore(int bucketId) async {
    if (_loadingMore.contains(bucketId)) return;
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.boardLoadMoreFailed;
    setState(() => _loadingMore.add(bucketId));
    try {
      await repository.loadMoreOfBucket(
        widget.projectId,
        widget.view.id,
        bucketId,
      );
    } on Object {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failed)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore.remove(bucketId));
    }
  }

  void _addTaskTo(BoardColumn column) {
    final view = widget.view;
    final defaultBucket = defaultColumnOf(view, _columns)!.bucket;
    final limit = column.bucket.limit;
    unawaited(
      showNewTaskSheet(
        context,
        projectId: widget.projectId,
        column: NewTaskColumn(
          viewId: view.id,
          bucketId: column.bucket.id,
          defaultBucket: defaultBucket,
          topPosition: column.tasks.firstOrNull?.position,
          done: view.doneBucketId != 0 && column.bucket.id == view.doneBucketId,
          // The server puts new tasks into the default column whatever its
          // limit, and moving them there is then no move.
          room: limit > 0 && column.bucket.id != defaultBucket.id
              ? math.max(limit - column.shownCount, 0)
              : null,
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    BoardColumn column,
    Task task,
    int index, {
    required double width,
  }) {
    final pending = widget.pendingIds.contains(task.id);
    final card = BoardCard(
      task: task,
      now: widget.now,
      minimumPriority: widget.minimumPriority,
      pending: pending,
      onTap: () => unawaited(showTaskDetail(context, task: task)),
      actions: widget.readOnly ? const {} : _actionsFor(column, task, index),
    );
    if (widget.readOnly) return card;
    return LongPressDraggable<_CardDrag>(
      data: _CardDrag(task, column.bucket.id),
      maxSimultaneousDrags: 1,
      feedback: _LiftedCard(
        width: width,
        child: BoardCard(
          task: task,
          now: widget.now,
          minimumPriority: widget.minimumPriority,
          pending: pending,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      onDragStarted: () => _startDrag(task, column.bucket.id),
      onDragUpdate: (details) => _dragMoved(details.globalPosition),
      onDragEnd: (_) => _endDrag(),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = _board;
    final view = widget.view;
    final insets = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // In landscape the first and last columns stay clear of a notch.
        final boardWidth = constraints.maxWidth - insets.horizontal;
        final columnWidth = _columnWidthIn(boardWidth);
        _snapGrid.step = columnWidth + _gap;
        // A phone shows one column at a time and snaps to the next.
        final snaps = _snaps =
            boardWidth < _sidePadding + 2 * (columnWidth + _gap);
        // The columns end at the bottom of the screen, where their last
        // cards can be scrolled to; on a short screen the notes above take
        // at most what is left above a board of this height.
        final boardHeight = math.min(
          _minBoardHeight,
          constraints.maxHeight * 0.6,
        );
        final board = SingleChildScrollView(
          key: _boardKey,
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          physics: snaps ? _snapPhysics : null,
          padding: EdgeInsets.fromLTRB(
            _sidePadding + insets.left,
            8,
            _sidePadding + insets.right,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, column) in columns.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                BoardColumnView(
                  key: _columnKeys.putIfAbsent(column.bucket.id, GlobalKey.new),
                  column: column,
                  width: columnWidth,
                  isDoneColumn:
                      view.doneBucketId != 0 &&
                      column.bucket.id == view.doneBucketId,
                  cardBuilder: (context, task, index) => _card(
                    context,
                    column,
                    task,
                    index,
                    width: columnWidth - 16,
                  ),
                  loadingMore: _loadingMore.contains(column.bucket.id),
                  onLoadMore: () => unawaited(_loadMore(column.bucket.id)),
                  onNearEnd: () => _loadMoreOnScroll(column),
                  onAddTask: widget.readOnly ? null : () => _addTaskTo(column),
                  draggedTaskId: _dragging?.task.id,
                  dropIndex: _dropLineIn(column),
                  endPadding: widget.bottomPadding,
                ),
              ],
            ],
          ),
        );
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header case final header?)
              NoticeSliver(
                notice: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      constraints.maxHeight - boardHeight - _noticeTop,
                      0,
                    ),
                  ),
                  child: ListView(
                    primary: false,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [header],
                  ),
                ),
              ),
            SliverLayoutBuilder(
              builder: (context, sliver) => SliverToBoxAdapter(
                child: SizedBox(
                  height: math.max(
                    sliver.viewportMainAxisExtent -
                        sliver.precedingScrollExtent,
                    boardHeight,
                  ),
                  child: DragTarget<_CardDrag>(
                    onWillAcceptWithDetails: (_) => !widget.readOnly,
                    onAcceptWithDetails: (details) => _drop(details.data),
                    onLeave: (_) => _setDropTarget(null),
                    builder: (context, _, _) => board,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The card as it hangs under the finger while dragged.
class _LiftedCard extends StatelessWidget {
  const new({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Transform.rotate(
      angle: 0.03,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
        child: child,
      ),
    ),
  );
}

/// What the column snapping reads when the board settles, kept current by
/// the board: a scrollable keeps the physics it started with while their
/// type stays.
final class _SnapGrid {
  /// From one column start to the next.
  double step = 0;

  /// A card is held over the board, which must not move under the finger.
  bool holding = false;
}

/// Settles on the nearest column start, like a page view with pages as
/// wide as a column, unless a card is held.
class _ColumnSnapPhysics extends ScrollPhysics {
  const new(this.grid, {super.parent});

  final _SnapGrid grid;

  @override
  _ColumnSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _ColumnSnapPhysics(grid, parent: buildParent(ancestor));

  double _target(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    var column = position.pixels / grid.step;
    if (velocity < -tolerance.velocity) {
      column -= 0.5;
    } else if (velocity > tolerance.velocity) {
      column += 0.5;
    }
    return (column.roundToDouble() * grid.step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (grid.holding ||
        grid.step <= 0 ||
        (velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _target(position, velocity);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}
