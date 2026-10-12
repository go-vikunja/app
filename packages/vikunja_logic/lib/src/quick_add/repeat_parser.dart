import 'package:vikunja_logic/src/quick_add/parsed_task_text.dart';

/// Larger amounts overflow `Duration` and `DateTime` arithmetic silently.
const maxQuickAddAmount = 100000;

final _repeatPhrase = RegExp(
  '(^| )'
  '((?:every|each) '
  '(?:([0-9]+|one|two|three|four|five|six|seven|eight|nine|ten) )?'
  '(hour|day|week|month|year)s?'
  '|annually|biannually|semiannually|biennially'
  '|daily|hourly|monthly|weekly|yearly)'
  r'(?:$| )',
  caseSensitive: false,
);

const _amountWords = [
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
];

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
/// Keywords are matched in any case (D19-2: the web reads `Daily` and
/// `Every Day` as hourly).
({String text, QuickAddRepeat? repeat, String? phrase}) parseRepeat(
  String text,
) {
  final match = _repeatPhrase.firstMatch(text);
  if (match == null) return (text: text, repeat: null, phrase: null);
  final phrase = match[2]!;
  final repeat = _keywords[phrase.toLowerCase()] ?? _everyPhrase(match);
  if (repeat == null) return (text: text, repeat: null, phrase: null);
  final end = match.start + match[1]!.length + phrase.length;
  return (
    text: text.replaceRange(match.start, end, ''),
    repeat: repeat,
    phrase: phrase,
  );
}

QuickAddRepeat? _everyPhrase(RegExpMatch match) {
  final amountText = match[3]?.toLowerCase();
  final amount = switch (amountText) {
    null => 1,
    _ when _amountWords.contains(amountText) =>
      _amountWords.indexOf(amountText) + 1,
    _ => int.tryParse(amountText),
  };
  if (amount == null || amount > maxQuickAddAmount) return null;
  return QuickAddRepeat(amount: amount, unit: _units[match[4]!.toLowerCase()]!);
}
