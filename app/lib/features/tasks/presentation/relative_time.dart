import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// "in 3 days" / "2 days ago", with the web's (dayjs) rounding thresholds
/// below a day. From a day on the count follows the local calendar, like the
/// overview's sections, so a task due tonight never reads "in 1 day" and one
/// due within the next seven days never "in 8 days".
String formatRelativeTime(
  AppLocalizations l10n,
  DateTime moment, {
  required DateTime now,
}) {
  final difference = moment.difference(now);
  final future = !difference.isNegative;
  final seconds = difference.abs().inSeconds;
  if (seconds < 45) return l10n.relativeNow;
  final minutes = (seconds / 60).round();
  if (minutes < 45) {
    return future
        ? l10n.relativeInMinutes(minutes)
        : l10n.relativeMinutesAgo(minutes);
  }
  final hours = (seconds / 3600).round();
  final days = _calendarDaysBetween(now, moment).abs();
  if (hours < 22 || days == 0) {
    return future ? l10n.relativeInHours(hours) : l10n.relativeHoursAgo(hours);
  }
  if (days < 26) {
    return future ? l10n.relativeInDays(days) : l10n.relativeDaysAgo(days);
  }
  final months = (days / 30).round();
  if (months < 11) {
    return future
        ? l10n.relativeInMonths(months)
        : l10n.relativeMonthsAgo(months);
  }
  final years = (days / 365).round();
  return future ? l10n.relativeInYears(years) : l10n.relativeYearsAgo(years);
}

int _calendarDaysBetween(DateTime from, DateTime to) =>
    _localDate(to).difference(_localDate(from)).inDays;

// A UTC date, so that a daylight-saving change does not shorten a day.
DateTime _localDate(DateTime moment) {
  final local = moment.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}
