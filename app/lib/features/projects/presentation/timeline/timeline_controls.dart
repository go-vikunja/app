import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/time/today_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/day_range_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_today.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';

enum _RangeChoice { standard, custom, reset }

/// Above a Gantt view's timeline: its range, whether tasks without dates
/// show, zoom and a way back to today; in one row that scrolls sideways
/// when they do not fit. Each change is saved with the view's preferences
/// under [listKey].
class ProjectTimelineControls extends ConsumerWidget {
  const new({
    required this.viewId,
    required this.listKey,
    required this.preferences,
    super.key,
  });

  final int viewId;
  final String listKey;
  final ViewPreferences preferences;

  TimelinePreferences get _timeline => preferences.timeline;

  void _save(WidgetRef ref, TimelinePreferences timeline) => unawaited(
    ref
        .read(listPreferencesProvider)
        ?.saveView(listKey, preferences.copyWith(timeline: timeline)),
  );

  Future<void> _chooseRange(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final timeline = _timeline;
    final choice = await showOptionSheet<_RangeChoice>(
      context,
      title: l10n.projectTimelineRangeTitle,
      options: [
        SheetOption(
          value: _RangeChoice.standard,
          label: l10n.projectTimelineRangeDefault,
          selected: timeline.customRange == null,
        ),
        SheetOption(
          value: _RangeChoice.custom,
          label: l10n.projectTimelineRangeCustom,
          selected: timeline.customRange != null,
        ),
        // The zoom is not this sheet's to reset.
        if (timeline.customRange != null || timeline.withoutDates)
          SheetOption(
            value: _RangeChoice.reset,
            label: l10n.projectTimelineReset,
          ),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case _RangeChoice.standard:
        _save(ref, timeline.copyWith(defaultRange: true));
      case _RangeChoice.custom:
        await _chooseCustomRange(context, ref);
      case _RangeChoice.reset:
        _save(ref, timeline.copyWith(defaultRange: true, withoutDates: false));
      case null:
        break;
    }
  }

  Future<void> _chooseCustomRange(BuildContext context, WidgetRef ref) async {
    final today = ref.read(todayProvider);
    final shown = _timeline.range(today);
    final days = await pickDayRange(
      context,
      first: shown.from.toDateTime(),
      last: shown.to.toDateTime(),
      now: today,
      firstDayOfWeekIndex: ref
          .read(displaySettingsProvider)
          .firstDayOfWeekIndex,
    );
    if (days == null || !context.mounted) return;
    final (from, to) = days;
    _save(
      ref,
      _timeline.copyWith(
        customRange: GanttRange(
          from: CalendarDate.of(from),
          to: CalendarDate.of(to),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(todayProvider);
    final timeline = _timeline;
    final range = timeline.range(today);
    final dates = timelineRangeText(context, range, today: today);
    final width = TimelineDays.clampWidth(timeline.dayWidth);
    final wider = TimelineDays.zoomedIn(width);
    final narrower = TimelineDays.zoomedOut(width);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Scrolled, the chips run to the screen's edges.
      clipBehavior: Clip.none,
      child: Row(
        spacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.date_range),
            label: Text(dates),
            tooltip: l10n.projectTimelineRangeCurrent(dates),
            onPressed: () => unawaited(_chooseRange(context, ref)),
          ),
          FilterChip(
            label: Text(l10n.projectTimelineShowUndated),
            tooltip: l10n.upcomingShowWithoutDate,
            selected: timeline.withoutDates,
            onSelected: (selected) =>
                _save(ref, timeline.copyWith(withoutDates: selected)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: narrower == null
                    ? null
                    : () => _save(ref, timeline.copyWith(dayWidth: narrower)),
                tooltip: l10n.projectTimelineZoomOut,
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                onPressed: wider == null
                    ? null
                    : () => _save(ref, timeline.copyWith(dayWidth: wider)),
                tooltip: l10n.projectTimelineZoomIn,
                icon: const Icon(Icons.zoom_in),
              ),
              IconButton(
                onPressed: range.contains(CalendarDate.of(today))
                    ? () => ref
                          .read(timelineTodayRequestsProvider(viewId).notifier)
                          .request()
                    : null,
                tooltip: l10n.projectTimelineGoToToday,
                icon: const Icon(Icons.today),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The range's first and last day, with the year only when one of them is
/// not in [today]'s.
(String, String) timelineRangeDays(
  BuildContext context,
  GanttRange range, {
  required DateTime today,
}) {
  final material = MaterialLocalizations.of(context);
  final thisYear = range.from.year == today.year && range.to.year == today.year;
  String format(CalendarDate day) => thisYear
      ? material.formatShortMonthDay(day.toDateTime())
      : material.formatShortDate(day.toDateTime());
  return (format(range.from), format(range.to));
}

/// [timelineRangeDays] as one text.
String timelineRangeText(
  BuildContext context,
  GanttRange range, {
  required DateTime today,
}) {
  final (from, to) = timelineRangeDays(context, range, today: today);
  return range.from == range.to
      ? from
      : context.l10n.upcomingRangeDates(from, to);
}
