/// How long a new API token lives: the web's presets or a day picked.
/// There is no "never", as on the web.
enum ApiTokenExpiryChoice {
  days30(30),
  days60(60),
  days90(90),
  custom(null);

  new(this.days);

  final int? days;
}

/// When a token made at [now] with a preset of [days] expires.
DateTime presetExpiry(int days, DateTime now) => now.add(Duration(days: days));

/// A picked day is valid through its end in the device's time zone.
DateTime endOfDay(DateTime day) =>
    DateTime(day.year, day.month, day.day, 23, 59, 59);

/// The server takes a past expiry and makes a token that never works.
bool isCustomExpiryValid(DateTime day, DateTime now) =>
    endOfDay(day).isAfter(now);
