import 'package:vikunja_logic/src/quick_add/amounts.dart';
import 'package:vikunja_logic/src/time/day_interval.dart';
import 'package:vikunja_logic/src/time/default_time.dart';

typedef _FoundDate = ({DateTime date, String text, List<String> phrases});

const _months =
    'january|february|march|april|june|july|august|september|october'
    '|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec';

const _monthAbbreviations = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

const _weekdayAbbreviations = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

// D19-3: the web has no trailing boundary, so `todays` was today and
// `next weekend` next week.
RegExp _keyword(String phrase) =>
    RegExp('(^| )($phrase)\\b', caseSensitive: false);

final _keywordDates = <(RegExp, DateTime Function(DateTime now))>[
  (_keyword('today'), (now) => _inDays(now, 0)),
  (_keyword('tonight'), (now) => DateTime(now.year, now.month, now.day, 21)),
  (_keyword('tomorrow'), (now) => _inDays(now, 1)),
  (_keyword('next monday'), (now) => _after(DayInterval.nextMonday, now)),
  (_keyword('this weekend'), (now) => _after(DayInterval.thisWeekend, now)),
  (
    _keyword('later this week'),
    (now) => _after(DayInterval.laterThisWeek, now),
  ),
  (
    _keyword('later next week'),
    (now) => _after(DayInterval.laterNextWeek, now),
  ),
  (_keyword('next week'), (now) => _after(DayInterval.nextWeek, now)),
  (
    _keyword('next month'),
    (now) => atDefaultTime(DateTime(now.year, now.month + 1), now: now),
  ),
  (_keyword('end of month'), _endOfMonth),
];

final _weekday = RegExp(
  '(^| )((?:next )?(monday|mon|tuesday|tue|wednesday|wed|thursday|thu'
  r'|friday|fri|saturday|sat|sunday|sun))(?:$| )',
  caseSensitive: false,
);

// D19-4: the web also accepts a month word that only starts after the
// day, so `13th marathon` was a date.
final _ordinalDay = RegExp(
  r'(^| )(([1-2][0-9]|3[01]|0?[1-9])(?:st|nd|rd|th|\.))'
  '(?=\$| at | @ | (?:$_months)\\b)',
  caseSensitive: false,
);

final _monthWord = RegExp('\\b($_months)\\b', caseSensitive: false);

// D38-9: the web needs a space or the end after the unit; here punctuation
// may follow (`in 2 days,`) but no apostrophe (`in a day's work`).
final _inAmount = RegExp(
  '(^| )(in ([0-9]+|an?|$amountWordsPattern) '
  "(minute|hour|day|week|month|year)s?)(?![\\w'\u2019])",
  caseSensitive: false,
);

final _absoluteDates = [
  RegExp(
    '(^| )(?<date>(?<month>[0-9][0-9]?)/(?<day>[0-9][0-9]?)'
    r'(?:/(?<year>[0-9][0-9](?:[0-9][0-9])?))?)($| )',
  ),
  RegExp(
    '(^| )(?<date>(?<year>[0-9]{3,4})/(?<month>[0-9][0-9]?)'
    r'/(?<day>[0-9][0-9]))($| )',
  ),
  RegExp(
    '(^| )(?<date>(?<year>[0-9]{3,4})-(?<month>[0-9][0-9]?)'
    r'-(?<day>[0-9][0-9]))($| )',
  ),
  RegExp(
    r'(^| )(?<date>(?<day>[0-9][0-9]?)\.(?<month>[0-9][0-9]?)'
    r'(?:\.(?<year>[0-9][0-9](?:[0-9][0-9])?))?)($| )',
  ),
];

final _timeAhead = RegExp('(?:at|@) ', caseSensitive: false);

// D19-4: the web has no trailing boundary, so `12 decorations` was Dec 12.
final _monthDay = RegExp(
  '(^| )((?<month1>$_months) (?<day1>[0-9][0-9]?)'
  '|(?<day2>[0-9][0-9]?) (?<month2>$_months))\\b',
  caseSensitive: false,
);

final _time = RegExp(
  ' (?:at|@) ([0-9][0-9]?)(?::([0-9][0-9]))?(?: ?([ap])m)?',
  caseSensitive: false,
);

/// The web's `parseDate`: the first date phrase of [text] by its rule
/// order, then a time (`at 9:00`, `@ 3pm`) anywhere in what is left, each
/// removed from the text. A time alone is today at that time.
({String text, DateTime? date, List<String> phrases}) parseDate(
  String text,
  DateTime now,
) {
  final found =
      _keywordDate(text, now) ??
      _weekdayDate(text, now) ??
      _ordinalDate(text, now) ??
      _inAmountDate(text, now) ??
      _absoluteDate(text, now) ??
      _monthDayDate(text, now);
  var rest = found?.text ?? text;
  var date = found?.date;
  final phrases = [...?found?.phrases];
  final time = _time.firstMatch(rest);
  if (time != null) {
    final day = date ?? now;
    date = DateTime(
      day.year,
      day.month,
      day.day,
      _hour(time),
      int.parse(time[2] ?? '0'),
    );
    phrases.add(time[0]!.trim());
    rest = rest.replaceAll(
      RegExp(RegExp.escape(time[0]!), caseSensitive: false),
      '',
    );
  }
  return (text: rest, date: date, phrases: phrases);
}

_FoundDate? _keywordDate(String text, DateTime now) {
  for (final (pattern, dateFor) in _keywordDates) {
    final match = pattern.firstMatch(text);
    if (match != null) return _found(text, dateFor(now), match[2]!);
  }
  return null;
}

_FoundDate? _weekdayDate(String text, DateTime now) {
  final match = _weekday.firstMatch(text);
  if (match == null) return null;
  final weekday = _weekdayAbbreviations.indexOf(
    match[3]!.substring(0, 3).toLowerCase(),
  );
  final days = (weekday - now.weekday % DateTime.daysPerWeek) % 7;
  // D38-5: the web keeps the clock time of now.
  return _found(text, _inDays(now, days), match[2]!);
}

_FoundDate? _ordinalDate(String text, DateTime now) {
  final match = _ordinalDay.firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match[3]!);
  var date = DateTime(now.year, now.month, day);
  if (date.isBefore(DateTime(now.year, now.month, now.day))) {
    date = DateTime(date.year, date.month + 1, date.day);
  }
  if (date.day != day) date = DateTime(date.year, date.month, day);
  final phrases = [match[2]!];
  var rest = _removeWords(text, match[2]!);
  final month = _monthWord.firstMatch(rest);
  if (month != null) {
    // May lie in the past and overflows like JS `setMonth` (web parity).
    date = DateTime(date.year, _monthNumber(month[1]!), date.day);
    phrases.add(month[1]!);
    rest = rest.replaceAll(
      RegExp('\\b${RegExp.escape(month[1]!)}\\b', caseSensitive: false),
      '',
    );
  }
  // D38-5: the web keeps the clock time of now.
  return (date: atDefaultTime(date, now: now), text: rest, phrases: phrases);
}

_FoundDate? _inAmountDate(String text, DateTime now) {
  final match = _inAmount.firstMatch(text);
  if (match == null) return null;
  final amount = switch (match[3]!.toLowerCase()) {
    'a' || 'an' => 1,
    final amountText => parseQuickAddAmount(amountText),
  };
  if (amount == null) return null;
  final unit = match[4]!.toLowerCase();
  final date = DateTime(
    now.year + (unit == 'year' ? amount : 0),
    now.month + (unit == 'month' ? amount : 0),
    now.day +
        switch (unit) {
          'day' => amount,
          'week' => 7 * amount,
          _ => 0,
        },
    now.hour + (unit == 'hour' ? amount : 0),
    now.minute + (unit == 'minute' ? amount : 0),
    now.second,
    now.millisecond,
    now.microsecond,
  );
  // Vikunja refuses the extended ISO form that a later year needs.
  if (date.year > 9999) return null;
  return _found(text, date, match[2]!);
}

_FoundDate? _absoluteDate(String text, DateTime now) {
  for (final pattern in _absoluteDates) {
    final match = pattern
        .allMatches(text)
        .where(
          (match) =>
              match.start == 0 ||
              match.end == text.length ||
              _timeAhead.matchAsPrefix(text, match.end) != null,
        )
        .firstOrNull;
    if (match == null) continue;
    final year = match.namedGroup('year');
    final date = _calendarDate(
      month: int.parse(match.namedGroup('month')!),
      day: int.parse(match.namedGroup('day')!),
      year: year == null ? null : int.parse(year),
      now: now,
    );
    if (date != null) return _found(text, date, match.namedGroup('date')!);
  }
  return null;
}

_FoundDate? _monthDayDate(String text, DateTime now) {
  final match = _monthDay.firstMatch(text);
  if (match == null) return null;
  final month = _monthNumber(
    match.namedGroup('month1') ?? match.namedGroup('month2')!,
  );
  final day = int.parse(match.namedGroup('day1') ?? match.namedGroup('day2')!);
  // D38-9: the web drops such a phrase from the title without a date.
  if (day < 1 || day > 31) return null;
  return _found(
    text,
    _nextOccurrence(DateTime(now.year, month, day), now),
    match[2]!,
  );
}

/// What JS `new Date('M/D/Y')` makes of the numbers, falling back to D/M/Y
/// like the web; without a year the next such date from [now].
DateTime? _calendarDate({
  required int month,
  required int day,
  required int? year,
  required DateTime now,
}) {
  final monthDay = _isCalendarDay(month, day)
      ? (month, day)
      : _isCalendarDay(day, month)
      ? (day, month)
      : null;
  if (monthDay == null) return null;
  final (m, d) = monthDay;
  if (year == null) return _nextOccurrence(DateTime(now.year, m, d), now);
  // V8 reads 0–49 as 20xx and 50–99 as 19xx.
  final fullYear = year < 50
      ? 2000 + year
      : year < 100
      ? 1900 + year
      : year;
  return DateTime(fullYear, m, d);
}

// JS accepts any day up to 31 and lets it overflow into the next month.
bool _isCalendarDay(int month, int day) =>
    month >= 1 && month <= 12 && day >= 1 && day <= 31;

// At midnight, so today's date is already in the past (web parity).
DateTime _nextOccurrence(DateTime date, DateTime now) =>
    date.isBefore(now) ? DateTime(date.year + 1, date.month, date.day) : date;

int _hour(RegExpMatch time) {
  final hour = int.parse(time[1]!);
  return switch (time[3]?.toLowerCase()) {
    'p' when hour != 12 => hour + 12,
    'a' when hour == 12 => 0,
    _ => hour,
  };
}

int _monthNumber(String name) =>
    _monthAbbreviations.indexOf(name.substring(0, 3).toLowerCase()) + 1;

// The web takes the default time of the last day's midnight, so 09:00.
DateTime _endOfMonth(DateTime now) {
  final lastDay = DateTime(now.year, now.month + 1, 0);
  return atDefaultTime(lastDay, now: lastDay);
}

DateTime _inDays(DateTime now, int days) =>
    atDefaultTime(DateTime(now.year, now.month, now.day + days), now: now);

DateTime _after(DayInterval interval, DateTime now) =>
    _inDays(now, calculateDayInterval(interval, now));

_FoundDate _found(String text, DateTime date, String phrase) =>
    (date: date, text: _removeWords(text, phrase), phrases: [phrase]);

// D38-9: the web removes every occurrence, also out of longer words:
// `fri frisbee` became `sbee`.
String _removeWords(String text, String phrase) => text.replaceAllMapped(
  RegExp('(^| )${RegExp.escape(phrase)}(?!\\w)', caseSensitive: false),
  (match) => match[1]!,
);
