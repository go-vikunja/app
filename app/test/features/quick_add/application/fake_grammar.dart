import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_grammar.dart';

QuickAddPrefixes? fakePrefixes(QuickAddMagicMode mode) => switch (mode) {
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
  QuickAddMagicMode.disabled => null,
};

/// A stand-in for the parser, so the service is tested on its own: words
/// split at single spaces; `<label>x` and the first `<project>x` are taken
/// out, as is the first `!0`..`!5`; `<assignee>x` stays; `tomorrow`
/// (tomorrow at 9:00), `today at 15:00`, `every week` and `every 2 months`
/// are the only date and repeat phrases. No quotes.
ParsedTaskText fakeParse(
  String text, {
  required DateTime now,
  required QuickAddMagicMode mode,
}) {
  final prefixes = fakePrefixes(mode);
  if (prefixes == null) return ParsedTaskText(text: text);
  var rest = text;
  DateTime? date;
  QuickAddRepeat? repeat;
  String take(String rest, String phrase, void Function() found) {
    final pattern = RegExp('(^| )$phrase(\$| )');
    if (!pattern.hasMatch(rest)) return rest;
    found();
    return rest.replaceFirst(pattern, ' ');
  }

  rest = take(rest, 'every week', () {
    repeat = const QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.weeks);
  });
  rest = take(rest, 'every 2 months', () {
    repeat = const QuickAddRepeat(amount: 2, unit: QuickAddRepeatUnit.months);
  });
  rest = take(rest, 'tomorrow', () {
    date = DateTime(now.year, now.month, now.day + 1, 9);
  });
  rest = take(rest, 'today at 15:00', () {
    date = DateTime(now.year, now.month, now.day, 15);
  });

  final labels = <String>[];
  final assignees = <String>[];
  String? project;
  int? priority;
  final words = <String>[];
  for (final word in rest.split(' ').where((word) => word.isNotEmpty)) {
    final item = word.length > 1 ? word.substring(1) : '';
    if (word.startsWith(prefixes.label) && item.isNotEmpty) {
      if (!labels.contains(item)) labels.add(item);
    } else if (word.startsWith(prefixes.project) &&
        item.isNotEmpty &&
        project == null) {
      project = item;
    } else if (int.tryParse(item) case final level?
        when word.startsWith(prefixes.priority) &&
            priority == null &&
            level >= 0 &&
            level <= 5) {
      priority = level;
    } else {
      if (word.startsWith(prefixes.assignee) &&
          item.isNotEmpty &&
          !assignees.contains(item)) {
        assignees.add(item);
      }
      words.add(word);
    }
  }
  return ParsedTaskText(
    text: words.join(' '),
    date: date,
    labels: labels,
    project: project,
    priority: priority,
    assignees: assignees,
    repeats: repeat,
  );
}

String fakeCleanup(String text, Iterable<String> items, String prefix) {
  final remove = {for (final item in items) '$prefix$item'.toLowerCase()};
  return text
      .split(' ')
      .where((word) => !remove.contains(word.toLowerCase()))
      .join(' ');
}

({Duration repeatAfter, RepeatMode mode}) fakeRepeatOf(QuickAddRepeat repeat) =>
    switch (repeat.unit) {
      QuickAddRepeatUnit.months when repeat.amount == 1 => (
        repeatAfter: Duration.zero,
        mode: RepeatMode.monthly,
      ),
      QuickAddRepeatUnit.months => (
        repeatAfter: Duration(days: 30 * repeat.amount),
        mode: RepeatMode.afterAmount,
      ),
      QuickAddRepeatUnit.weeks => (
        repeatAfter: Duration(days: 7 * repeat.amount),
        mode: RepeatMode.afterAmount,
      ),
      QuickAddRepeatUnit.days => (
        repeatAfter: Duration(days: repeat.amount),
        mode: RepeatMode.afterAmount,
      ),
      QuickAddRepeatUnit.hours => (
        repeatAfter: Duration(hours: repeat.amount),
        mode: RepeatMode.afterAmount,
      ),
      QuickAddRepeatUnit.years => (
        repeatAfter: Duration(days: 365 * repeat.amount),
        mode: RepeatMode.afterAmount,
      ),
    };

const fakeGrammar = QuickAddGrammar(
  parse: fakeParse,
  cleanup: fakeCleanup,
  prefixes: fakePrefixes,
  repeatOf: fakeRepeatOf,
);
