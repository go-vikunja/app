import 'dart:math' as math;

import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// The range's days side by side, each with its weekday, its number and a
/// dot for each of up to three open tasks; today tonal, the [selected] day
/// filled. A tap on a day picks it, another the whole range again.
class DayStrip extends StatefulWidget {
  const new({
    required this.days,
    required this.openCounts,
    required this.today,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Local midnights.
  final List<DateTime> days;
  final Map<DateTime, int> openCounts;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelected;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  final _scroll = ScrollController();
  final GlobalKey _startKey = GlobalKey();
  late final DateTime _start = widget.selected ?? widget.today;

  @override
  void initState() {
    super.initState();
    // A month's strip opens on today, or the picked day, not on the 1st.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final start = _startKey.currentContext?.findRenderObject();
      if (!mounted || start == null || !_scroll.hasClients) return;
      _scroll.position.ensureVisible(start, alignment: 0.5);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Up to 150 % text; beyond, a pill would be a tall column. Screen
    // readers get each day in full.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            for (final day in widget.days)
              _DayPill(
                key: day == _start ? _startKey : null,
                day: day,
                openCount: widget.openCounts[day] ?? 0,
                today: day == widget.today,
                past: day.isBefore(widget.today),
                selected: day == widget.selected,
                onTap: () =>
                    widget.onSelected(day == widget.selected ? null : day),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const new({
    required this.day,
    required this.openCount,
    required this.today,
    required this.past,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final DateTime day;
  final int openCount;
  final bool today;
  final bool past;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, number, weekday, dot) = switch (selected) {
      true => (
        colors.primary,
        colors.onPrimary,
        colors.onPrimary,
        colors.onPrimary,
      ),
      false when today => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        colors.onSecondaryContainer,
        colors.primary,
      ),
      false => (
        Colors.transparent,
        past ? colors.onSurfaceVariant : colors.onSurface,
        colors.onSurfaceVariant,
        past ? colors.error : colors.primary,
      ),
    };
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: l10n.upcomingDaySemantics(
        MaterialLocalizations.of(context).formatMediumDate(day),
        openCount,
      ),
      hint: selected ? l10n.upcomingShowRangeHint : l10n.upcomingShowDayHint,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(
                    intl.DateFormat.E(l10n.localeName).format(day),
                    style: theme.textTheme.labelSmall?.copyWith(color: weekday),
                  ),
                  Text(
                    intl.DateFormat.d(l10n.localeName).format(day),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: number,
                      fontSize: 18,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(
                    height: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        for (var i = 0; i < math.min(openCount, 3); i++)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 6),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
