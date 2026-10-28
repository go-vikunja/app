import 'dart:io';

/// The calls that open a dialog, a sheet, a picker or a menu, or a page
/// pushed with the Navigator, which the route walk does not see.
final RegExp overlayCall = RegExp(
  r'\b(showAdaptiveDialog|showDialog|showModalBottomSheet|showCupertinoSheet'
  '|showReadableCupertinoSheet|showCupertinoModalPopup|showDatePicker'
  '|showTimePicker|showMenu'
  '|MenuAnchor|PopupMenuButton|MaterialPageRoute|CupertinoPageRoute'
  r'|PageRouteBuilder)\b\s*(?:<.*?>)?\(',
);

/// One call of [overlayCall] in `app/lib`.
final class OverlaySite {
  const new({required this.key, required this.location});

  /// `<path under lib> <enclosing declaration> <call>`, with `#2` and on
  /// for a repeated call in one declaration; stable when lines move.
  final String key;

  /// `<path under lib>:<line>`, for the failure message.
  final String location;
}

final _declaration = RegExp(
  '^( {0,2})(?=[A-Za-z_])(?:static |external )?'
  r'(?:[\w$<>?,. ()]+?\s)?([a-z_$][\w$]*)\s*(?:<.*?>)?\(',
);
final _typeDeclaration = RegExp(
  '^(?:abstract |final |base |sealed |interface )*'
  r'(?:class|mixin|extension|enum)\s+([A-Za-z_$][\w$]*)',
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
};

/// Every overlay call under [lib], in file order.
List<OverlaySite> scanOverlaySites(Directory lib) {
  final files =
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
  final sites = <OverlaySite>[];
  for (final file in files) {
    final path = file.path.substring(lib.path.length + 1);
    final lines = file.readAsLinesSync();
    final counts = <String, int>{};
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) continue;
      for (final match in overlayCall.allMatches(line)) {
        if (_declaresTopLevel(line, match.group(1)!)) continue;
        final enclosing = _enclosing(lines, index);
        final base = '$path $enclosing ${match.group(1)}';
        final count = counts[base] = (counts[base] ?? 0) + 1;
        sites.add(
          OverlaySite(
            key: count == 1 ? base : '$base#$count',
            location: '$path:${index + 1}',
          ),
        );
      }
    }
  }
  return sites;
}

/// Whether [line] declares the top-level function [name], e.g. the app's
/// own presenter around one of the calls, rather than calling it.
bool _declaresTopLevel(String line, String name) {
  final match = _declaration.firstMatch(line);
  if (match == null || match.group(1)!.isNotEmpty) return false;
  final firstWord = line.trim().split(RegExp(r'[\s(<]')).first;
  return match.group(2) == name && !_notDeclarations.contains(firstWord);
}

/// The nearest declaration above [index]: a top-level function, or a
/// type's member, e.g. `showTaskDetail` or `_LabelRow.build`. A local
/// function inside a top-level function does not count.
String _enclosing(List<String> lines, int index) {
  String? member;
  for (var at = index; at >= 0; at--) {
    final line = lines[at];
    if (_typeDeclaration.firstMatch(line) case final type?) {
      final name = type.group(1)!;
      return member == null ? name : '$name.$member';
    }
    final match = _declaration.firstMatch(line);
    if (match == null) continue;
    final name = match.group(2)!;
    final firstWord = line.trim().split(RegExp(r'[\s(<]')).first;
    if (_notDeclarations.contains(name) ||
        _notDeclarations.contains(firstWord)) {
      continue;
    }
    if (match.group(1)!.isEmpty) return name;
    member ??= name;
  }
  return member ?? '<top>';
}
