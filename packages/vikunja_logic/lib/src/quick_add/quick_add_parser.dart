import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/quick_add/date_parser.dart';
import 'package:vikunja_logic/src/quick_add/parsed_task_text.dart';
import 'package:vikunja_logic/src/quick_add/repeat_parser.dart';

/// The prefix characters of a mode; null for [QuickAddMagicMode.disabled].
typedef QuickAddPrefixes = ({
  String label,
  String project,
  String priority,
  String assignee,
});

QuickAddPrefixes? quickAddPrefixes(QuickAddMagicMode mode) => switch (mode) {
  QuickAddMagicMode.disabled => null,
  QuickAddMagicMode.vikunja => (
    label: '*',
    project: '+',
    priority: '!',
    assignee: '@',
  ),
  QuickAddMagicMode.todoist => (
    label: '@',
    project: '#',
    priority: '!',
    assignee: '+',
  ),
};

/// The web's `parseTaskText`, with the deviations of D19 and D38. [now] is
/// local wall-clock time; every relative date is computed from it.
///
/// Where it parts from the web on purpose (D38):
/// - Repeat keywords and the unit of `in N days` match in any case
///   (`Daily`, `Every Day`, `In 2 Days`).
/// - The date keywords (`today` to `next monday`) and `in N days` need
///   whole words: `todays`, `next weekend` and `within 2 days` stay text.
/// - Day-and-month dates need whole words: `12 decorations`,
///   `13th marathon` and `sep 17th tasks` stay text, and so does a day that
///   no month has (`dec 45`), which the web drops from the title.
/// - A date phrase is removed only where it stands as words, never out of
///   a longer word (the web turns `fri frisbee` into `sbee`).
/// - Weekdays and ordinal days get the default time, not the clock time
///   of [now].
/// - Amounts above 100000 (`every 999999 years`) are text.
ParsedTaskText parseTaskText(
  String text, {
  required DateTime now,
  QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
}) {
  if (_isQuoted(text)) {
    return ParsedTaskText(text: text.substring(1, text.length - 1));
  }
  final prefixes = quickAddPrefixes(mode);
  if (prefixes == null) return ParsedTaskText(text: text);

  final labels = _itemsFromPrefix(text, prefixes.label);
  var rest = cleanupItemText(text, labels, prefixes.label);
  final project = _itemsFromPrefix(rest, prefixes.project).firstOrNull;
  final projects = [?project];
  rest = cleanupItemText(rest, projects, prefixes.project);
  final priority = _priority(rest, prefixes.priority);
  final priorities = [if (priority != null) '$priority'];
  rest = cleanupItemText(rest, priorities, prefixes.priority);
  final assignees = _itemsFromPrefix(rest, prefixes.assignee);
  final repeat = parseRepeat(rest);
  final date = parseDate(repeat.text, now.toLocal());

  rest = cleanupItemText(date.text, labels, prefixes.label);
  rest = cleanupItemText(rest, projects, prefixes.project);
  rest = cleanupItemText(rest, priorities, prefixes.priority);
  return ParsedTaskText(
    text: rest.trim(),
    date: date.date,
    labels: labels,
    project: project,
    priority: priority,
    assignees: assignees,
    repeats: repeat.repeat,
    datePhrases: date.phrases,
    repeatPhrase: repeat.phrase,
  );
}

/// The web's `cleanupItemText`: removes `<prefix>item` (quoted or not, with
/// one trailing space) for each of [items], case-insensitively.
String cleanupItemText(String text, Iterable<String> items, String prefix) {
  final escapedPrefix = RegExp.escape(prefix);
  var result = text;
  for (final item in items.where((item) => item.isNotEmpty)) {
    final escapedItem = RegExp.escape(item);
    for (final token in [
      "'$escapedItem' ",
      "'$escapedItem'",
      '"$escapedItem" ',
      '"$escapedItem"',
      '$escapedItem ',
      escapedItem,
    ]) {
      result = result.replaceAll(
        RegExp('$escapedPrefix$token', caseSensitive: false),
        '',
      );
    }
  }
  return result;
}

bool _isQuoted(String text) =>
    text.length >= 2 &&
    (text.startsWith('"') || text.startsWith("'")) &&
    text.endsWith(text[0]);

/// The web's `getItemsFromPrefix`: an item follows its prefix at the start
/// of the text or after a space and runs to the next space, or is quoted
/// with `'` or `"`. Duplicates collapse.
List<String> _itemsFromPrefix(String text, String prefix) {
  final parts = text.split(' $prefix');
  final items = <String>{};
  for (var part in text.startsWith(prefix) ? parts : parts.skip(1)) {
    if (part.startsWith(prefix)) part = part.substring(prefix.length);
    final item = part.startsWith("'")
        ? part.split("'")[1]
        : part.startsWith('"')
        ? part.split('"')[1]
        : part.split(' ').first;
    if (item.isNotEmpty) items.add(item);
  }
  return items.toList();
}

final _leadingInteger = RegExp(r'^\s*([+-]?)(?:0[xX]([0-9a-fA-F]*)|([0-9]+))');

/// The first item that JS `parseInt` reads as 0 to 5.
int? _priority(String text, String prefix) {
  for (final item in _itemsFromPrefix(text, prefix)) {
    final match = _leadingInteger.firstMatch(item);
    if (match == null) continue;
    final hex = match[2];
    // Without a radix, parseInt reads `0x…` as hex, and `0x` alone as NaN.
    final value = hex == null
        ? int.tryParse(match[3]!)
        : int.tryParse(hex, radix: 16);
    if (value != null && value <= 5 && (value == 0 || match[1] != '-')) {
      return value;
    }
  }
  return null;
}
