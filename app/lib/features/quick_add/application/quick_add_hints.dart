import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';

/// Why a line's due date may not be the one the user typed, for a hint
/// under the title field. The grammar stays the web's (D38); this only
/// points at what it does not read.
sealed class QuickAddDateHint {
  const new();
}

/// The line has a date word of another language and no date, as the date
/// words are English only.
final class ForeignDateWords extends QuickAddDateHint {
  const new();
}

/// A clock time follows the line's date without `at` or `@`, so it stays
/// in the title (D102-2). [time] is the time as typed.
final class TimeWithoutAt extends QuickAddDateHint {
  const new(this.time);

  final String time;
}

/// The hint for [plan]'s line, if any.
QuickAddDateHint? quickAddDateHint(QuickAddPlan plan) {
  if (plan.magicOnly) return null;
  final parsed = plan.parsed;
  final line = plan.input;
  if (parsed.date == null) {
    return _quoted(line.trim()) || !_foreignDateWord.hasMatch(line)
        ? null
        : const ForeignDateWords();
  }
  final phrases = parsed.datePhrases;
  if (phrases.any(_timePhrase.hasMatch)) return null;
  for (final phrase in phrases) {
    final match = RegExp(
      '(?<!\\S)${RegExp.escape(phrase)} +($_clock12|$_clock24)(?![\\w:])',
      caseSensitive: false,
    ).firstMatch(line);
    if (match != null) return TimeWithoutAt(match[1]!);
  }
  return null;
}

final _timePhrase = RegExp('^(?:at|@) ', caseSensitive: false);

// The forms the parser reads after `at` (D102-2), with minutes or am/pm,
// so that `tomorrow 3 apples` gives no hint.
const _clock12 = '(?:0?[1-9]|1[0-2])(?::[0-5][0-9])? ?[ap]m';
const _clock24 = '(?:[01]?[0-9]|2[0-3]):[0-5][0-9]';

// German, as the app's other language; short weekday names are left out,
// as `do` and `so` are English words.
final _foreignDateWord = RegExp(
  r'(?<![\p{L}\p{N}])(?:heute|übermorgen|morgen'
  '|(?:montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonnabend'
  '|sonntag)s?'
  '|wochenende|januar|februar|märz|mai|juni|juli|oktober|dezember'
  '|(?:nächste[nrs]?|kommende[nrs]?) (?:woche|monat|jahr)'
  '|in [0-9]+ (?:tag(?:en?)?|wochen?|monat(?:en?)?)'
  '|(?:um )?[0-9][0-9]?(?:[:.][0-9][0-9])? ?uhr'
  r'|um [0-9][0-9]?[:.][0-9][0-9])(?![\p{L}\p{N}])',
  caseSensitive: false,
  unicode: true,
);

bool _quoted(String text) =>
    text.length >= 2 &&
    (text.startsWith('"') || text.startsWith("'")) &&
    text.endsWith(text[0]);
