import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';

/// The sizes of a row: the bar grows with the text, so a title stays
/// readable at 200 %.
final class TimelineRowMetrics {
  factory of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = titleStyleOf(context);
    final lineHeight =
        scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.3);
    final barHeight = math.max<double>(32, (lineHeight + 8).ceilToDouble());
    return TimelineRowMetrics._(
      barHeight: barHeight,
      rowHeight: math.max<double>(48, barHeight + 12),
    );
  }

  const new _({required this.barHeight, required this.rowHeight});

  final double barHeight;
  final double rowHeight;

  static const chevronWidth = 48.0;
  static const labelGap = 8.0;

  static TextStyle titleStyleOf(BuildContext context) =>
      (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
        height: 1.3,
      );
}

/// A row: the bar over its days with the title inside when it fits, else
/// beside it; a parent's chevron left of its bar; behind it the faint
/// bands of the groups it is in. A title inside its bar and a parent's
/// chevron move along as [horizontal] scrolls the bar's start off screen,
/// so a task in progress shows them. One screen reader node with the title,
/// the dates and the collapse action. Read-only: a tap opens the task.
class TimelineRow extends StatelessWidget {
  const new({
    required this.row,
    required this.days,
    required this.horizontal,
    required this.viewportWidth,
    required this.metrics,
    required this.semanticsLabel,
    required this.groupSpans,
    required this.onTap,
    this.collapsed = false,
    this.onToggleCollapsed,
    super.key,
  });

  final GanttRow row;
  final TimelineDays days;
  final ScrollController horizontal;

  /// The chart's width: what [horizontal] shows before its first layout.
  final double viewportWidth;
  final TimelineRowMetrics metrics;
  final String semanticsLabel;

  /// The groups it is in, a parent with its subtasks below it, as
  /// `(start, end)` column indexes, the outermost first.
  final List<(int, int)> groupSpans;
  final VoidCallback onTap;
  final bool collapsed;

  /// Null for a row without subtasks.
  final VoidCallback? onToggleCollapsed;

  static const _bandOverhang = 12.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final task = row.task;
    final bar = row.bar;
    final width = days.width;
    final fullLeft = days.xOf(bar.column);
    final fullRight = days.xOf(bar.endColumn);
    final fullWidth = fullRight - fullLeft;
    final barLeft = math.max<double>(fullLeft, 0);
    final barRight = math.min<double>(fullRight, width);
    final barWidth = math.max<double>(barRight - barLeft, 0);
    final look = _BarLook.of(row, colors);
    final style = TimelineRowMetrics.titleStyleOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final painter = TextPainter(
      text: TextSpan(text: task.title, style: style),
      textScaler: textScaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final titleWidth = painter.width;
    painter.dispose();

    final toggle = onToggleCollapsed;
    const chevronWidth = TimelineRowMetrics.chevronWidth;
    final chevronLeft = toggle == null
        ? barLeft
        : math.max<double>(barLeft - chevronWidth, 0);
    // A partial bar's title stays on its opaque part.
    final (opaqueStart, opaqueEnd) = switch (bar.kind) {
      GanttBarKind.startOnly => (
        fullLeft,
        fullLeft + _BarPainter.fadeOutFrom * fullWidth,
      ),
      GanttBarKind.endOnly => (
        fullLeft + _BarPainter.fadeInUntil * fullWidth,
        fullRight,
      ),
      GanttBarKind.scheduled || GanttBarKind.estimated => (fullLeft, fullRight),
    };
    // A parent's end markers stay clear of its title.
    final markerRoom = row.isParent ? _BarPainter.markerRoom : 0.0;
    final insideStart = math.max<double>(
      math.max<double>(
        barLeft + (bar.column < 0 ? 0 : markerRoom),
        opaqueStart,
      ),
      toggle == null ? 0.0 : chevronLeft + chevronWidth,
    );
    final insideEnd = math.min<double>(
      barRight - (bar.endColumn > days.count ? 0 : markerRoom),
      opaqueEnd,
    );
    const gap = TimelineRowMetrics.labelGap;
    final fitsInside = insideStart + gap + titleWidth + gap <= insideEnd;
    final fitsAfter = barRight + gap + titleWidth + gap <= width;
    final (labelLeft, labelWidth, inside) = switch ((fitsInside, fitsAfter)) {
      (true, _) => (insideStart + gap, insideEnd - insideStart - 2 * gap, true),
      (false, true) => (barRight + gap, titleWidth + gap, false),
      // At the end of the range: before the bar, as far as there is room.
      _ => (
        math.max<double>(chevronLeft - gap - titleWidth, 0),
        math.min<double>(titleWidth, math.max<double>(chevronLeft - gap, 0)),
        false,
      ),
    };
    final groupLeft = math.min<double>(chevronLeft, labelLeft);
    final groupRight = math.max<double>(
      math.max<double>(barRight, labelLeft + labelWidth),
      groupLeft + kMinInteractiveDimension,
    );
    final barTop = (metrics.rowHeight - metrics.barHeight) / 2;
    final titleColor = inside
        ? look.onBar
        : task.done
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final title = Text(
      task.title,
      maxLines: 1,
      softWrap: false,
      overflow: inside ? TextOverflow.ellipsis : TextOverflow.clip,
      style: style.copyWith(
        color: titleColor,
        decoration: task.done ? TextDecoration.lineThrough : null,
        decorationColor: titleColor,
      ),
    );

    Widget following(Widget Function(double viewLeft) build) =>
        ListenableBuilder(
          listenable: horizontal,
          builder: (context, _) =>
              build(visibleWindow(horizontal, fallbackWidth: viewportWidth).$1),
        );

    // Null where the chevron stays left of the bar.
    double? pinnedChevron(double viewLeft) =>
        barLeft - chevronWidth < viewLeft && viewLeft < barRight - chevronWidth
        ? viewLeft
        : null;

    Widget label(double left, double width) => Positioned(
      left: left - groupLeft,
      width: math.max<double>(width, 0),
      top: barTop,
      height: metrics.barHeight,
      child: Align(
        // On the opaque end of a bar that fades in.
        alignment: inside && bar.kind == GanttBarKind.endOnly
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: title,
      ),
    );

    Widget followingLabel(double viewLeft) {
      final pinned = toggle == null ? null : pinnedChevron(viewLeft);
      final start = math.max<double>(
        insideStart,
        pinned == null ? viewLeft : pinned + chevronWidth,
      );
      final left = start + gap + titleWidth + gap <= insideEnd
          ? start + gap
          : math.max<double>(insideEnd - gap - titleWidth, insideStart + gap);
      return label(left, insideEnd - gap - left);
    }

    Widget chevron(double left) => Positioned(
      left: left - groupLeft,
      width: chevronWidth,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton(
          onPressed: toggle,
          tooltip: collapsed
              ? l10n.projectTimelineExpand(task.title)
              : l10n.projectTimelineCollapse(task.title),
          style: IconButton.styleFrom(
            // Over the bar, on a background of its own.
            backgroundColor: left + chevronWidth > barLeft
                ? colors.surfaceContainerHigh
                : null,
            minimumSize: const Size.square(kMinInteractiveDimension),
          ),
          icon: Icon(
            collapsed ? Icons.chevron_right : Icons.expand_more,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );

    return SizedBox(
      width: width,
      height: metrics.rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (groupSpans.isNotEmpty)
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _BandsPainter(
                    spans: [
                      for (final (start, end) in groupSpans)
                        (
                          math.max<double>(days.xOf(start) - _bandOverhang, 0),
                          math.min<double>(
                            days.xOf(end) + _bandOverhang,
                            width,
                          ),
                        ),
                    ],
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          Positioned(
            left: groupLeft,
            width: groupRight - groupLeft,
            top: 0,
            bottom: 0,
            child: Semantics(
              container: true,
              button: true,
              label: semanticsLabel,
              expanded: toggle == null ? null : !collapsed,
              onTap: onTap,
              customSemanticsActions: toggle == null
                  ? null
                  : {
                      CustomSemanticsAction(
                        label: collapsed
                            ? l10n.projectTimelineExpand(task.title)
                            : l10n.projectTimelineCollapse(task.title),
                      ): toggle,
                    },
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                // Read-only: a long press is not a tap that opens the task.
                onLongPress: () {},
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: barLeft - groupLeft,
                      width: barWidth,
                      top: barTop,
                      height: metrics.barHeight,
                      child: CustomPaint(
                        painter: _BarPainter(
                          look: look,
                          kind: bar.kind,
                          parent: row.isParent,
                          clippedStart: bar.column < 0,
                          clippedEnd: bar.endColumn > days.count,
                          fullOffset: fullLeft - barLeft,
                          fullWidth: fullWidth,
                        ),
                      ),
                    ),
                    if (inside && bar.kind != GanttBarKind.endOnly)
                      following(followingLabel)
                    else if (labelWidth > 0)
                      label(labelLeft, labelWidth),
                    if (toggle != null)
                      following(
                        (viewLeft) =>
                            chevron(pinnedChevron(viewLeft) ?? chevronLeft),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bar's colours: the task's own, else the scheme's primary container;
/// an estimated bar neutral. A done task's are mixed with the surface
/// rather than drawn translucent, so that its title's colour is chosen
/// against the colour on screen.
@immutable
final class _BarLook {
  const new({
    required this.fill,
    required this.onBar,
    required this.border,
    required this.dashed,
  });

  factory of(GanttRow row, ColorScheme colors) {
    Color muted(Color color) => row.task.done
        ? Color.alphaBlend(color.withValues(alpha: 0.5), colors.surface)
        : color;
    if (row.bar.kind == GanttBarKind.estimated) {
      return _BarLook(
        fill: muted(colors.surfaceContainerHighest),
        onBar: colors.onSurfaceVariant,
        border: colors.outline,
        dashed: true,
      );
    }
    final own = parseHexColor(row.task.hexColor);
    final fill = muted(own ?? colors.primaryContainer);
    final onBar = own == null
        ? colors.onPrimaryContainer
        : contrastingTextColor(fill);
    return _BarLook(
      fill: fill,
      onBar: onBar,
      border: row.bar.derived ? onBar.withValues(alpha: 0.7) : null,
      dashed: row.bar.derived,
    );
  }

  final Color fill;
  final Color onBar;
  final Color? border;
  final bool dashed;
}

/// Paints the part of a bar inside the range; a partial bar's fade runs
/// over the whole bar, [fullWidth] wide from [fullOffset] (zero or less).
class _BarPainter extends CustomPainter {
  new({
    required this.look,
    required this.kind,
    required this.parent,
    required this.clippedStart,
    required this.clippedEnd,
    required this.fullOffset,
    required this.fullWidth,
  });

  final _BarLook look;
  final GanttBarKind kind;
  final bool parent;
  final bool clippedStart;
  final bool clippedEnd;
  final double fullOffset;
  final double fullWidth;

  static const _radius = Radius.circular(6);

  /// From a bar's end to the far side of its marker.
  static const markerRoom = 10.0;

  /// Where a bar without an end starts to fade, of its width.
  static const fadeOutFrom = 0.6;

  /// Where a bar without a start is opaque from, of its width.
  static const fadeInUntil = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final rect = (Offset.zero & size).deflate(1);
    final full = Rect.fromLTWH(
      fullOffset,
      0,
      fullWidth,
      size.height,
    ).deflate(1);
    final shape = RRect.fromRectAndCorners(
      rect,
      topLeft: clippedStart ? Radius.zero : _radius,
      bottomLeft: clippedStart ? Radius.zero : _radius,
      topRight: clippedEnd ? Radius.zero : _radius,
      bottomRight: clippedEnd ? Radius.zero : _radius,
    );
    final fill = Paint();
    final transparent = look.fill.withValues(alpha: 0);
    switch (kind) {
      case GanttBarKind.startOnly:
        fill.shader = LinearGradient(
          colors: [look.fill, look.fill, transparent],
          stops: const [0, fadeOutFrom, 1],
        ).createShader(full);
      case GanttBarKind.endOnly:
        fill.shader = LinearGradient(
          colors: [transparent, look.fill, look.fill],
          stops: const [0, fadeInUntil, 1],
        ).createShader(full);
      case GanttBarKind.scheduled || GanttBarKind.estimated:
        fill.color = look.fill;
    }
    canvas.drawRRect(shape, fill);
    if (look.border case final border?) {
      final stroke = Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = kind == GanttBarKind.estimated ? 1.5 : 1;
      if (look.dashed) {
        _dashed(canvas, Path()..addRRect(shape), stroke);
      } else {
        canvas.drawRRect(shape, stroke);
      }
    }
    if (parent) {
      final marker = Paint()..color = look.onBar;
      final centreY = size.height / 2;
      for (final x in [
        if (!clippedStart) rect.left + 6,
        if (!clippedEnd) rect.right - 6,
      ]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, centreY - 4)
            ..lineTo(x + 4, centreY)
            ..lineTo(x, centreY + 4)
            ..lineTo(x - 4, centreY)
            ..close(),
          marker,
        );
      }
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dash = 5.0;
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
            math.min<double>(distance + dash, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.look.fill != look.fill ||
      oldDelegate.look.onBar != look.onBar ||
      oldDelegate.look.border != look.border ||
      oldDelegate.look.dashed != look.dashed ||
      oldDelegate.kind != kind ||
      oldDelegate.parent != parent ||
      oldDelegate.clippedStart != clippedStart ||
      oldDelegate.clippedEnd != clippedEnd ||
      oldDelegate.fullOffset != fullOffset ||
      oldDelegate.fullWidth != fullWidth;
}

class _BandsPainter extends CustomPainter {
  new({required this.spans, required this.color});

  final List<(double, double)> spans;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final band = Paint()..color = color.withValues(alpha: 0.06);
    for (final (left, right) in spans) {
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), band);
    }
  }

  @override
  bool shouldRepaint(_BandsPainter oldDelegate) =>
      oldDelegate.color != color || !_sameSpans(oldDelegate.spans, spans);

  static bool _sameSpans(List<(double, double)> a, List<(double, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
