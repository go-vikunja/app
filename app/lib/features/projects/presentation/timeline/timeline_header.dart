import 'dart:math' as math;

import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';

/// The timeline's two header rows: each month's name and year, kept on
/// screen while any of its days is, then each day's short weekday over its
/// number, today's filled. Only the days [horizontal] shows are built: a
/// custom range may span years.
class TimelineHeader extends StatelessWidget {
  const new({
    required this.days,
    required this.today,
    required this.horizontal,
    required this.viewportWidth,
    super.key,
  });

  final TimelineDays days;
  final CalendarDate today;
  final ScrollController horizontal;

  /// The chart's width: what [horizontal] shows before its first layout.
  final double viewportWidth;

  /// Up to 150 % text, as the Upcoming day strip; screen readers get the
  /// dates from each row instead.
  static const maxTextScale = 1.5;

  static const _monthSize = 12.0;
  static const _weekdaySize = 11.0;
  static const _numberSize = 13.0;
  static const _lineHeight = 1.3;

  /// Days built beyond each edge of the screen, so a fling shows no gap.
  static const _spareDays = 3;

  static TextScaler _scalerOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxTextScale);

  static double _line(TextScaler scaler, double size) =>
      (scaler.scale(size) * _lineHeight).ceilToDouble();

  static double _numberCircle(TextScaler scaler) =>
      math.max(22, _line(scaler, _numberSize) + 2);

  static double _monthRowHeight(TextScaler scaler) =>
      _line(scaler, _monthSize) + 8;

  static double _dayRowHeight(TextScaler scaler) =>
      4 + _line(scaler, _weekdaySize) + 2 + _numberCircle(scaler) + 6;

  static double heightOf(BuildContext context) {
    final scaler = _scalerOf(context);
    return _monthRowHeight(scaler) + _dayRowHeight(scaler);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = context.l10n.localeName;
    final scaler = _scalerOf(context);
    final monthHeight = _monthRowHeight(scaler);
    final dayHeight = _dayRowHeight(scaler);
    final circle = _numberCircle(scaler);
    final labelStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(height: _lineHeight);
    final monthStyle = labelStyle.copyWith(
      fontSize: _monthSize,
      fontWeight: FontWeight.w700,
      color: colors.onSurfaceVariant,
    );
    final weekdayStyle = labelStyle.copyWith(
      fontSize: _weekdaySize,
      color: colors.onSurfaceVariant,
    );
    final numberStyle = labelStyle.copyWith(
      fontSize: _numberSize,
      color: colors.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final direction = Directionality.of(context);
    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final width = days.dayWidth;
    final shortWeekdays = intl.DateFormat.E(locale);
    final widestWeekday = [
      for (var day = 1; day <= 7; day++)
        widthOf(shortWeekdays.format(DateTime(2024, 1, day)), weekdayStyle),
    ].reduce(math.max);
    final weekdays = widestWeekday > width - 4
        ? intl.DateFormat.EEEEE(locale)
        : shortWeekdays;
    // Too narrow for every number: every second one, and always today's.
    final numberStep = widthOf('28', numberStyle) > width - 2 ? 2 : 1;
    final months = intl.DateFormat.yMMMM(locale);
    final numbers = intl.DateFormat.d(locale);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: ExcludeSemantics(
        child: SizedBox(
          width: days.width,
          height: monthHeight + dayHeight,
          child: ListenableBuilder(
            listenable: horizontal,
            builder: (context, _) {
              final (left, right) = visibleWindow(
                horizontal,
                fallbackWidth: viewportWidth,
              );
              final (first, end) = days.visible(
                left - _spareDays * width,
                right + _spareDays * width,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HeaderLinesPainter(
                        days: days,
                        first: first,
                        end: end,
                        monthHeight: monthHeight,
                        color: colors.outlineVariant,
                      ),
                    ),
                  ),
                  ..._months(
                    first: first,
                    end: end,
                    left: left,
                    height: monthHeight,
                    format: months,
                    style: monthStyle,
                    widthOf: widthOf,
                  ),
                  for (var index = first; index < end; index++)
                    Positioned(
                      key: ValueKey(index),
                      left: days.xOf(index),
                      width: width,
                      top: monthHeight,
                      height: dayHeight,
                      child: _DayCell(
                        day: days.dayAt(index),
                        today: days.dayAt(index) == today,
                        weekday: weekdays,
                        number: numbers,
                        numberStep: numberStep,
                        circle: circle,
                        weekdayStyle: weekdayStyle,
                        numberStyle: numberStyle,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _months({
    required int first,
    required int end,
    required double left,
    required double height,
    required intl.DateFormat format,
    required TextStyle style,
    required double Function(String, TextStyle) widthOf,
  }) sync* {
    var index = first;
    while (index < end) {
      final day = days.dayAt(index);
      final next = day.month == 12
          ? CalendarDate(day.year + 1, 1, 1)
          : CalendarDate(day.year, day.month + 1, 1);
      final monthEnd = math.min(days.indexOf(next), days.count);
      final startX = math.max<double>(
        days.xOf(days.indexOf(CalendarDate(day.year, day.month, 1))),
        0,
      );
      final endX = days.xOf(monthEnd);
      final label = format.format(day.toDateTime());
      final latest = endX - widthOf(label, style) - 8;
      final x = latest < startX + 8
          ? startX + 8
          : math.min(math.max(startX, left) + 8, latest);
      yield Positioned(
        key: ValueKey(('month', day.year, day.month)),
        left: startX,
        width: endX - startX,
        top: 0,
        height: height,
        child: ClipRect(
          child: Padding(
            padding: EdgeInsets.only(left: x - startX),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ),
      );
      index = monthEnd;
    }
  }
}

class _DayCell extends StatelessWidget {
  const new({
    required this.day,
    required this.today,
    required this.weekday,
    required this.number,
    required this.numberStep,
    required this.circle,
    required this.weekdayStyle,
    required this.numberStyle,
  });

  final CalendarDate day;
  final bool today;
  final intl.DateFormat weekday;
  final intl.DateFormat number;
  final int numberStep;
  final double circle;
  final TextStyle weekdayStyle;
  final TextStyle numberStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = day.toDateTime();
    final showsNumber = today || numberStep == 1 || (day.day - 1).isEven;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        spacing: 2,
        children: [
          Text(
            weekday.format(date),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: weekdayStyle.copyWith(
              color: today ? colors.primary : null,
              fontWeight: today ? FontWeight.w700 : null,
            ),
          ),
          if (showsNumber)
            DecoratedBox(
              key: today ? const ValueKey('timeline-today') : null,
              decoration: today
                  ? BoxDecoration(color: colors.primary, shape: BoxShape.circle)
                  : const BoxDecoration(),
              child: SizedBox.square(
                dimension: circle,
                child: Center(
                  child: Text(
                    number.format(date),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: numberStyle.copyWith(
                      color: today ? colors.onPrimary : null,
                      fontWeight: today ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The header's bottom edge and a line before each new month.
class _HeaderLinesPainter extends CustomPainter {
  new({
    required this.days,
    required this.first,
    required this.end,
    required this.monthHeight,
    required this.color,
  });

  final TimelineDays days;
  final int first;
  final int end;
  final double monthHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      line,
    );
    for (var index = math.max(first, 1); index < end; index++) {
      if (days.dayAt(index).day != 1) continue;
      final x = days.xOf(index);
      canvas.drawLine(Offset(x, 4), Offset(x, monthHeight), line);
    }
  }

  @override
  bool shouldRepaint(_HeaderLinesPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.first != first ||
      oldDelegate.end != end ||
      oldDelegate.monthHeight != monthHeight ||
      oldDelegate.color != color;
}
