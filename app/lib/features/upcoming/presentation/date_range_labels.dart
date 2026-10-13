import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/features/upcoming/application/upcoming_sections.dart';

String presetLabel(AppLocalizations l10n, DateRangePreset preset) =>
    switch (preset) {
      DateRangePreset.today => l10n.rangeToday,
      DateRangePreset.tomorrow => l10n.rangeTomorrow,
      DateRangePreset.lastWeek => l10n.rangeLastWeek,
      DateRangePreset.thisWeek => l10n.rangeThisWeek,
      DateRangePreset.restOfThisWeek => l10n.rangeRestOfThisWeek,
      DateRangePreset.nextWeek => l10n.rangeNextWeek,
      DateRangePreset.next7Days => l10n.rangeNext7Days,
      DateRangePreset.lastMonth => l10n.rangeLastMonth,
      DateRangePreset.thisMonth => l10n.rangeThisMonth,
      DateRangePreset.restOfThisMonth => l10n.rangeRestOfThisMonth,
      DateRangePreset.nextMonth => l10n.rangeNextMonth,
      DateRangePreset.next30Days => l10n.rangeNext30Days,
      DateRangePreset.thisYear => l10n.rangeThisYear,
      DateRangePreset.restOfThisYear => l10n.rangeRestOfThisYear,
    };

/// The preset's name, or "Custom".
String rangeName(AppLocalizations l10n, UpcomingPreferences preferences) =>
    switch (preferences.preset) {
      final preset? => presetLabel(l10n, preset),
      null => l10n.upcomingRangeCustom,
    };

/// The range's first and last day, both included; with the year only when
/// one of them is not in [now]'s.
String rangeDates(BuildContext context, DateRange range, DateTime now) {
  final materialL10n = MaterialLocalizations.of(context);
  final (first, last) = daysOf(range);
  final thisYear = first.year == now.year && last.year == now.year;
  String format(DateTime day) => thisYear
      ? materialL10n.formatShortMonthDay(day)
      : materialL10n.formatShortDate(day);
  if (first == last) return format(first);
  return context.l10n.upcomingRangeDates(format(first), format(last));
}

/// "Today", "Tomorrow", or the weekday with the date.
String dayTitle(BuildContext context, DateTime day, DateTime now) {
  final l10n = context.l10n;
  final materialL10n = MaterialLocalizations.of(context);
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  if (day == today) return l10n.sectionToday;
  if (day == DateTime(today.year, today.month, today.day + 1)) {
    return l10n.sectionTomorrow;
  }
  return day.year == today.year
      ? materialL10n.formatMediumDate(day)
      : materialL10n.formatFullDate(day);
}
