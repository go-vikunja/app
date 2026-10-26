import 'package:flutter/widgets.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';

/// The day columns of a timeline: one per day of [range], each [dayWidth]
/// wide.
@immutable
final class TimelineDays {
  const new({required this.range, required this.dayWidth});

  /// What the zoom buttons step through, from
  /// [TimelinePreferences.minDayWidth] to [TimelinePreferences.maxDayWidth].
  static const zoomSteps = [20.0, 24.0, 30.0, 36.0, 44.0, 54.0, 64.0, 72.0];

  final GanttRange range;
  final double dayWidth;

  int get count => range.dayCount;

  double get width => count * dayWidth;

  CalendarDate dayAt(int index) => range.dayAt(index);

  /// May be outside 0 ..< [count].
  int indexOf(CalendarDate day) => day.daysSince(range.from);

  double xOf(int index) => index * dayWidth;

  /// The columns at least partly inside [left] ..< [right], clamped.
  (int, int) visible(double left, double right) => (
    (left / dayWidth).floor().clamp(0, count),
    (right / dayWidth).ceil().clamp(0, count),
  );

  static double clampWidth(double width) => width.clamp(
    TimelinePreferences.minDayWidth,
    TimelinePreferences.maxDayWidth,
  );

  static double? zoomedIn(double width) =>
      zoomSteps.where((step) => step > width + 0.5).firstOrNull;

  static double? zoomedOut(double width) =>
      zoomSteps.reversed.where((step) => step < width - 0.5).firstOrNull;

  @override
  bool operator ==(Object other) =>
      other is TimelineDays &&
      other.range == range &&
      other.dayWidth == dayWidth;

  @override
  int get hashCode => Object.hash(range, dayWidth);
}

/// What [controller] shows of its child, from its offset over its
/// viewport's width; before its first layout [fallbackWidth] from the
/// start, which is where it opens.
(double, double) visibleWindow(
  ScrollController controller, {
  required double fallbackWidth,
}) {
  if (controller.hasClients && controller.positions.length == 1) {
    final position = controller.position;
    if (position.hasContentDimensions && position.hasViewportDimension) {
      return (position.pixels, position.pixels + position.viewportDimension);
    }
  }
  return (0, fallbackWidth);
}
