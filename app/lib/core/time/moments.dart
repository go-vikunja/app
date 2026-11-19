/// Whether [a] and [b] fall in the same second, as the server stores
/// times; two nulls are the same.
bool sameSecond(DateTime? a, DateTime? b) => switch ((a, b)) {
  (null, null) => true,
  (final a?, final b?) =>
    a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000,
  _ => false,
};

/// The calendar days from [from] to [to] in the device's time zone, counted
/// on UTC dates so that a daylight-saving change in between does not
/// shorten a day.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
