/// Larger amounts overflow `Duration` and `DateTime` arithmetic silently.
const maxQuickAddAmount = 100000;

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
  'eleven',
  'twelve',
];

/// The number words as regular expression alternatives.
final String amountWordsPattern = _amountWords.join('|');

/// Digits or a number word in any case; null above [maxQuickAddAmount].
int? parseQuickAddAmount(String text) {
  final word = _amountWords.indexOf(text.toLowerCase());
  final amount = word >= 0 ? word + 1 : int.tryParse(text);
  return amount == null || amount > maxQuickAddAmount ? null : amount;
}
