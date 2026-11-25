import 'package:flutter/foundation.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_lines.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';

enum MagicSpanKind {
  label,
  project,
  unmatchedProject,
  priority,
  assignee,
  date,
  repeat,
}

/// A recognised part of the text, as character offsets.
@immutable
final class MagicSpan {
  const new(this.start, this.end, this.kind, {this.item});

  final int start;
  final int end;
  final MagicSpanKind kind;

  /// The label title, project or name a prefixed token stands for, as typed.
  final String? item;

  MagicSpan shifted(int offset) =>
      MagicSpan(start + offset, end + offset, kind, item: item);

  @override
  bool operator ==(Object other) =>
      other is MagicSpan &&
      other.start == start &&
      other.end == end &&
      other.kind == kind &&
      other.item == item;

  @override
  int get hashCode => Object.hash(start, end, kind, item);

  @override
  String toString() => 'MagicSpan($start, $end, ${kind.name}, $item)';
}

typedef MagicLine = ({int offset, String text});

/// The lines quick add turns into tasks, each as the text its task is
/// planned from and where that starts in [text], split and cut as
/// `quickAddTaskLines` does: a single line as typed; of several, each
/// without its indent and list marker, and none for a line that is only a
/// marker.
List<MagicLine> magicLines(String text) {
  final lines = <MagicLine>[];
  var start = 0;
  void add(int end) {
    final line = text.substring(start, end);
    if (line.trim().isNotEmpty) lines.add((offset: start, text: line));
  }

  for (final lineBreak in quickAddLineBreaks.allMatches(text)) {
    add(lineBreak.start);
    start = lineBreak.end;
  }
  add(text.length);
  if (lines.length < 2) return lines;
  return [
    for (final (:offset, :text) in lines)
      if (subtaskLineText(text) case final task when task.trim().isNotEmpty)
        (offset: offset + text.length - task.length, text: task),
  ];
}

/// Where [plan]'s recognised parts are in [line], the text it was planned
/// from: prefixed tokens where the parser reads them ([quickAddTokens]) by
/// their items, the date and repeat phrases where the parser's phrases
/// stand as words outside of them.
List<MagicSpan> magicSpansForLine(
  String line,
  QuickAddPlan plan,
  QuickAddPrefixes prefixes,
) {
  if (plan.magicOnly) return const [];
  final parsed = plan.parsed;
  final spans = <MagicSpan>[];

  bool same(String a, String b) => a.toLowerCase() == b.toLowerCase();

  final labels = parsed.labels;
  if (labels.isNotEmpty) {
    for (final token in quickAddTokens(line, prefixes.label)) {
      if (token.item.isNotEmpty && labels.any((l) => same(l, token.item))) {
        spans.add(
          MagicSpan(
            token.start,
            token.end,
            MagicSpanKind.label,
            item: token.item,
          ),
        );
      }
    }
  }
  if (parsed.project case final project?) {
    final kind = plan.unmatchedProject == null
        ? MagicSpanKind.project
        : MagicSpanKind.unmatchedProject;
    for (final token in quickAddTokens(line, prefixes.project)) {
      if (same(project, token.item)) {
        spans.add(MagicSpan(token.start, token.end, kind, item: token.item));
      }
    }
  }
  if (parsed.priority case final priority?) {
    // As the parser: the first whole number from 0 to 5 outside the labels
    // and the project, and every token of that number (`!03`, not `!3abc`).
    final tokens = [
      for (final token in quickAddTokens(line, prefixes.priority))
        if (!spans.any((s) => s.start < token.end && token.start < s.end))
          token,
    ];
    final item = tokens
        .map((token) => token.item)
        .where((item) => quickAddPriority(item) != null)
        .firstOrNull;
    if (item != null && quickAddPriority(item) == priority) {
      for (final token in tokens) {
        if (token.item == item) {
          spans.add(MagicSpan(token.start, token.end, MagicSpanKind.priority));
        }
      }
    }
  }
  final assignees = parsed.assignees;
  if (assignees.isNotEmpty) {
    for (final token in quickAddTokens(line, prefixes.assignee)) {
      if (token.item.isNotEmpty && assignees.any((a) => same(a, token.item))) {
        spans.add(
          MagicSpan(
            token.start,
            token.end,
            MagicSpanKind.assignee,
            item: token.item,
          ),
        );
      }
    }
  }
  spans.addAll(_phraseSpans(line, parsed, [...spans]));
  return spans..sort((a, b) => a.start.compareTo(b.start));
}

/// The spans of every line of [text]; [planFor] plans one line.
List<MagicSpan> magicSpansOf(
  String text,
  QuickAddPrefixes prefixes,
  QuickAddPlan? Function(String line) planFor,
) => [
  for (final line in magicLines(text))
    if (planFor(line.text) case final plan?)
      for (final span in magicSpansForLine(line.text, plan, prefixes))
        span.shifted(line.offset),
];

/// The repeat phrase where it first stands as words, by the parser's two
/// ends, the date phrases wherever they do (the parser removed every
/// occurrence), outside of [taken]; each ends where the parser ends it
/// (QA-4, QA-6, QA-14). Neighbours of a kind with only spaces between
/// them are one.
List<MagicSpan> _phraseSpans(
  String line,
  ParsedTaskText parsed,
  List<MagicSpan> taken,
) {
  final found = <MagicSpan>[];
  bool free(int start, int end) =>
      !taken.any((span) => span.start < end && start < span.end);
  bool mark(
    String phrase,
    MagicSpanKind kind,
    String end, {
    required bool everywhere,
  }) {
    if (phrase.isEmpty) return false;
    final pattern = RegExp(
      '(?<!\\S)${RegExp.escape(phrase)}$end',
      caseSensitive: false,
      unicode: true,
    );
    var marked = false;
    for (final match in pattern.allMatches(line)) {
      if (!free(match.start, match.end)) continue;
      final span = MagicSpan(match.start, match.end, kind);
      taken.add(span);
      found.add(span);
      marked = true;
      if (!everywhere) break;
    }
    return marked;
  }

  if ((parsed.repeats, parsed.repeatPhrase) case (_?, final phrase?)) {
    for (final end in [quickAddSpaceEnd, quickAddPunctuationEnd]) {
      if (mark(phrase, MagicSpanKind.repeat, end, everywhere: false)) break;
    }
  }
  if (parsed.date != null) {
    for (final phrase in parsed.datePhrases) {
      mark(
        phrase,
        MagicSpanKind.date,
        quickAddDatePhraseEnd(phrase),
        everywhere: true,
      );
    }
  }
  found.sort((a, b) => a.start.compareTo(b.start));
  final merged = <MagicSpan>[];
  for (final span in found) {
    final last = merged.lastOrNull;
    if (last != null &&
        last.kind == span.kind &&
        line.substring(last.end, span.start).trim().isEmpty) {
      merged.last = MagicSpan(last.start, span.end, span.kind);
    } else {
      merged.add(span);
    }
  }
  return merged;
}
