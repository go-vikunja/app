import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// WidgetKit reloads widgets by kind: a kind the plugin names but the
// extension does not declare reloads nothing, without an error.
void main() {
  const extensionFolder = 'ios/VikunjaWidgets';
  final bundle = File('$extensionFolder/VikunjaWidgetsBundle.swift')
      .readAsStringSync();
  final plugin = File(
    '../plugins/vikunja_widgets/ios/vikunja_widgets/Sources/vikunja_widgets/'
    'VikunjaWidgetsPlugin.swift',
  ).readAsStringSync();

  final enumBody = RegExp(r'enum WidgetKinds \{([^}]*)\}')
      .firstMatch(bundle)
      ?.group(1);
  final declared = {
    for (final match in RegExp(
      r'static let (\w+) = "([^"]*)"',
    ).allMatches(enumBody ?? ''))
      match[1]!: match[2]!,
  };

  test('the plugin reloads exactly the kinds the extension declares', () {
    final list = RegExp(r'static let kinds = \[([^\]]*)\]')
        .firstMatch(plugin)
        ?.group(1);
    final reloaded = [
      for (final match in RegExp('"([^"]*)"').allMatches(list ?? '')) match[1]!,
    ];

    expect(declared.values, hasLength(2));
    expect(reloaded, unorderedEquals(declared.values));
  });

  test('every kind starts with Vikunja', () {
    expect(declared.values, isNotEmpty);
    for (final kind in declared.values) {
      expect(kind, startsWith('Vikunja'));
    }
  });

  test('every widget of the extension takes its kind from WidgetKinds', () {
    final used = [
      for (final entity in Directory(extensionFolder).listSync())
        if (entity is File && entity.path.endsWith('.swift'))
          for (final match in RegExp(
            r'Configuration\(\s*kind:\s*([\w.]+)',
          ).allMatches(entity.readAsStringSync()))
            match[1]!,
    ];

    expect(
      used,
      unorderedEquals([for (final name in declared.keys) 'WidgetKinds.$name']),
    );
  });
}
