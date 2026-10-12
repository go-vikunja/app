import 'package:flutter/services.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';

enum MagicTokenKind { label, project, assignee }

/// The prefixed token the caret is in, which suggestions complete.
typedef ActiveMagicToken = ({
  MagicTokenKind kind,
  String prefix,
  int start,
  int end,
  String query,
});

ActiveMagicToken? activeMagicToken(
  TextEditingValue value,
  QuickAddPrefixes prefixes,
) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final text = value.text;
  final caret = selection.baseOffset;
  if (caret > text.length) return null;
  final lineStart = caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
  var lineEnd = text.indexOf('\n', caret);
  if (lineEnd < 0) lineEnd = text.length;
  final line = text.substring(lineStart, lineEnd);
  final column = caret - lineStart;
  for (final (kind, prefix) in [
    (MagicTokenKind.label, prefixes.label),
    (MagicTokenKind.project, prefixes.project),
    (MagicTokenKind.assignee, prefixes.assignee),
  ]) {
    for (final token in prefixedTokens(line, prefix)) {
      if (column < token.itemStart || column > token.end) continue;
      final open = token.quoted && !_closed(line, token);
      // An open quote runs to the end of the line; only the part up to the
      // caret is being typed.
      final end = open ? column : token.end;
      final query = open ? line.substring(token.itemStart, column) : token.item;
      return (
        kind: kind,
        prefix: prefix,
        start: lineStart + token.start,
        end: lineStart + end,
        query: query,
      );
    }
  }
  return null;
}

bool _closed(String line, PrefixedToken token) =>
    token.end <= line.length &&
    token.end > token.itemStart &&
    line[token.end - 1] == line[token.itemStart - 1];

/// [value] as an item: quoted when it contains a space.
String quoteMagicValue(String value) {
  if (!value.contains(RegExp(r'\s'))) return value;
  return value.contains('"') ? "'$value'" : '"$value"';
}

/// Replaces [token] with its prefix and [item], followed by a space, and
/// puts the caret after it.
TextEditingValue completeMagicToken(
  TextEditingValue value,
  ActiveMagicToken token,
  String item,
) {
  final text = value.text;
  final replacement = '${token.prefix}${quoteMagicValue(item)}';
  final spaced = text.startsWith(' ', token.end)
      ? replacement
      : '$replacement ';
  return TextEditingValue(
    text: text.replaceRange(token.start, token.end, spaced),
    selection: TextSelection.collapsed(
      offset: token.start + replacement.length + 1,
    ),
  );
}

/// Inserts [insert] in place of the selection (at the end without one),
/// as a token of its own: with a space before it unless the caret follows
/// one, and a space after it when text follows directly. The caret goes
/// right after [insert], or with [trailingSpace] after the space following
/// it.
TextEditingValue insertMagicText(
  TextEditingValue value,
  String insert, {
  bool trailingSpace = false,
}) {
  final text = value.text;
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: text.length);
  final before = text.substring(0, selection.start);
  final after = text.substring(selection.end);
  final leading = before.isNotEmpty && !_endsWithSpace(before) ? ' ' : '';
  final glued = after.isNotEmpty && !_startsWithSpace(after);
  final trailing = glued || (trailingSpace && !after.startsWith(' '))
      ? ' '
      : '';
  return TextEditingValue(
    text: text.replaceRange(
      selection.start,
      selection.end,
      '$leading$insert$trailing',
    ),
    selection: TextSelection.collapsed(
      offset:
          selection.start +
          leading.length +
          insert.length +
          (trailingSpace ? 1 : 0),
    ),
  );
}

/// Inserts [prefix] like [insertMagicText]; a selection on one line
/// becomes its item (`Buy *milk`, `*"oat milk"`) instead of being replaced.
TextEditingValue insertMagicPrefix(TextEditingValue value, String prefix) {
  final selection = value.selection;
  if (!selection.isValid || selection.isCollapsed) {
    return insertMagicText(value, prefix);
  }
  final selected = value.text.substring(selection.start, selection.end).trim();
  if (selected.isEmpty || selected.contains('\n')) {
    return insertMagicText(
      value.copyWith(selection: TextSelection.collapsed(offset: selection.end)),
      prefix,
    );
  }
  return insertMagicText(value, '$prefix${quoteMagicValue(selected)}');
}

bool _startsWithSpace(String text) {
  final first = text.codeUnitAt(0);
  return first == 0x20 || first == 0x0A || first == 0x09;
}

bool _endsWithSpace(String text) {
  final last = text.codeUnitAt(text.length - 1);
  return last == 0x20 || last == 0x0A || last == 0x09;
}

/// Removes [spans] and one space next to each, keeping the caret where it
/// was relative to the text around it.
TextEditingValue removeMagicSpans(
  TextEditingValue value,
  Iterable<MagicSpan> spans,
) {
  var text = value.text;
  var caret = value.selection.isValid
      ? value.selection.baseOffset
      : text.length;
  final sorted = [...spans]..sort((a, b) => b.start.compareTo(a.start));
  var limit = text.length;
  for (final span in sorted) {
    if (span.end > limit) continue;
    var start = span.start;
    var end = span.end;
    if (text.startsWith(' ', end)) {
      end++;
    } else if (start > 0 && text[start - 1] == ' ') {
      start--;
    }
    text = text.replaceRange(start, end, '');
    if (caret >= end) {
      caret -= end - start;
    } else if (caret > start) {
      caret = start;
    }
    limit = start;
  }
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
  );
}
