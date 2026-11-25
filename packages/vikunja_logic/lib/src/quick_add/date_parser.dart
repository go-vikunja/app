import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/quick_add/amounts.dart';
import 'package:vikunja_logic/src/quick_add/phrase_ends.dart';
import 'package:vikunja_logic/src/quick_add/quick_add_tokens.dart';
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

RegExp _keyword(String phrase) => RegExp(
  '(^| )($phrase)$quickAddWordEnd',
  caseSensitive: false,
  unicode: true,
);

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

RegExp _weekday(String before, String after) => RegExp(
  '$before((?:(next|this) )?(monday|mon|tuesday|tue|wednesday|wed|thursday'
  '|thu|friday|fri|saturday|sat|sunday|sun))$after',
  caseSensitive: false,
);

final RegExp _weekdayBeforeSpace = _weekday('(^| )', quickAddSpaceEnd);
final RegExp _weekdayBeforePunctuation = _weekday(
  '(^| )',
  quickAddPunctuationEnd,
);

// `next monday` is the keyword, which ends as a word.
final RegExp _weekdayPhraseOnly = _weekday(r'^(?!next monday$)', r'$');

final _timePhrase = RegExp('^(?:at|@) ', caseSensitive: false);

/// Where the parser ends the date phrase [phrase] when it removes it, as a
/// regular expression to append to one made with `unicode: true`: a time
/// as a time ([quickAddTimeEnd]), a weekday as one
/// ([quickAddSpaceOrPunctuationEnd]), anything else as a word
/// ([quickAddWordEnd]).
String quickAddDatePhraseEnd(String phrase) {
  if (_timePhrase.hasMatch(phrase)) return quickAddTimeEnd;
  if (_weekdayPhraseOnly.hasMatch(phrase)) {
    return quickAddSpaceOrPunctuationEnd;
  }
  return quickAddWordEnd;
}

final _ordinalDay = RegExp(
  r'(^| )(([1-2][0-9]|3[01]|0?[1-9])(?:st|nd|rd|th|\.))',
  caseSensitive: false,
);

// QA-5: the web also accepts a month word that only starts after the
// day, so `13th marathon` was a date.
final _afterOrdinal = RegExp(
  ' at | @ | (?:$_months)$quickAddWordEnd',
  caseSensitive: false,
  unicode: true,
);

// QA-10: the web takes a month word from anywhere in the text, so `Ask if
// we may move 5th` was 5 May; here only one right beside the ordinal.
// QA-4: not out of `may's`, which the removal leaves too.
final _monthAfter = RegExp(
  ' ($_months)$quickAddWordEnd',
  caseSensitive: false,
  unicode: true,
);
// Read behind the day, so that a long line is not copied for each day.
final _monthBefore = RegExp('(?<=(?:^| )($_months) )', caseSensitive: false);

// QA-6: the web needs a space or the end after the unit; here punctuation
// may follow (`in 2 days,`) but no apostrophe (`in a day's work`).
final _inAmount = RegExp(
  '(^| )(in ([0-9]+|an?|$amountWordsPattern) '
  '(minute|hour|day|week|month|year)s?)'
  "(?!$quickAddWordCharacter|['\u2019])",
  caseSensitive: false,
  unicode: true,
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
  // QA-13: a final dot, as German writes `17.12.` and `17.12.2026.`.
  RegExp(
    r'(^| )(?<date>(?<day>[0-9][0-9]?)\.(?<month>[0-9][0-9]?)'
    r'(?:\.(?<year>[0-9][0-9](?:[0-9][0-9])?))?\.?)($| )',
  ),
];

final RegExp _dottedDate = _absoluteDates.last;

// QA-13: a standalone German `am` before a dotted date goes with it,
// unless it is the time suffix of a number before it (`at 9 am 17.12.`).
final _amBefore = RegExp(r'(?<!\S)am $', caseSensitive: false);
final _numberBefore = RegExp(r'(?:^|\s)[0-9][0-9]?(?::[0-9][0-9])? $');

const _anyAbsoluteDate =
    '[0-9][0-9]?/[0-9][0-9]?(?:/[0-9][0-9](?:[0-9][0-9])?)?'
    '|[0-9]{3,4}/[0-9][0-9]?/[0-9][0-9]'
    '|[0-9]{3,4}-[0-9][0-9]?-[0-9][0-9]'
    r'|[0-9][0-9]?\.[0-9][0-9]?(?:\.(?:[0-9][0-9](?:[0-9][0-9])?\.?)?)?';

// Web parity: the web keeps a range such as `31.12.2026 - 01.01.2027` in
// the title and takes no date from it.
final _absoluteDateRange = RegExp(
  '(?<![0-9])(?:$_anyAbsoluteDate)'
  '(?: *[-\u2013] *(?:$_anyAbsoluteDate))+(?![0-9])',
);

final _timeAhead = RegExp(' (?:at|@) ', caseSensitive: false);

final _spaces = RegExp(r'\s*');

/// The assignee tokens of the text a date is read from, by where each
/// starts; read once, and only when a prefix stands where one is looked
/// for, as reading them for each day of a long line took seconds.
final class _Assignees {
  new(this._text, this._prefix);

  final String _text;
  final String _prefix;
  late final Map<int, int> _ends = {
    for (final token in quickAddTokens(_text, _prefix))
      if (token.item.isNotEmpty) token.start: token.end,
  };

  /// Where the assignee token that starts at [start] ends, if one does.
  int? endOf(int start) =>
      _text.startsWith(_prefix, start) ? _ends[start] : null;
}

/// [from] moved past the assignee tokens that follow it, each after one
/// space. QA-20: they stay in the text the date is read from, so a time or
/// month after them is beside the date, as after a removed label.
int _pastAssignees(String text, int from, _Assignees assignees) {
  var at = from;
  while (text.startsWith(' ', at)) {
    final end = assignees.endOf(at + 1);
    if (end == null) break;
    at = end;
  }
  return at;
}

/// Whether only whitespace and assignee tokens follow [from] in [text].
/// QA-20: labels, the project and the priority are removed before the date
/// is read and leave their spaces behind, and assignees stay in the text
/// until they are resolved; the web's boundary then drops `Pay rent 5th
/// *bills` and `Arzt 17.12. @anna`. Any other word after the date, also
/// the app's stand-in for an unmatched project (QA-15), still keeps it
/// text.
bool _endsText(String text, int from, _Assignees assignees) {
  var at = _spaces.matchAsPrefix(text, from)!.end;
  while (at < text.length) {
    final end = assignees.endOf(at);
    if (end == null) return false;
    at = _spaces.matchAsPrefix(text, end)!.end;
  }
  return true;
}

// QA-5: the web has no trailing boundary, so `12 decorations` was Dec 12.
final _monthDay = RegExp(
  '(^| )((?<month1>$_months) (?<day1>[0-9][0-9]?)'
  '|(?<day2>[0-9][0-9]?) (?<month2>$_months))$quickAddWordEnd',
  caseSensitive: false,
  unicode: true,
);

// QA-14: the web reads any one or two digits after `at` as a time, also
// out of a longer number (`at 221B`) and beyond the clock (`at 90`).
final _time = RegExp(
  r' (?:at|@) ([0-9][0-9]?)(?::([0-9][0-9]))?(?: ?([ap])m)?(?![\w:])',
  caseSensitive: false,
);

// QA-9: the web reads `Release 1.2` as 1 February; German section words
// keep `Kapitel 3.2` text too. Read behind the number, as `_monthBefore`.
final _versionWord = RegExp(
  r'(?<=(?:^|\s)(?:v|ver|version|release|rel|build|update|patch|rc|beta'
  r'|alpha|kapitel|abschnitt|seite|folie|teil|nr\.?) )',
  caseSensitive: false,
);

bool _afterVersionWord(String text, int start) =>
    _versionWord.matchAsPrefix(text, start) != null;

/// The web's `parseDate`: the first date phrase of [text] by its rule
/// order, then a time (`at 9:00`, `@ 3pm`) anywhere in what is left, each
/// removed from the text. A time alone is today at that time. A day
/// without a time takes [defaultTime] (`atDefaultTime`). Where the web's
/// rules find no date, a day number or a numeric date before the line's
/// end or the tokens of [assigneePrefix] is tried (QA-20), then a weekday
/// before punctuation (QA-6).
({String text, DateTime? date, List<String> phrases}) parseDate(
  String text,
  DateTime now, {
  required String assigneePrefix,
  ClockTime? defaultTime,
}) {
  final assignees = _Assignees(text, assigneePrefix);
  final found =
      _keywordDate(text, now, defaultTime) ??
      _weekdayDate(text, now, defaultTime, _weekdayBeforeSpace) ??
      _ordinalDate(text, now, defaultTime) ??
      _inAmountDate(text, now) ??
      _absoluteDate(text, now, defaultTime) ??
      _monthDayDate(text, now, defaultTime) ??
      // QA-20 and QA-6 come last, so that they never move a date the web
      // reads, as from `9/11 Prepare part 2. @anna` or `Dinner Fri, Dec
      // 17`; tokens after a day count before a weekday's punctuation, as
      // `Dentist Fri. 13th` keeps its day with `*health` after it.
      _ordinalDate(text, now, defaultTime, assignees: assignees) ??
      _absoluteDate(text, now, defaultTime, assignees: assignees) ??
      _weekdayDate(text, now, defaultTime, _weekdayBeforePunctuation);
  var rest = found?.text ?? text;
  var date = found?.date;
  final phrases = [...?found?.phrases];
  final time = _time.allMatches(rest).where(_isClockTime).firstOrNull;
  if (time != null) {
    final day = date ?? now;
    final tonight = found?.phrases.first.toLowerCase() == 'tonight';
    date = DateTime(
      day.year,
      day.month,
      day.day,
      _hour(time, evening: tonight),
      int.parse(time[2] ?? '0'),
    );
    phrases.add(time[0]!.trim());
    rest = _withoutPhrase(
      rest,
      RegExp(
        '( *)${RegExp.escape(time[0]!)}$quickAddTimeEnd',
        caseSensitive: false,
      ),
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

_FoundDate? _weekdayDate(
  String text,
  DateTime now,
  ClockTime? defaultTime,
  RegExp weekday,
) {
  final match = weekday.firstMatch(text);
  if (match == null) return null;
  final day = _weekdayAbbreviations.indexOf(
    match[4]!.substring(0, 3).toLowerCase(),
  );
  final days = (day - now.weekday % DateTime.daysPerWeek) % 7;
  final next = match[3]?.toLowerCase() == 'next';
  // QA-7: the web keeps the clock time of now.
  return _found(
    text,
    _inDays(now, next ? _nextWeekday(days) : days, defaultTime),
    match[2]!,
    end: quickAddSpaceOrPunctuationEnd,
  );
}

// QA-12: on the weekday itself, `next` means a week ahead, not today.
int _nextWeekday(int days) => days == 0 ? DateTime.daysPerWeek : days;

/// The first day number with a time, a month or the line's end after it;
/// with [assignees], that end may be whitespace and assignee tokens, and
/// assignees may stand before the time or month (QA-20).
_FoundDate? _ordinalDate(
  String text,
  DateTime now,
  ClockTime? defaultTime, {
  _Assignees? assignees,
}) {
  for (final match in _ordinalDay.allMatches(text)) {
    final end = match.end;
    final next = assignees == null ? end : _pastAssignees(text, end, assignees);
    if (_afterOrdinal.matchAsPrefix(text, next) == null &&
        !(assignees == null
            ? end == text.length
            : _endsText(text, end, assignees))) {
      continue;
    }
    final start = match.start + match[1]!.length;
    final month =
        _monthAfter.matchAsPrefix(text, next) ??
        _monthBefore.matchAsPrefix(text, start);
    // QA-9: `Lies Kapitel 3.` and `Release 2.` keep their number.
    if (month == null &&
        match[2]!.endsWith('.') &&
        _afterVersionWord(text, start)) {
      continue;
    }
    return _ordinalDateAt(text, match, month, now, defaultTime);
  }
  return null;
}

_FoundDate? _ordinalDateAt(
  String text,
  RegExpMatch match,
  Match? month,
  DateTime now,
  ClockTime? defaultTime,
) {
  final day = int.parse(match[3]!);
  DateTime date;
  if (month != null) {
    // QA-10, QA-11: a day the month does not have is no date (the web rolls
    // it into the next month), and a passed one is next year's.
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
  var rest = _removeWords(text, match[2]!, quickAddWordEnd);
  if (month != null) {
    phrases.add(month[1]!);
    rest = _withoutPhrase(
      rest,
      RegExp(
        '( *)(?<!$quickAddWordCharacter)${RegExp.escape(month[1]!)}'
        '$quickAddWordEnd',
        caseSensitive: false,
        unicode: true,
      ),
    );
  }
  // QA-7: the web keeps the clock time of now.
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
    // Not the fraction of the second: the server keeps whole seconds, and a
    // finer instant would read as moved once the server's copy is synced.
    now.second,
  );
  // Vikunja refuses the extended ISO form that a later year needs.
  if (date.year > 9999) return null;
  return _found(text, date, match[2]!);
}

/// The first numeric date at the line's start or with a time or the
/// line's end after it; with [assignees], that end may be whitespace and
/// assignee tokens, and assignees may stand before the time (QA-20).
_FoundDate? _absoluteDate(
  String text,
  DateTime now,
  ClockTime? defaultTime, {
  _Assignees? assignees,
}) {
  final ranges = _absoluteDateRange.allMatches(text).toList();
  int dateStart(RegExpMatch match) => match.start + match[1]!.length;
  int dateEnd(RegExpMatch match) =>
      dateStart(match) + match.namedGroup('date')!.length;
  bool inRange(RegExpMatch match) => ranges.any(
    (range) => range.start <= dateStart(match) && dateEnd(match) <= range.end,
  );
  bool ends(RegExpMatch match) {
    if (match.start == 0) return true;
    final end = dateEnd(match);
    if (assignees == null) {
      return match.end == text.length ||
          _timeAhead.matchAsPrefix(text, end) != null;
    }
    return _endsText(text, end, assignees) ||
        _timeAhead.matchAsPrefix(text, _pastAssignees(text, end, assignees)) !=
            null;
  }

  for (final pattern in _absoluteDates) {
    final match = pattern
        .allMatches(text)
        .where(
          (match) =>
              ends(match) &&
              !inRange(match) &&
              !(match.namedGroup('year') == null &&
                  _afterVersionWord(text, dateStart(match))),
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
      final phrase = match.namedGroup('date')!;
      return _found(
        text,
        atDefaultTime(date, now: now, defaultTime: defaultTime),
        identical(pattern, _dottedDate)
            ? '${_germanAm(text.substring(0, match.start + match[1]!.length))}'
                  '$phrase'
            : phrase,
      );
    }
  }
  return null;
}

/// The `am ` that ends [before] and goes with the dotted date after it, as
/// typed; empty when there is none or it ends a time (`9 am`).
String _germanAm(String before) {
  if (!_amBefore.hasMatch(before)) return '';
  final head = before.substring(0, before.length - 3);
  if (_numberBefore.hasMatch(head)) return '';
  return before.substring(before.length - 3);
}

_FoundDate? _monthDayDate(String text, DateTime now, ClockTime? defaultTime) {
  final match = _monthDay.firstMatch(text);
  if (match == null) return null;
  final month = _monthNumber(
    match.namedGroup('month1') ?? match.namedGroup('month2')!,
  );
  final day = int.parse(match.namedGroup('day1') ?? match.namedGroup('day2')!);
  // QA-6: the web drops such a phrase from the title without a date;
  // QA-11: nor is a day the month does not have one (`apr 31`).
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
  // QA-11: a day the month does not have is no date; JS rolls it into the
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

// QA-9, QA-11: from today on, so today's date is today (the web compares it
// at midnight with the clock time of now and moves it to next year), and a
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

// QA-7: `tonight at 8` is 20:00, where the web takes 08:00.
int _hour(RegExpMatch time, {required bool evening}) {
  final hour = int.parse(time[1]!);
  return switch (time[3]?.toLowerCase()) {
    'p' when hour != 12 => hour + 12,
    'a' when hour == 12 => 0,
    null when evening && hour >= 1 && hour <= 11 => hour + 12,
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

_FoundDate _found(
  String text,
  DateTime date,
  String phrase, {
  String end = quickAddWordEnd,
}) => (date: date, text: _removeWords(text, phrase, end), phrases: [phrase]);

// QA-6: the web removes every occurrence, also out of longer words:
// `fri frisbee` became `sbee`.
String _removeWords(String text, String phrase, String end) => _withoutPhrase(
  text,
  RegExp(
    '(^| +)${RegExp.escape(phrase)}$end',
    caseSensitive: false,
    unicode: true,
  ),
);

/// The characters before which a removed phrase takes its spaces along
/// (QA-19) and which may follow a prefixed item (QA-16).
const punctuationClass = '[.,;:!?\u2026)\\]}"\u201d\u00bb]';

final _punctuation = RegExp(punctuationClass);

final _nonSpace = RegExp(r'\S');

final _punctuationAtLineStart = RegExp('$punctuationClass+(?!\\S)\\s*');

/// [end], or past the punctuation and the whitespace after it, for a
/// phrase that starts the line and ends at [end]. QA-19: `Mon: standup`
/// is `standup`, where the web leaves `: standup`; a letter right after
/// the punctuation keeps it (`Today.com launch`).
int endAtLineStart(String text, int end) =>
    _punctuationAtLineStart.matchAsPrefix(text, end)?.end ?? end;

// QA-19: the spaces before a phrase (its first group) go with it when
// punctuation follows: `Call back.`, where the web leaves `Call back .`;
// at the line's start, that punctuation goes too.
String _withoutPhrase(String text, RegExp phrase) {
  final lineStart = _nonSpace.firstMatch(text)?.start ?? text.length;
  final result = StringBuffer();
  var at = 0;
  for (final match in phrase.allMatches(text)) {
    final phraseStart = match.start + match[1]!.length;
    var start = phraseStart;
    var end = match.end;
    if (_punctuation.matchAsPrefix(text, end) != null) {
      start = match.start;
      if (phraseStart <= lineStart) end = endAtLineStart(text, end);
    }
    if (start > at) result.write(text.substring(at, start));
    if (end > at) at = end;
  }
  result.write(text.substring(at));
  return result.toString();
}
