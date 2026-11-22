/// A prefix and its item where the parser reads one, as offsets into the
/// text: `start` at the prefix, `itemStart` after the prefix (and a
/// repeated one) and an opening quote, `end` after a closing quote.
typedef QuickAddToken = ({
  int start,
  int end,
  int itemStart,
  String item,
  bool quoted,
});

/// Every prefixed item of [text] as the web's `getItemsFromPrefix` reads
/// them: the text is split at each ` <prefix>`, and its start counts too
/// when it begins with [prefix]. One repeated [prefix] is dropped (`**bike`
/// is `bike`), except at the start of the text, where the web keeps it
/// (`**bike` there is `*bike`). An item quoted with `'` or `"` runs to the
/// same quote, or without one to the next ` <prefix>`; any other item to
/// the next space. Empty items are included.
List<QuickAddToken> quickAddTokens(String text, String prefix) {
  final tokens = <QuickAddToken>[];
  void read(int start, int from, int partEnd) {
    var at = from;
    if (at + prefix.length <= partEnd && text.startsWith(prefix, at)) {
      at += prefix.length;
    }
    final quote = at < partEnd ? text[at] : '';
    if (quote == '"' || quote == "'") {
      final close = text.indexOf(quote, at + 1);
      final closed = close >= 0 && close < partEnd;
      tokens.add((
        start: start,
        end: closed ? close + 1 : partEnd,
        itemStart: at + 1,
        item: text.substring(at + 1, closed ? close : partEnd),
        quoted: true,
      ));
    } else {
      final space = text.indexOf(' ', at);
      final end = space < 0 || space > partEnd ? partEnd : space;
      tokens.add((
        start: start,
        end: end,
        itemStart: at,
        item: text.substring(at, end),
        quoted: false,
      ));
    }
  }

  final separator = ' $prefix';
  // At the start the prefix itself is the one dropped, so a repeated one
  // stays in the item.
  var tokenStart = text.startsWith(prefix) ? 0 : null;
  var partStart = 0;
  while (true) {
    final next = text.indexOf(separator, partStart);
    final partEnd = next < 0 ? text.length : next;
    if (tokenStart != null) read(tokenStart, partStart, partEnd);
    if (next < 0) return tokens;
    tokenStart = next + 1;
    partStart = next + separator.length;
  }
}

/// [item] as typed after a prefix: quoted when it holds whitespace, with
/// `'` when it holds a `"`.
String quoteQuickAddItem(String item) {
  if (!item.contains(RegExp(r'\s'))) return item;
  return item.contains('"') ? "'$item'" : '"$item"';
}

final _wholeNumber = RegExp(r'^[0-9]+$');

/// The priority a priority item stands for: a whole number from 0 to 5.
/// QA-17: the web reads it with JS `parseInt`, so `!2fa` was priority 2
/// while the title kept `!2fa`.
int? quickAddPriority(String item) {
  if (!_wholeNumber.hasMatch(item)) return null;
  final value = int.tryParse(item);
  return value != null && value <= 5 ? value : null;
}
