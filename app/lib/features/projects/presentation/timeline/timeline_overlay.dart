import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';

/// Over the rows, which scroll with [vertical]: the relation arrows, each
/// from the right end of its source bar to the left end of its target,
/// and a line down the middle of today.
class TimelineOverlayPainter extends CustomPainter {
  new({
    required this.days,
    required this.today,
    required this.arrows,
    required this.rowHeight,
    required this.vertical,
    required this.colors,
  }) : super(repaint: vertical);

  final TimelineDays days;
  final CalendarDate today;
  final List<GanttArrow> arrows;
  final double rowHeight;
  final ScrollController vertical;
  final ColorScheme colors;

  static const _headLength = 7.0;
  static const _routeOffset = 16.0;

  double get _scrolled {
    if (!vertical.hasClients || vertical.positions.length != 1) return 0;
    return vertical.position.hasPixels ? vertical.position.pixels : 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final scrolled = _scrolled;
    final firstShown = (scrolled / rowHeight).floor();
    final lastShown = ((scrolled + size.height) / rowHeight).ceil();
    final blocking = Paint()
      ..color = colors.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final precedes = Paint()
      ..color = colors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final arrow in arrows) {
      final top = math.min(arrow.fromRow, arrow.toRow);
      final bottom = math.max(arrow.fromRow, arrow.toRow);
      if (bottom < firstShown - 1 || top > lastShown + 1) continue;
      final start = Offset(
        math.min(days.xOf(arrow.fromColumn), days.width),
        _centreOf(arrow.fromRow, scrolled) + arrow.fromOffset,
      );
      final end = Offset(
        math.max(days.xOf(arrow.toColumn), 0),
        _centreOf(arrow.toRow, scrolled) + arrow.toOffset,
      );
      final paint = arrow.kind == GanttArrowKind.blocking ? blocking : precedes;
      final path = _route(start, end);
      if (arrow.kind == GanttArrowKind.precedes) {
        _dashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
      canvas.drawPath(
        Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - _headLength, end.dy - _headLength / 2)
          ..lineTo(end.dx - _headLength, end.dy + _headLength / 2)
          ..close(),
        Paint()..color = paint.color,
      );
    }
    final todayIndex = days.indexOf(today);
    if (todayIndex >= 0 && todayIndex < days.count) {
      final x = days.xOf(todayIndex) + days.dayWidth / 2;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = colors.primary.withValues(alpha: 0.8)
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  double _centreOf(int row, double scrolled) =>
      row * rowHeight + rowHeight / 2 - scrolled;

  /// An S-curve to a target on the right; to one on the left, out to the
  /// right first, along between the rows and back in from the left.
  Path _route(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final path = Path()..moveTo(start.dx, start.dy);
    if (dx >= _routeOffset) {
      final bend = math.min(dx / 2, 48);
      return path..cubicTo(
        start.dx + bend,
        start.dy,
        end.dx - bend,
        end.dy,
        end.dx - _headLength,
        end.dy,
      );
    }
    final between =
        start.dy + (end.dy >= start.dy ? rowHeight / 2 : -rowHeight / 2);
    final out = start.dx + _routeOffset;
    final back = end.dx - _routeOffset;
    return path
      ..cubicTo(out, start.dy, out, start.dy, out, between)
      ..lineTo(back, between)
      ..cubicTo(back, end.dy, back, end.dy, end.dx - _headLength, end.dy);
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      for (
        var distance = 0.0;
        distance < metric.length;
        distance += dash + gap
      ) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dash, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TimelineOverlayPainter oldDelegate) =>
      !identical(oldDelegate.arrows, arrows) ||
      oldDelegate.days != days ||
      oldDelegate.today != today ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.colors != colors;
}
