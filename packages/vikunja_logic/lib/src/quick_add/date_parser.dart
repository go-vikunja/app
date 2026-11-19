import 'package:vikunja_domain/vikunja_domain.dart';
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
// `next weekend` next week; D102-1: an apostrophe followed by a letter
// does not end the word either, so `today's` stays text, also where a
// `today` elsewhere is removed.
const _wordEnd = "(?!\\w|['\u2019]\\w)";

RegExp _keyword(String phrase) =>
    RegExp('(^| )($phrase)$_wordEnd', caseSensitive: false);

typedef _DateFor = DateTime Function(DateTime now, ClockTime? defaultTime);

final _keywordDates = <(RegExp, _DateFor)>[
  (_keyword('today'), (now, time) => _inDays(now, 0, time)),
  (
    _keyword('tonight'),
    (now, _) =>
        notPassedToday(DateTime(now.year, now.month, now.day, 21), now: now),
  ),
  (_keyword('tomorrow'), (now, time) => _inDays(now, 1, time)),
  (
    _keyword('next monday'),
    (now, time) => _inDays(
      now,
      _nextWeekday(calculateDayInterval(DayInterval.nextMonday, now)),
      time,
    ),
  ),
  (
    _keyword('this weekend'),
    (now, time) => _after(DayInterval.thisWeekend, now, time),
  ),
  (
    _keyword('later this week'),
    (now, time) => _after(DayInterval.laterThisWeek, now, time),
  ),
  (
    _keyword('later next week'),
    (now, time) => _after(DayInterval.laterNextWeek, now, time),
  ),
  (
    _keyword('next week'),
    (now, time) => _after(DayInterval.nextWeek, now, time),
  ),
  (
    _keyword('next month'),
    (now, time) => atDefaultTime(
      DateTime(now.year, now.month + 1),
      now: now,
      defaultTime: time,
    ),
  ),
  (_keyword('end of month'), _endOfMonth),
];

final _weekday = RegExp(
  '(^| )((?:(next|this) )?(monday|mon|tuesday|tue|wednesday|wed|thursday|thu'
  r'|friday|fri|saturday|sat|sunday|sun))(?:$| )',
  caseSensitive: false,
);

// D19-4: the web also accepts a month word that only starts after the
// day, so `13th marathon` was a date.
final _ordinalDay = RegExp(
  r'(^| )(([1-2][0-9]|3[01]|0?[1-9])(?:st|nd|rd|th|\.))'
  '(?=\$| at | @ | (?:$_months)$_wordEnd)',
  caseSensitive: false,
);

// D102-3: the web takes a month word from anywhere in the text, so `Ask if
// we may move 5th` was 5 May; here only one right beside the ordinal.
// D102-1: not out of `may's`, which the removal leaves too.
final _monthAfter = RegExp(' ($_months)$_wordEnd', caseSensitive: false);
final _monthBefore = RegExp('(?:^| )($_months) \$', caseSensitive: false);

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

const _anyAbsoluteDate =
    '[0-9][0-9]?/[0-9][0-9]?(?:/[0-9][0-9](?:[0-9][0-9])?)?'
    '|[0-9]{3,4}/[0-9][0-9]?/[0-9][0-9]'
    '|[0-9]{3,4}-[0-9][0-9]?-[0-9][0-9]'
    r'|[0-9][0-9]?\.[0-9][0-9]?(?:\.(?:[0-9][0-9](?:[0-9][0-9])?)?)?';

// Web parity: the web keeps a range such as `31.12.2026 - 01.01.2027` in
// the title and takes no date from it.
final _absoluteDateRange = RegExp(
  '(?<![0-9])(?:$_anyAbsoluteDate)'
  '(?: *[-\u2013] *(?:$_anyAbsoluteDate))+(?![0-9])',
);

final _timeAhead = RegExp('(?:at|@) ', caseSensitive: false);

// D19-4: the web has no trailing boundary, so `12 decorations` was Dec 12.
final _monthDay = RegExp(
  '(^| )((?<month1>$_months) (?<day1>[0-9][0-9]?)'
  '|(?<day2>[0-9][0-9]?) (?<month2>$_months))$_wordEnd',
  caseSensitive: false,
);

// D102-2: the web reads any one or two digits after `at` as a time, also
// out of a longer number (`at 221B`) and beyond the clock (`at 90`).
final _time = RegExp(
  r' (?:at|@) ([0-9][0-9]?)(?::([0-9][0-9]))?(?: ?([ap])m)?(?![\w:])',
  caseSensitive: false,
);

// D102-2: a time is removed only where `_time` reads the same phrase, not
// out of `at 221B`, `at 22:5` or, for `at 9`, `at 9 pm`.
const _timeEnd = r'(?![\w:]| ?[ap]m(?![\w:]))';

// D102-5: the web reads `Release 1.2` as 1 February.
final _versionWord = RegExp(
  r'(?:^|\s)(?:v|ver|version|release|rel|build|update|patch|rc|beta|alpha) $',
  caseSensitive: false,
);

/// The web's `parseDate`: the first date phrase of [text] by its rule
/// order, then a time (`at 9:00`, `@ 3pm`) anywhere in what is left, each
/// removed from the text. A time alone is today at that time. A day
/// without a time takes [defaultTime] (`atDefaultTime`).
({String text, DateTime? date, List<String> phrases}) parseDate(
  String text,
  DateTime now, {
  ClockTime? defaultTime,
}) {
  final found =
      _keywordDate(text, now, defaultTime) ??
      _weekdayDate(text, now, defaultTime) ??
      _ordinalDate(text, now, defaultTime) ??
      _inAmountDate(text, now) ??
      _absoluteDate(text, now, defaultTime) ??
      _monthDayDate(text, now, defaultTime);
  var rest = found?.text ?? text;
  var date = found?.date;
  final phrases = [...?found?.phrases];
  final time = _time.allMatches(rest).where(_isClockTime).firstOrNull;
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
    rest = _withoutPhrase(
      rest,
      RegExp('( *)${RegExp.escape(time[0]!)}$_timeEnd', caseSensitive: false),
    );
  }
  return (text: rest, date: date, phrases: phrases);
}

_FoundDate? _keywordDate(String text, DateTime now, ClockTime? defaultTime) {
  for (final (pattern, dateFor) in _keywordDates) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      return _found(text, dateFor(now, defaultTime), match[2]!);
    }
  }
  return null;
}

_FoundDate? _weekdayDate(String text, DateTime now, ClockTime? defaultTime) {
  final match = _weekday.firstMatch(text);
  if (match == null) return null;
  final weekday = _weekdayAbbreviations.indexOf(
    match[4]!.substring(0, 3).toLowerCase(),
  );
  final days = (weekday - now.weekday % DateTime.daysPerWeek) % 7;
  final next = match[3]?.toLowerCase() == 'next';
  // D38-5: the web keeps the clock time of now.
  return _found(
    text,
    _inDays(now, next ? _nextWeekday(days) : days, defaultTime),
    match[2]!,
  );
}

// D102-4: on the weekday itself, `next` means a week ahead, not today.
int _nextWeekday(int days) => days == 0 ? DateTime.daysPerWeek : days;

_FoundDate? _ordinalDate(String text, DateTime now, ClockTime? defaultTime) {
  final match = _ordinalDay.firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match[3]!);
  final end = match.end;
  final start = match.start + match[1]!.length;
  final month =
      _monthAfter.matchAsPrefix(text, end) ??
      _monthBefore.firstMatch(text.substring(0, start));
  DateTime date;
  if (month != null) {
    // D102-3: a day the month does not have is no date (the web rolls it
    // into the next month), and a passed one is next year's.
    final next = _nextRealDate(_monthNumber(month[1]!), day, now);
    if (next == null) return null;
    date = next;
  } else {
    date = DateTime(now.year, now.month, day);
    if (date.isBefore(DateTime(now.year, now.month, now.day))) {
      date = DateTime(date.year, date.month + 1, date.day);
    }
    if (date.day != day) date = DateTime(date.year, date.month, day);
  }
  final phrases = [match[2]!];
  var rest = _removeWords(text, match[2]!);
  if (month != null) {
    phrases.add(month[1]!);
    rest = _withoutPhrase(
      rest,
      RegExp(
        '( *)\\b${RegExp.escape(month[1]!)}$_wordEnd',
        caseSensitive: false,
      ),
    );
  }
  // D38-5: the web keeps the clock time of now.
  return (
    date: atDefaultTime(date, now: now, defaultTime: defaultTime),
    text: rest,
    phrases: phrases,
  );
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

_FoundDate? _absoluteDate(String text, DateTime now, ClockTime? defaultTime) {
  final ranges = _absoluteDateRange.allMatches(text).toList();
  bool inRange(RegExpMatch match) {
    final start = match.start + match[1]!.length;
    final end = start + match.namedGroup('date')!.length;
    return ranges.any((range) => range.start <= start && end <= range.end);
  }

  for (final pattern in _absoluteDates) {
    final match = pattern
        .allMatches(text)
        .where(
          (match) =>
              (match.start == 0 ||
                  match.end == text.length ||
                  _timeAhead.matchAsPrefix(text, match.end) != null) &&
              !inRange(match) &&
              !(match.namedGroup('year') == null &&
                  _versionWord.hasMatch(text.substring(0, match.start + 1))),
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
    if (date != null) {
      return _found(
        text,
        atDefaultTime(date, now: now, defaultTime: defaultTime),
        match.namedGroup('date')!,
      );
    }
  }
  return null;
}

_FoundDate? _monthDayDate(String text, DateTime now, ClockTime? defaultTime) {
  final match = _monthDay.firstMatch(text);
  if (match == null) return null;
  final month = _monthNumber(
    match.namedGroup('month1') ?? match.namedGroup('month2')!,
  );
  final day = int.parse(match.namedGroup('day1') ?? match.namedGroup('day2')!);
  // D38-9: the web drops such a phrase from the title without a date;
  // D102-6: nor is a day the month does not have one (`apr 31`).
  final date = _nextRealDate(month, day, now);
  if (date == null) return null;
  return _found(
    text,
    atDefaultTime(date, now: now, defaultTime: defaultTime),
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
  // V8 reads 0–49 as 20xx and 50–99 as 19xx.
  final fullYear = switch (year) {
    null => null,
    final year when year < 50 => 2000 + year,
    final year when year < 100 => 1900 + year,
    final year => year,
  };
  // D102-6: a day the month does not have is no date; JS rolls it into the
  // next month.
  DateTime? dateOf(int m, int d) => switch (fullYear) {
    final year? => _isRealDay(year, m, d) ? DateTime(year, m, d) : null,
    null => _nextRealDate(m, d, now),
  };
  return dateOf(month, day) ?? dateOf(day, month);
}

bool _isRealDay(int year, int month, int day) =>
    month >= 1 &&
    month <= 12 &&
    day >= 1 &&
    DateTime(year, month, day).day == day;

// D102-5: from today on, so today's date is today (the web compares it at
// midnight with the clock time of now and moves it to next year), and a
// 29 February waits for a leap year.
DateTime? _nextRealDate(int month, int day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  for (var year = now.year; year <= now.year + 4; year++) {
    if (!_isRealDay(year, month, day)) continue;
    final date = DateTime(year, month, day);
    if (!date.isBefore(today)) return date;
  }
  return null;
}

bool _isClockTime(RegExpMatch time) {
  final hour = int.parse(time[1]!);
  final minute = int.parse(time[2] ?? '0');
  final meridiem = time[3] != null;
  return minute <= 59 && (meridiem ? hour >= 1 && hour <= 12 : hour <= 23);
}

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

// Without a default time the web takes the breakpoint of the last day's
// midnight, so 09:00.
DateTime _endOfMonth(DateTime now, ClockTime? defaultTime) {
  final lastDay = DateTime(now.year, now.month + 1, 0);
  return notPassedToday(
    atDefaultTime(lastDay, now: lastDay, defaultTime: defaultTime),
    now: now,
  );
}

DateTime _inDays(DateTime now, int days, ClockTime? defaultTime) =>
    atDefaultTime(
      DateTime(now.year, now.month, now.day + days),
      now: now,
      defaultTime: defaultTime,
    );

DateTime _after(DayInterval interval, DateTime now, ClockTime? defaultTime) =>
    _inDays(now, calculateDayInterval(interval, now), defaultTime);

_FoundDate _found(String text, DateTime date, String phrase) =>
    (date: date, text: _removeWords(text, phrase), phrases: [phrase]);

// D38-9: the web removes every occurrence, also out of longer words:
// `fri frisbee` became `sbee`.
String _removeWords(String text, String phrase) => _withoutPhrase(
  text,
  RegExp('(^| +)${RegExp.escape(phrase)}$_wordEnd', caseSensitive: false),
);

/// The characters before which a removed phrase takes its spaces along
/// (D38-11) and which may follow a prefixed item (D102-7).
const punctuationClass = '[.,;:!?\u2026)\\]}"\u201d\u00bb]';

final _punctuation = RegExp(punctuationClass);

// D38-11: the spaces before a phrase (its first group) go with it when
// punctuation follows: `Call back.`, where the web leaves `Call back .`.
String _withoutPhrase(String text, RegExp phrase) => text.replaceAllMapped(
  phrase,
  (match) =>
      _punctuation.matchAsPrefix(text, match.end) == null ? match[1]! : '',
);
