import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';

/// Behind the timeline, below [top] (the header): a line at every day
/// boundary, stronger at a new month, and weekends tinted. Only what
/// [horizontal] shows is painted.
class TimelineGridPainter extends CustomPainter {
  new({
    required this.days,
    required this.top,
    required this.horizontal,
    required this.colors,
  }) : super(repaint: horizontal);

  final TimelineDays days;
  final double top;
  final ScrollController horizontal;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    var left = 0.0;
    var right = size.width;
    if (horizontal.hasClients && horizontal.positions.length == 1) {
      final position = horizontal.position;
      if (position.hasContentDimensions && position.hasViewportDimension) {
        left = position.pixels;
        right = left + position.viewportDimension;
      }
    }
    final (firstIndex, endIndex) = days.visible(
      left - days.dayWidth,
      right + days.dayWidth,
    );
    final weekend = Paint()
      ..color = colors.surfaceContainerHighest.withValues(alpha: 0.45);
    final dayLine = Paint()
      ..color = colors.outlineVariant.withValues(alpha: 0.6)
      ..strokeWidth = 0.5;
    final monthLine = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 1;
    for (var index = firstIndex; index < endIndex; index++) {
      final day = days.dayAt(index);
      final x = days.xOf(index);
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        canvas.drawRect(
          Rect.fromLTWH(x, top, days.dayWidth, size.height - top),
          weekend,
        );
      }
      if (index > 0) {
        canvas.drawLine(
          Offset(x, top),
          Offset(x, size.height),
          day.day == 1 ? monthLine : dayLine,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TimelineGridPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.top != top ||
      oldDelegate.colors != colors;
}
