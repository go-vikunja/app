import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/quick_add/quick_add_parser.dart';

/// One task of a multi-line quick add: its text without the indentation
/// and list marker, the line it is a subtask of, and the project prefix
/// it inherits from that parent line when it has none of its own.
@immutable
final class IndentedLine {
  const new({required this.text, this.parentIndex, this.inheritedProject});

  final String text;

  /// Index into the returned list; null for a top-level line.
  final int? parentIndex;

  /// The parent's `+project` (in the mode's prefix, its own or the one it
  /// inherits), when this line names none; null otherwise.
  final String? inheritedProject;

  @override
  bool operator ==(Object other) =>
      other is IndentedLine &&
      other.text == text &&
      other.parentIndex == parentIndex &&
      other.inheritedProject == inheritedProject;

  @override
  int get hashCode => Object.hash(text, parentIndex, inheritedProject);

  @override
  String toString() =>
      'IndentedLine($text, parent: $parentIndex, project: $inheritedProject)';
}

/// The web's `parseSubtasksViaIndention` (client-logic §1.9 item 12): one
/// entry per line that has text, in input order.
///
/// - The first line's indent is cut from every line; a later line with
///   less indent lowers the cut for itself and every line after it.
/// - A list marker (`- `, `* ` or `+ `, then `[ ] `) is stripped after the
///   indent.
/// - A line still indented after the cut is a subtask of the nearest
///   earlier line with less indent.
/// - A subtask without a project of its own (in [mode]'s prefix) inherits
///   its parent's, the parent's own or inherited one.
///
/// Where it parts from the web: a tab counts as four spaces (the web cuts
/// it from the first line like one space but never reads it as indent
/// after that); `[ ] ` without a bullet is a marker too, and a line that is
/// only a marker is no task (its subtasks move up to its parent), as in
/// D38's multi-line add; and grandchildren inherit the project as well,
/// which the web gives only to direct subtasks.
List<IndentedLine> parseSubtasksViaIndention(
  String text, {
  QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
}) {
  final lines = <({int indent, String text})>[];
  for (final line in text.split(_lineBreaks)) {
    if (line.trim().isEmpty) continue;
    final indent = _leadingIndent.stringMatch(line)!;
    lines.add((
      indent: _width(indent),
      text: line.substring(indent.length).replaceFirst(_listMarker, ''),
    ));
  }
  if (lines.isEmpty) return const [];

  var cut = lines.first.indent;
  final indents = <int>[];
  for (final line in lines) {
    if (line.indent < cut) cut = line.indent;
    indents.add(line.indent - cut);
  }
  final result = <IndentedLine>[];
  // Per line its index in the result; for a line without text, which is
  // left out, its parent's.
  final resultIndex = <int?>[];
  final projects = <String?>[];
  for (final (index, line) in lines.indexed) {
    final parent = indents[index] == 0 ? null : _parentIndex(indents, index);
    final own = parseQuickAddProject(line.text, mode: mode);
    final parentProject = parent == null ? null : projects[parent];
    projects.add(own ?? parentProject);
    final parentInResult = parent == null ? null : resultIndex[parent];
    if (line.text.trim().isEmpty) {
      resultIndex.add(parentInResult);
      continue;
    }
    resultIndex.add(result.length);
    result.add(
      IndentedLine(
        text: line.text,
        parentIndex: parentInResult,
        inheritedProject: own == null ? parentProject : null,
      ),
    );
  }
  return List.unmodifiable(result);
}

const _tabWidth = 4;
final _lineBreaks = RegExp(r'[\r\n]+');
final _leadingIndent = RegExp(r'^[ \t]*');
final _listMarker = RegExp(r'^(?:[-*+] )?(?:\[ \] )?');

int _width(String indent) => indent.runes.fold(
  0,
  (width, rune) => width + (rune == 0x09 ? _tabWidth : 1),
);

// The first line has no indent after the cut, so the walk ends there.
int _parentIndex(List<int> indents, int index) {
  var parent = index - 1;
  while (indents[parent] >= indents[index]) {
    parent--;
  }
  return parent;
}
