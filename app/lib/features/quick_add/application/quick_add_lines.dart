import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

typedef SubtaskParser = List<IndentedLine> Function(
  String text, {
  QuickAddMagicMode mode,
});

final _lineBreaks = RegExp(r'\r\n|\r|\n');

/// The tasks a quick-add text stands for, one per line with text, each
/// with the line it is a subtask of. A single line is taken as typed;
/// several go through [parse], which strips the indentation and list
/// markers and makes a line indented deeper than the one before a subtask
/// (`parseSubtasksViaIndention`).
List<IndentedLine> quickAddTaskLines(
  String text, {
  QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
  SubtaskParser parse = parseSubtasksViaIndention,
}) {
  final lines = [
    for (final line in text.split(_lineBreaks))
      if (line.trim().isNotEmpty) line,
  ];
  if (lines.length < 2) {
    return [for (final line in lines) IndentedLine(text: line)];
  }
  return parse(text, mode: mode);
}

/// The titles of [quickAddTaskLines], one per task.
List<String> splitQuickAddLines(
  String text, {
  QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
  SubtaskParser parse = parseSubtasksViaIndention,
}) => [
  for (final line in quickAddTaskLines(text, mode: mode, parse: parse))
    line.text,
];
