import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// What a swipe in one direction does, shown in the strip the row uncovers.
@immutable
final class SwipeAction {
  const new({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTriggered,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback onTriggered;
}

/// [child] follows a horizontal swipe. [startAction] is uncovered at the
/// start edge, so it is a swipe toward the end (rightward in a
/// left-to-right language), and [endAction] the other way. Released past
/// [threshold] of the width, or flung that way past a quarter of it, the
/// action runs and the row slides back; crossing the threshold ticks.
/// Without an action in a direction the row does not move that way, and
/// without any it takes no horizontal drags at all, so they reach what is
/// around it. Screen readers get the actions elsewhere, as custom actions
/// of the row.
class SwipeActions extends StatefulWidget {
  const new({
    required this.child,
    this.startAction,
    this.endAction,
    this.threshold = 0.35,
    super.key,
  });

  final Widget child;
  final SwipeAction? startAction;
  final SwipeAction? endAction;
  final double threshold;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  static const _flingVelocity = 700.0;
  static const _flingFraction = 0.25;

  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_onBack);

  /// Along the reading direction: positive uncovers the start edge.
  double _offset = 0;
  double _backFrom = 0;
  double _width = 1;
  bool _armed = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _onBack() => setState(
    () => _offset = _backFrom * (1 - Curves.easeOut.transform(_back.value)),
  );

  bool get _ltr => Directionality.of(context) == TextDirection.ltr;

  void _start(DragStartDetails details) {
    _back.stop();
  }

  void _update(DragUpdateDetails details) {
    final delta = (_ltr ? 1 : -1) * (details.primaryDelta ?? 0);
    final min = widget.endAction == null ? 0.0 : -_width;
    final max = widget.startAction == null ? 0.0 : _width;
    final next = (_offset + delta).clamp(min, max);
    final armed = next.abs() >= widget.threshold * _width;
    if (armed != _armed) unawaited(HapticFeedback.selectionClick());
    setState(() {
      _offset = next;
      _armed = armed;
    });
  }

  void _end(DragEndDetails details) {
    final velocity = (_ltr ? 1 : -1) * details.primaryVelocity!;
    final flung =
        velocity.abs() >= _flingVelocity &&
        velocity.sign == _offset.sign &&
        _offset.abs() >= _flingFraction * _width;
    final action = _offset > 0 ? widget.startAction : widget.endAction;
    if ((_armed || flung) && _offset != 0) action?.onTriggered();
    _settle();
  }

  void _settle() {
    _armed = false;
    if (_offset == 0) return;
    _backFrom = _offset;
    _back.forward(from: 0);
  }

  @override
  void didUpdateWidget(SwipeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.startAction == null && _offset > 0) ||
        (widget.endAction == null && _offset < 0)) {
      _settle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final swipes = widget.startAction != null || widget.endAction != null;
    final action = _offset > 0
        ? widget.startAction
        : _offset < 0
        ? widget.endAction
        : null;
    final row = LayoutBuilder(
      builder: (context, constraints) {
        _width = math.max(1, constraints.maxWidth);
        return ClipRect(
          child: Stack(
            children: [
              if (action != null)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: _Strip(
                      action: action,
                      atStart: _offset > 0,
                      width: _offset.abs(),
                      armed: _armed,
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset((_ltr ? 1 : -1) * _offset, 0),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
    // Always there, so that actions coming or going keep the row's
    // subtree, and with it a screen reader's place. Its own semantics would
    // offer scroll actions that run the actions; the row has them as
    // custom actions instead.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onHorizontalDragStart: swipes ? _start : null,
      onHorizontalDragUpdate: swipes ? _update : null,
      onHorizontalDragEnd: swipes ? _end : null,
      onHorizontalDragCancel: swipes ? _settle : null,
      child: row,
    );
  }
}

/// The uncovered part beside the row: the action's colour, its icon at
/// the row's edge and, once it fits whole, its name; fainter until the
/// swipe would act.
class _Strip extends StatelessWidget {
  const new({
    required this.action,
    required this.atStart,
    required this.width,
    required this.armed,
  });

  final SwipeAction action;
  final bool atStart;
  final double width;
  final bool armed;

  static const _padding = 20.0;
  static const _gap = 8.0;

  bool _labelFits(BuildContext context, TextStyle? style) {
    final bold = MediaQuery.boldTextOf(context);
    final painter = TextPainter(
      text: TextSpan(
        text: action.label,
        style: DefaultTextStyle.of(context).style
            .merge(style)
            .merge(bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final needed =
        2 * _padding +
        (IconTheme.of(context).size ?? 24) +
        _gap +
        painter.width;
    painter.dispose();
    return width >= needed;
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: action.onColor);
    final icon = Icon(action.icon, color: action.onColor);
    final label = _labelFits(context, style)
        ? [Text(action.label, style: style)]
        : const <Widget>[];
    return Align(
      alignment: atStart
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: width,
        height: double.infinity,
        // The row above it is transparent, so nothing may spill out.
        child: ClipRect(
          child: ColoredBox(
            color: armed ? action.color : action.color.withValues(alpha: 0.7),
            child: OverflowBox(
              alignment: atStart
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              maxWidth: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _padding),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: atStart
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.end,
                  spacing: _gap,
                  children: atStart ? [icon, ...label] : [...label, icon],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
