import 'package:flutter/foundation.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
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

/// The lines quick add turns into tasks: the non-blank ones, with where
/// each starts in [text].
List<MagicLine> magicLines(String text) {
  final lines = <MagicLine>[];
  var start = 0;
  while (start <= text.length) {
    var end = text.indexOf('\n', start);
    if (end < 0) end = text.length;
    final line = text.substring(start, end);
    if (line.trim().isNotEmpty) lines.add((offset: start, text: line));
    start = end + 1;
  }
  return lines;
}

/// A prefix followed by an item, quoted or up to the next space, where
/// Quick Add Magic looks for one: at the start or after a space.
typedef PrefixedToken = ({
  int start,
  int end,
  int itemStart,
  String item,
  bool quoted,
});

Iterable<PrefixedToken> prefixedTokens(String line, String prefix) sync* {
  var from = 0;
  while (from < line.length) {
    final at = line.indexOf(prefix, from);
    if (at < 0) return;
    from = at + prefix.length;
    if (at > 0 && line[at - 1] != ' ') continue;
    var itemStart = at + prefix.length;
    // The web drops one repeated prefix: `@@alice` is `alice`.
    if (line.startsWith(prefix, itemStart)) itemStart += prefix.length;
    final quote = itemStart < line.length ? line[itemStart] : '';
    if (quote == '"' || quote == "'") {
      final close = line.indexOf(quote, itemStart + 1);
      final end = close < 0 ? line.length : close + 1;
      yield (
        start: at,
        end: end,
        itemStart: itemStart + 1,
        item: line.substring(itemStart + 1, close < 0 ? line.length : close),
        quoted: true,
      );
      from = end;
    } else {
      var end = line.indexOf(' ', itemStart);
      if (end < 0) end = line.length;
      yield (
        start: at,
        end: end,
        itemStart: itemStart,
        item: line.substring(itemStart, end),
        quoted: false,
      );
    }
  }
}

/// Where [plan]'s recognised parts are in [line], the text it was planned
/// from: prefixed tokens by their items, the date and repeat phrases where
/// the parser's phrases stand as words outside of them.
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
    for (final token in prefixedTokens(line, prefixes.label)) {
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
    for (final token in prefixedTokens(line, prefixes.project)) {
      if (same(project, token.item)) {
        spans.add(MagicSpan(token.start, token.end, kind, item: token.item));
      }
    }
  }
  if (parsed.priority case final priority?) {
    for (final token in prefixedTokens(line, prefixes.priority)) {
      if (token.quoted) continue;
      final digits = RegExp(r'^\d+').stringMatch(token.item);
      if (digits == '$priority') {
        spans.add(
          MagicSpan(
            token.start,
            token.itemStart + digits!.length,
            MagicSpanKind.priority,
          ),
        );
      }
    }
  }
  final assignees = parsed.assignees;
  if (assignees.isNotEmpty) {
    for (final token in prefixedTokens(line, prefixes.assignee)) {
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

/// The repeat phrase where it first stands as words, the date phrases
/// wherever they do (the parser removed every occurrence), outside of
/// [taken]; neighbours of a kind with only spaces between them are one.
List<MagicSpan> _phraseSpans(
  String line,
  ParsedTaskText parsed,
  List<MagicSpan> taken,
) {
  final found = <MagicSpan>[];
  bool free(int start, int end) =>
      !taken.any((span) => span.start < end && start < span.end);
  void mark(String phrase, MagicSpanKind kind, {required bool everywhere}) {
    if (phrase.isEmpty) return;
    final pattern = RegExp(
      '(?<!\\S)${RegExp.escape(phrase)}(?!\\w)',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(line)) {
      if (!free(match.start, match.end)) continue;
      final span = MagicSpan(match.start, match.end, kind);
      taken.add(span);
      found.add(span);
      if (!everywhere) return;
    }
  }

  if ((parsed.repeats, parsed.repeatPhrase) case (_?, final phrase?)) {
    mark(phrase, MagicSpanKind.repeat, everywhere: false);
  }
  if (parsed.date != null) {
    for (final phrase in parsed.datePhrases) {
      mark(phrase, MagicSpanKind.date, everywhere: true);
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
