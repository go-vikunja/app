import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  test('English says "forever" for what the bin deletes, never "for good"', () {
    final english = jsonDecode(
      File('lib/l10n/arb/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final forGood = [
      for (final MapEntry(:key, :value) in english.entries)
        if (!key.startsWith('@') && (value! as String).contains('for good'))
          key,
    ];

    expect(forGood, isEmpty);
  });

  test('the restore paragraph of a project delete names the project, since '
      'it can follow the default-project paragraph', () {
    expect(en.projectTrashRestorable, startsWith('The project '));
    expect(de.projectTrashRestorable, contains(' das Projekt '));
  });
}
