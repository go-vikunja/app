import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/quick_add/date_parser.dart';
import 'package:vikunja_logic/src/quick_add/parsed_task_text.dart';
import 'package:vikunja_logic/src/quick_add/quick_add_tokens.dart';
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
/// local wall-clock time; every relative date is computed from it. A day
/// without a time takes the user's `default_due_time` ([defaultTime]), else
/// the breakpoint for [now] (`atDefaultTime`).
///
/// Where it parts from the web on purpose (D38):
/// - Repeat keywords and units match in any case (`Daily`, `Every Day`).
/// - The date keywords (`today` to `next monday`) need whole words:
///   `todays` and `next weekend` stay text.
/// - `in 2 days` may be followed by punctuation (`in 2 days,`), where the
///   web wants a space or the end; an apostrophe keeps it text on both
///   (`in a day's work`).
/// - Day-and-month dates need whole words: `12 decorations`,
///   `13th marathon` and `sep 17th tasks` stay text, and so does a day that
///   no month has (`dec 45`), which the web drops from the title.
/// - A date phrase is removed only where it stands as words, never out of
///   a longer word (the web turns `fri frisbee` into `sbee`).
/// - Weekdays and ordinal days get the default time, not the clock time
///   of [now].
/// - Amounts above 100000 (`every 999999 years`) are text, and so is an
///   `in …` date after the year 9999 (`in 9000 years`).
/// - A date phrase removed before punctuation takes the spaces before it
///   along: `Call back tomorrow.` becomes `Call back.`, not `Call back .`.
ParsedTaskText parseTaskText(
  String text, {
  required DateTime now,
  QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
  ClockTime? defaultTime,
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
  final found = _priority(rest, prefixes.priority);
  final priority = found?.value;
  final priorities = [?found?.item];
  rest = cleanupItemText(rest, priorities, prefixes.priority);
  final assignees = _itemsFromPrefix(rest, prefixes.assignee);
  final repeat = parseRepeat(rest);
  final date = parseDate(repeat.text, now.toLocal(), defaultTime: defaultTime);

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

/// The project [parseTaskText] reads from [text], without the rest of the
/// parse.
String? parseQuickAddProject(
  String text, {
  QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
}) {
  final prefixes = quickAddPrefixes(mode);
  if (prefixes == null || _isQuoted(text)) return null;
  final labels = _itemsFromPrefix(text, prefixes.label);
  final rest = cleanupItemText(text, labels, prefixes.label);
  return _itemsFromPrefix(rest, prefixes.project).firstOrNull;
}

/// The web's `cleanupItemText`: removes `<prefix>item` (quoted or not, with
/// one trailing space) for each of [items], case-insensitively. D102-7:
/// only as a whole token, at the start or after a space and ending at a
/// space or the end; the web also cut `*bug` out of `*bugfix`. A quoted
/// item may also end before punctuation (`*"New York",`), as the parser
/// reads it there; an unquoted one only with [beforePunctuation], for
/// names read before a date was removed behind them (`@bob.` out of
/// `@bob tomorrow.`): read alone, `!3,` is no `!3`. Like
/// [_itemsFromPrefix], it takes one repeated prefix along (`**bike`).
String cleanupItemText(
  String text,
  Iterable<String> items,
  String prefix, {
  bool beforePunctuation = false,
}) {
  final escapedPrefix = RegExp.escape(prefix);
  var result = text;
  // Longest first, so that `*bug` is not cut out of `*bug.` before `bug.`
  // is removed.
  final sorted = items.where((item) => item.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final item in sorted) {
    final escapedItem = RegExp.escape(item);
    for (final (token, quoted) in [
      ("'$escapedItem'", true),
      ('"$escapedItem"', true),
      (escapedItem, false),
    ]) {
      final end = quoted || beforePunctuation
          ? '(?: |(?=$punctuationClass*(?!\\S)))'
          : r'(?: |(?!\S))';
      result = result.replaceAll(
        RegExp(
          '(?<!\\S)$escapedPrefix(?:$escapedPrefix)?$token$end',
          caseSensitive: false,
        ),
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

/// The web's `getItemsFromPrefix`: the non-empty items of
/// [quickAddTokens], duplicates collapsed.
List<String> _itemsFromPrefix(String text, String prefix) => {
  for (final token in quickAddTokens(text, prefix))
    if (token.item.isNotEmpty) token.item,
}.toList();

/// The first item that is a priority ([quickAddPriority]).
({int value, String item})? _priority(String text, String prefix) {
  for (final item in _itemsFromPrefix(text, prefix)) {
    if (quickAddPriority(item) case final value?) {
      return (value: value, item: item);
    }
  }
  return null;
}
