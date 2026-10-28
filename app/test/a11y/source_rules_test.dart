import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The shipped sources, relative to the app package, where tests run.
List<String> _dartRoots() => [
  'lib',
  for (final parent in ['packages', 'plugins'])
    for (final entity in Directory('../$parent').listSync())
      if (entity is Directory) '${entity.path}/lib',
];

const _announcer = 'lib/features/common/presentation/announce.dart';

/// Sources whose heading level comes without header: true, each with its
/// reason.
const _levelsOfAnotherHeader = {
  'lib/features/common/presentation/screen_title.dart':
      "An AppBar's title: the AppBar's own header: true is on the same node, "
      'and a second header flag would split it into two nodes (headers '
      'conflict), one of them a header without a level. ScreenTitle asserts '
      'that it is the title of such an AppBar.',
};

final _header = RegExp(r'\bheader\s*:\s*true\b');
final _headingLevel = RegExp(r'\bheadingLevel\s*:');
final _directAnnouncement = RegExp(
  r'\bSemanticsService\s*\.\s*(sendAnnouncement|announce)\b',
);

void main() {
  final sources = [
    for (final root in _dartRoots())
      if (Directory(root).existsSync())
        for (final file in Directory(root).listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              !file.path.endsWith('.g.dart'))
            _Source.read(file),
  ];

  test('every header names its heading level in the same Semantics, and '
      'every heading level comes with header: true', () {
    final findings = [
      for (final source in sources) ..._headingFindings(source),
    ];
    expect(
      sources.where((source) => _header.hasMatch(source.code)),
      isNotEmpty,
    );
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  test('every announcement goes through the announcer, which falls back to '
      'a live region where the platform cannot announce', () {
    final findings = [
      for (final source in sources)
        if (!source.path.endsWith(_announcer))
          for (final match in _directAnnouncement.allMatches(source.code))
            source.finding(
              match.start,
              'announces directly; use announce() or Announcer',
            ),
    ];
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  group('the scan', () {
    List<String> scan(String code) =>
        _headingFindings(_Source('lib/sample.dart', code));

    test('takes a level among the arguments of the same call', () {
      expect(
        scan('''
Semantics(
  header: true,
  headingLevel: 2,
  child: Text('a, b (c)'),
)'''),
        isEmpty,
      );
    });

    test('names the line of a header without a level, also where a nested '
        'call has one', () {
      expect(
        scan('''
final a = Semantics(header: true, child: Text('x'));
final b = Semantics(
  header: true,
  child: Semantics(header: true, headingLevel: 1, child: Text('y')),
);'''),
        [
          'lib/sample.dart:1: header: true without headingLevel',
          'lib/sample.dart:3: header: true without headingLevel',
        ],
      );
    });

    test('names a level without header: true', () {
      expect(scan('Semantics(headingLevel: 1, child: x)'), [
        'lib/sample.dart:1: headingLevel without header: true',
      ]);
    });

    test('ignores strings and comments', () {
      expect(
        scan(r"""
// Semantics(header: true)
/* header: true /* nested */ headingLevel: 1 */
final a = 'header: true ${b('(')} headingLevel:';
final c = r'header: true';
final d = '''
header: true
''';
f(e, 'x)');"""),
        isEmpty,
      );
    });
  });
}

List<String> _headingFindings(_Source source) => [
  for (final match in _header.allMatches(source.code))
    if (!source.callAround(match.start).contains(_headingLevel))
      source.finding(match.start, 'header: true without headingLevel'),
  if (!_levelsOfAnotherHeader.keys.any(source.path.endsWith))
    for (final match in _headingLevel.allMatches(source.code))
      if (!source.callAround(match.start).contains(_header))
        source.finding(match.start, 'headingLevel without header: true'),
];

final class _Source {
  new(this.path, String text) : _text = text, code = _codeOnly(text);

  factory read(File file) =>
      _Source(file.path.replaceAll(r'\', '/'), file.readAsStringSync());

  final String path;
  final String _text;

  /// The text with strings and comments blanked, lines kept.
  final String code;

  int lineAt(int offset) =>
      '\n'.allMatches(_text.substring(0, offset)).length + 1;

  String finding(int offset, String what) => '$path:${lineAt(offset)}: $what';

  /// The arguments of the call [offset] is directly in, with the arguments
  /// of nested calls and literals blanked; empty outside of a call.
  String callAround(int offset) {
    var depth = 0;
    var open = -1;
    for (var i = offset - 1; i >= 0; i--) {
      final char = code[i];
      if (')]}'.contains(char)) depth++;
      if ('([{'.contains(char)) {
        if (depth == 0) {
          open = char == '(' ? i : -1;
          break;
        }
        depth--;
      }
    }
    if (open < 0) return '';
    final arguments = StringBuffer();
    depth = 0;
    for (var i = open + 1; i < code.length; i++) {
      final char = code[i];
      if ('([{'.contains(char)) depth++;
      if (')]}'.contains(char)) {
        if (depth == 0) break;
        depth--;
      }
      arguments.write(depth == 0 ? char : ' ');
    }
    return arguments.toString();
  }
}

String _codeOnly(String text) {
  final out = StringBuffer();
  void blank(int from, int to) {
    for (var i = from; i < to; i++) {
      out.write(text[i] == '\n' ? '\n' : ' ');
    }
  }

  var i = 0;
  while (i < text.length) {
    final end = _commentEnd(text, i) ?? _stringEnd(text, i);
    if (end != null) {
      blank(i, end);
      i = end;
    } else {
      out.write(text[i]);
      i++;
    }
  }
  return out.toString();
}

int? _commentEnd(String text, int start) {
  if (text.startsWith('//', start)) {
    final end = text.indexOf('\n', start);
    return end < 0 ? text.length : end;
  }
  if (!text.startsWith('/*', start)) return null;
  var i = start;
  var depth = 0;
  while (i < text.length) {
    if (text.startsWith('/*', i)) {
      depth++;
      i += 2;
    } else if (text.startsWith('*/', i)) {
      depth--;
      i += 2;
      if (depth == 0) return i;
    } else {
      i++;
    }
  }
  return text.length;
}

final _identifierChar = RegExp(r'[A-Za-z0-9_$]');

int? _stringEnd(String text, int start) {
  var i = start;
  final raw =
      text[i] == 'r' &&
      (i == 0 || !_identifierChar.hasMatch(text[i - 1])) &&
      i + 1 < text.length &&
      (text[i + 1] == "'" || text[i + 1] == '"');
  if (raw) i++;
  final quote = text[i];
  if (quote != "'" && quote != '"') return null;
  final triple = text.startsWith(quote * 3, i);
  final close = triple ? quote * 3 : quote;
  i += close.length;
  while (i < text.length) {
    if (!raw && text[i] == r'\') {
      i += 2;
    } else if (text.startsWith(close, i)) {
      return i + close.length;
    } else if (!raw && text.startsWith(r'${', i)) {
      i = _interpolationEnd(text, i + 2);
    } else {
      i++;
    }
  }
  return text.length;
}

int _interpolationEnd(String text, int start) {
  var i = start;
  var depth = 1;
  while (i < text.length) {
    final end = _stringEnd(text, i);
    if (end != null) {
      i = end;
      continue;
    }
    if (text[i] == '{') depth++;
    if (text[i] == '}' && --depth == 0) return i + 1;
    i++;
  }
  return text.length;
}
