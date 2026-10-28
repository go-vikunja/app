import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/motion.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_grid.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_overlay.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_today.dart';

/// A Gantt view's timeline: the days side by side under a two-row header
/// that stays put, one row per task built as it scrolls into view, the
/// relation arrows and today's line over them. It opens with today in its
/// left third, scrolls there again on [TimelineTodayRequests], and two
/// fingers zoom the days between the widths the preferences allow.
class TimelineChart extends ConsumerStatefulWidget {
  const new({
    required this.viewId,
    required this.layout,
    required this.dayWidth,
    required this.onOpen,
    required this.onToggleCollapsed,
    required this.onDayWidthChanged,
    this.onPinchChanged,
    this.bottomPadding = 0,
    super.key,
  });

  final int viewId;
  final GanttLayout layout;
  final double dayWidth;
  final ValueChanged<Task> onOpen;
  final ValueChanged<int> onToggleCollapsed;

  /// When a pinch ends, with the width it left.
  final ValueChanged<double> onDayWidthChanged;

  /// When two fingers start and stop zooming, for the scroll views
  /// around the chart to let go of them too: else the one left wins their
  /// drag and pulls to refresh.
  final ValueChanged<bool>? onPinchChanged;

  /// Below the last row, to scroll it clear of a floating action button.
  final double bottomPadding;

  @override
  ConsumerState<TimelineChart> createState() => _TimelineChartState();
}

class _TimelineChartState extends ConsumerState<TimelineChart> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _pointers = <int, Offset>{};

  late double _dayWidth = TimelineDays.clampWidth(widget.dayWidth);
  ({double distance, double width, double day})? _pinch;
  double? _pendingOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) scrollToToday(animate: false);
    });
  }

  @override
  void didUpdateWidget(TimelineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final width = TimelineDays.clampWidth(widget.dayWidth);
    if (width != TimelineDays.clampWidth(oldWidget.dayWidth) &&
        width != _dayWidth &&
        _pinch == null) {
      _zoomAroundCentre(width, rebuild: false);
    }
  }

  @override
  void dispose() {
    if (_pinch != null) {
      final onPinchChanged = widget.onPinchChanged;
      // Not while the tree is locked.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onPinchChanged?.call(false),
      );
    }
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  TimelineDays get _days =>
      TimelineDays(range: widget.layout.range, dayWidth: _dayWidth);

  /// Today in the left third, when the range has it.
  void scrollToToday({bool animate = true}) {
    final column = widget.layout.todayColumn;
    if (column == null || !_horizontal.hasClients) return;
    final position = _horizontal.position;
    final target =
        (_days.xOf(column) + _dayWidth / 2 - position.viewportDimension / 3)
            .clamp(0.0, position.maxScrollExtent);
    if (animate && !reduceMotionOf(context)) {
      _horizontal.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _horizontal.jumpTo(target);
    }
  }

  /// [rebuild] false from [didUpdateWidget], which builds anyway.
  void _zoomAroundCentre(double width, {bool rebuild = true}) {
    void apply() {
      if (_horizontal.hasClients) {
        final position = _horizontal.position;
        final centre = position.viewportDimension / 2;
        _pendingOffset =
            (position.pixels + centre) / _dayWidth * width - centre;
      }
      _dayWidth = width;
    }

    rebuild ? setState(apply) : apply();
  }

  /// The offset a zoom asked for, once the new width is laid out.
  void _applyPendingOffset() {
    final offset = _pendingOffset;
    if (offset == null) return;
    _pendingOffset = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontal.hasClients) return;
      final position = _horizontal.position;
      _horizontal.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    });
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) _startPinch();
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    _updatePinch();
  }

  void _pointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _pinch != null) {
      setState(() => _pinch = null);
      widget.onPinchChanged?.call(false);
      widget.onDayWidthChanged(_dayWidth);
    }
  }

  (double, double) _spread() {
    final points = _pointers.values.take(2).toList();
    return (
      (points[0] - points[1]).distance,
      (points[0].dx + points[1].dx) / 2,
    );
  }

  void _startPinch() {
    if (!_horizontal.hasClients) return;
    final (distance, focal) = _spread();
    if (distance < 1) return;
    // The scroll views let go of their drags, which the pinch replaces.
    setState(
      () => _pinch = (
        distance: distance,
        width: _dayWidth,
        day: (_horizontal.position.pixels + focal) / _dayWidth,
      ),
    );
    widget.onPinchChanged?.call(true);
  }

  void _updatePinch() {
    final pinch = _pinch;
    if (pinch == null || _pointers.length < 2) return;
    final (distance, focal) = _spread();
    final width = TimelineDays.clampWidth(
      pinch.width * distance / pinch.distance,
    );
    if (width == _dayWidth) return;
    setState(() {
      _dayWidth = width;
      _pendingOffset = pinch.day * width - focal;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      timelineTodayRequestsProvider(widget.viewId),
      (_, _) => scrollToToday(),
    );
    _applyPendingOffset();
    final layout = widget.layout;
    final days = _days;
    final colors = Theme.of(context).colorScheme;
    final headerHeight = TimelineHeader.heightOf(context);
    final metrics = TimelineRowMetrics.of(context);
    final rows = layout.rows;
    final spans = layout.groupSpans;
    final today = layout.today;
    final semantics = TimelineSemantics.of(context, layout: layout);
    final pinching = _pinch != null;
    final ScrollPhysics? scrollPhysics = pinching
        ? const NeverScrollableScrollPhysics()
        : null;

    final chart = Listener(
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerUp,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        physics: scrollPhysics,
        child: SizedBox(
          width: days.width,
          child: CustomPaint(
            painter: TimelineGridPainter(
              days: days,
              top: headerHeight,
              horizontal: _horizontal,
              colors: colors,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TimelineHeader(
                  days: days,
                  today: today,
                  horizontal: _horizontal,
                ),
                Expanded(
                  child: CustomPaint(
                    foregroundPainter: TimelineOverlayPainter(
                      days: days,
                      today: today,
                      arrows: layout.arrows,
                      rowHeight: metrics.rowHeight,
                      vertical: _vertical,
                      colors: colors,
                    ),
                    child: ListView.builder(
                      controller: _vertical,
                      physics: pinching
                          ? const NeverScrollableScrollPhysics()
                          : const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: widget.bottomPadding),
                      itemExtent: metrics.rowHeight,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final task = row.task;
                        return TimelineRow(
                          key: ValueKey(task.id),
                          row: row,
                          days: days,
                          horizontal: _horizontal,
                          metrics: metrics,
                          semanticsLabel: semantics.labelOf(row),
                          groupSpans: spans[index],
                          collapsed: row.collapsed,
                          onTap: () => widget.onOpen(task),
                          onToggleCollapsed: row.canCollapse
                              ? () => widget.onToggleCollapsed(task.id)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        chart,
        // Over the header, which is only painted and scrolls sideways; this
        // stays in view for a screen reader and takes no touches.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerHeight,
          child: Semantics(
            container: true,
            label: semantics.summary,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

/// What a screen reader hears for a row: the title, its parent, done, its
/// dates as the task has them (a derived bar's as drawn) and the relations
/// drawn as arrows from and to it; for the header, today and the range.
final class TimelineSemantics {
  factory of(BuildContext context, {required GanttLayout layout}) =>
      TimelineSemantics._(
        context.l10n,
        MaterialLocalizations.of(context),
        layout,
      );

  new _(this._l10n, this._material, this._layout);

  final AppLocalizations _l10n;
  final MaterialLocalizations _material;
  final GanttLayout _layout;

  CalendarDate get _today => _layout.today;

  /// Per task id and kind, the titles at the arrows' other ends, in the
  /// order the arrows are drawn.
  late final Map<(int, _Relation), List<String>> _related = () {
    final related = <(int, _Relation), List<String>>{};
    String titleOf(int taskId) =>
        _layout.rows[_layout.rowOf(taskId)!].task.title;
    void add(int taskId, _Relation relation, int otherId) =>
        related.putIfAbsent((taskId, relation), () => []).add(titleOf(otherId));
    for (final arrow in _layout.arrows) {
      final (from, to) = switch (arrow.kind) {
        GanttArrowKind.blocking => (_Relation.blocks, _Relation.blockedBy),
        GanttArrowKind.precedes => (_Relation.precedes, _Relation.follows),
      };
      add(arrow.fromTaskId, from, arrow.toTaskId);
      add(arrow.toTaskId, to, arrow.fromTaskId);
    }
    return related;
  }();

  String get summary => _l10n.projectTimelineSummarySemantics(
    _material.formatFullDate(_today.toDateTime()),
    _l10n.projectTimelineSpanSemantics(
      _date(_layout.range.from),
      _date(_layout.range.to),
    ),
  );

  String _date(CalendarDate day) => day.year == _today.year
      ? _material.formatMediumDate(day.toDateTime())
      : _material.formatFullDate(day.toDateTime());

  String _moment(DateTime moment) => _date(CalendarDate.of(moment.toLocal()));

  String _dates(GanttRow row) {
    final task = row.task;
    final bar = row.bar;
    final start = task.startDate;
    final ends = task.endDate;
    final due = task.dueDate;
    final end = ends ?? due;
    String drawn() =>
        _l10n.projectTimelineSpanSemantics(_date(bar.first), _date(bar.last));
    return switch (bar.kind) {
      GanttBarKind.estimated => _l10n.projectTimelineEstimatedSemantics,
      _ when bar.derived => drawn(),
      GanttBarKind.scheduled when start != null && end != null =>
        _l10n.projectTimelineSpanSemantics(_moment(start), _moment(end)),
      GanttBarKind.startOnly when start != null =>
        _l10n.projectTimelineStartOnlySemantics(_moment(start)),
      GanttBarKind.endOnly when ends != null =>
        _l10n.projectTimelineEndOnlySemantics(_moment(ends)),
      GanttBarKind.endOnly when due != null =>
        _l10n.projectTimelineDueOnlySemantics(_moment(due)),
      _ => drawn(),
    };
  }

  String labelOf(GanttRow row) {
    final task = row.task;
    final parent = row.parent;
    return [
      task.title,
      if (parent != null) _l10n.taskSubtaskOfSemantics(parent.title),
      if (task.done) _l10n.taskDoneSemantics,
      _dates(row),
      if (row.bar.derived) _l10n.projectTimelineDerivedSemantics,
      for (final relation in _Relation.values)
        if (_related[(task.id, relation)] case final titles?)
          relation.line(_l10n, titles.join(', ')),
    ].join('\n');
  }
}

enum _Relation {
  blocks,
  blockedBy,
  precedes,
  follows;

  String line(AppLocalizations l10n, String titles) => switch (this) {
    blocks => l10n.projectTimelineBlocksSemantics(titles),
    blockedBy => l10n.projectTimelineBlockedBySemantics(titles),
    precedes => l10n.projectTimelinePrecedesSemantics(titles),
    follows => l10n.projectTimelineFollowsSemantics(titles),
  };
}

/// The chart's height when it shares the screen with notes above it: what
/// is left, but at least enough for a few rows.
double timelineChartHeight(double available, BuildContext context) => math.max(
  available,
  TimelineHeader.heightOf(context) +
      3 * TimelineRowMetrics.of(context).rowHeight,
);
