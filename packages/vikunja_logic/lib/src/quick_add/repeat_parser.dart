import 'package:vikunja_logic/src/quick_add/amounts.dart';
import 'package:vikunja_logic/src/quick_add/date_parser.dart';
import 'package:vikunja_logic/src/quick_add/parsed_task_text.dart';
import 'package:vikunja_logic/src/quick_add/phrase_ends.dart';

RegExp _repeatPhrase(String end) => RegExp(
  '(^| )'
  '((?:every|each) '
  '(?:([0-9]+|$amountWordsPattern) )?'
  '(hour|day|week|month|year)s?'
  '|annually|biannually|semiannually|biennially'
  '|daily|hourly|monthly|weekly|yearly)'
  '$end',
  caseSensitive: false,
);

final RegExp _repeatBeforeSpace = _repeatPhrase(quickAddSpaceEnd);

// QA-6: tried only where the web's rule finds no repeat, as for a weekday.
final RegExp _repeatBeforePunctuation = _repeatPhrase(quickAddPunctuationEnd);

const _keywords = <String, QuickAddRepeat>{
  'hourly': QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.hours),
  'daily': QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.days),
  'weekly': QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.weeks),
  'monthly': QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.months),
  'biannually': QuickAddRepeat(amount: 6, unit: QuickAddRepeatUnit.months),
  'semiannually': QuickAddRepeat(amount: 6, unit: QuickAddRepeatUnit.months),
  'yearly': QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.years),
  'annually': QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.years),
  'biennially': QuickAddRepeat(amount: 2, unit: QuickAddRepeatUnit.years),
};

const _units = <String, QuickAddRepeatUnit>{
  'hour': QuickAddRepeatUnit.hours,
  'day': QuickAddRepeatUnit.days,
  'week': QuickAddRepeatUnit.weeks,
  'month': QuickAddRepeatUnit.months,
  'year': QuickAddRepeatUnit.years,
};

/// The web's `getRepeats`: the first repeat phrase, removed from [text].
/// Keywords are matched in any case (QA-2: the web reads `Daily` and
/// `Every Day` as hourly).
({String text, QuickAddRepeat? repeat, String? phrase}) parseRepeat(
  String text,
) =>
    _repeatIn(text, _repeatBeforeSpace) ??
    _repeatIn(text, _repeatBeforePunctuation) ??
    (text: text, repeat: null, phrase: null);

({String text, QuickAddRepeat? repeat, String? phrase})? _repeatIn(
  String text,
  RegExp pattern,
) {
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  final phrase = match[2]!;
  final repeat = _keywords[phrase.toLowerCase()] ?? _everyPhrase(match);
  if (repeat == null) return null;
  final start = match.start + match[1]!.length;
  var end = start + phrase.length;
  if (text.substring(0, start).trim().isEmpty) {
    end = endAtLineStart(text, end);
  }
  return (
    text: text.replaceRange(match.start, end, ''),
    repeat: repeat,
    phrase: phrase,
  );
}

QuickAddRepeat? _everyPhrase(RegExpMatch match) {
  final amountText = match[3];
  final amount = amountText == null ? 1 : parseQuickAddAmount(amountText);
  if (amount == null) return null;
  return QuickAddRepeat(amount: amount, unit: _units[match[4]!.toLowerCase()]!);
}
