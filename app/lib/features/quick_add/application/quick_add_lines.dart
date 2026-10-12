final _lineBreaks = RegExp(r'\r\n|\r|\n');
final _listMarker = RegExp(r'^(?:[-*+] )?(?:\[ \] )?');

/// The tasks a quick-add text stands for, one per non-blank line. A single
/// line is taken as typed; of several, each loses its indentation (it does
/// not make subtasks yet) and a leading list marker (`- `, `* `, `+ `,
/// `[ ] ` or `- [ ] `), as when a list is pasted.
List<String> splitQuickAddLines(String text) {
  final lines = [
    for (final line in text.split(_lineBreaks))
      if (line.trim().isNotEmpty) line,
  ];
  if (lines.length < 2) return lines;
  return [
    for (final line in lines)
      if (line.trimLeft().replaceFirst(_listMarker, '') case final item
          when item.trim().isNotEmpty)
        item,
  ];
}
