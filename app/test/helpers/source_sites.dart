import 'dart:io';

/// One match of a scanned pattern in `app/lib`.
final class SourceSite {
  const new({
    required this.path,
    required this.enclosing,
    required this.name,
    required this.line,
  });

  /// The path under lib, e.g. `features/teams/presentation/team_page.dart`.
  final String path;

  /// The nearest declaration above the match: a top-level function,
  /// getter or variable, or a type's member, e.g. `showTaskDetail` or
  /// `_LabelRow.build`. A local function inside a top-level function does
  /// not count.
  final String enclosing;

  /// The pattern's first group.
  final String name;

  final int line;

  String get location => '$path:$line';
}

/// A return or variable type before a declared name: records, function
/// types and type arguments included.
const _type = r'(?:[\w$<>?,. (){}]+?\s)';
const _start = '^( {0,2})(?=[A-Za-z_(])(?:static |external )?';

/// A modifier before a record type, as in `final (int, int) pair;`, is no
/// function's name.
const _name = r'(?!(?:final|const|late|var|covariant)\b)([a-z_$][\w$]*)';

final _declaration = RegExp(
  '$_start$_type?$_name'
  r'\s*(?:<.*?>)?\(',
);
final _getter = RegExp(
  '$_start$_type?'
  r'get\s+([a-z_$][\w$]*)\s*(?:async\*?|sync\*)?\s*(?:=>|\{|;|$)',
);
final _operator = RegExp(
  '$_start$_type?'
  r'(operator\s*[^\s(]+)\s*\(',
);

/// Without a type for a name on a line of its own below a type dart format
/// split over lines.
final _variable = RegExp(
  '$_start$_type?$_name'
  r'\s*(?:=(?![=>])|;)',
);
final _enumValue = RegExp(r'^( {0,2})([a-z_$][\w$]*)\s*[,;]?$');
final _typeDeclaration = RegExp(
  '^(?:(?:abstract|final|base|sealed|interface|mixin) )*'
  r'(?:class|mixin|enum|extension type(?: const)?|extension(?!\s+on\b))\s+'
  r'([A-Za-z_$][\w$]*)',
);
final _unnamedExtension = RegExp(
  r'^extension\s*(?:<.*?>)?\s+on\s+(.*?)\s*\{?\s*$',
);

/// A constructor named after its type, as `Name.named` or `Name`, is a
/// member named `named` or `new`, as one declared with `new` is.
final _constructor = RegExp(
  r'^  (?:const |external )*(?:factory )?_?[A-Z$][\w$]*'
  r'(?:\.([a-z_$][\w$]*))?\s*\(',
);
const _notDeclarations = {
  'if',
  'for',
  'while',
  'switch',
  'return',
  'await',
  'unawaited',
  'assert',
  'catch',
  'super',
  'this',
  'throw',
  'yield',
  'break',
  'continue',
  'else',
  'library',
  'typedef',
};

/// The Dart files under [lib] that people write, in path order.
List<File> sourceFiles(Directory lib) =>
    lib
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.endsWith('.g.dart') &&
              !file.path.contains('/l10n/generated/'),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Every match of [pattern] outside line comments in the files under
/// [lib] that [include] accepts, in file order. [skip] drops a match, e.g.
/// one that declares the name rather than using it.
List<SourceSite> scanSourceSites(
  Directory lib,
  RegExp pattern, {
  bool Function(String path)? include,
  bool Function(String line, String name)? skip,
}) {
  final sites = <SourceSite>[];
  for (final file in sourceFiles(lib)) {
    final path = file.path.substring(lib.path.length + 1);
    if (include != null && !include(path)) continue;
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trimLeft().startsWith('//')) continue;
      for (final match in pattern.allMatches(line)) {
        final name = match.group(1)!;
        if (skip != null && skip(line, name)) continue;
        sites.add(
          SourceSite(
            path: path,
            enclosing: enclosingDeclaration(lines, index),
            name: name,
            line: index + 1,
          ),
        );
      }
    }
  }
  return sites;
}

/// Whether [line] declares the top-level function [name] rather than
/// calling it.
bool declaresTopLevel(String line, String name) {
  final match = _declaration.firstMatch(line);
  if (match == null || match.group(1)!.isNotEmpty) return false;
  return match.group(2) == name && !_notDeclarations.contains(_firstWord(line));
}

/// Whether [line] declares [name] at the top level or in a type's body: a
/// function, getter, variable, field or enum value.
bool declares(String line, String name) {
  if (_notDeclarations.contains(_firstWord(line))) return false;
  final match =
      _declaration.firstMatch(line) ??
      _getter.firstMatch(line) ??
      _variable.firstMatch(line) ??
      _enumValue.firstMatch(line);
  return match?.group(2) == name;
}

/// The nearest declaration above [index], as [SourceSite.enclosing].
String enclosingDeclaration(List<String> lines, int index) {
  String? member;
  for (var at = index; at >= 0; at--) {
    final line = lines[at];
    final type = _typeName(lines, at);
    if (type != null) return member == null ? type : '$type.$member';
    if (_notDeclarations.contains(_firstWord(line))) continue;
    if (_constructor.firstMatch(line) case final constructor?) {
      member ??= constructor.group(1) ?? 'new';
      continue;
    }
    final match =
        _declaration.firstMatch(line) ??
        _getter.firstMatch(line) ??
        _operator.firstMatch(line) ??
        _variable.firstMatch(line);
    if (match == null) continue;
    final name = match.group(2)!.replaceAll(' ', '');
    if (_notDeclarations.contains(name)) continue;
    if (match.group(1)!.isEmpty) return name;
    member ??= name;
  }
  return member ?? '<top>';
}

/// The name of the type declared at [at], or null. An unnamed extension
/// is named by its type, numbered from the second on that type in its
/// file, so two never share a name.
String? _typeName(List<String> lines, int at) {
  if (_typeDeclaration.firstMatch(lines[at]) case final type?) {
    return type.group(1);
  }
  final on = _unnamedExtension.firstMatch(lines[at])?.group(1);
  if (on == null) return null;
  final number =
      1 +
      lines
          .take(at)
          .where((line) => _unnamedExtension.firstMatch(line)?.group(1) == on)
          .length;
  return number == 1 ? 'extension on $on' : 'extension on $on #$number';
}

String _firstWord(String line) => line.trim().split(RegExp(r'[\s(<]')).first;
