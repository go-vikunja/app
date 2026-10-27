import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The widget extension shares files with the app, never the Keychain:
  // tokens stay with the app (D24, D63).
  for (final path in [
    'ios/Runner/Runner.entitlements',
    'ios/RuranaWidgets/RuranaWidgets.entitlements',
  ]) {
    test('$path grants the App Group and nothing else', () {
      final plist = File(path).readAsStringSync();
      final keys = [
        for (final match in RegExp('<key>([^<]+)</key>').allMatches(plist))
          match[1],
      ];

      expect(keys, ['com.apple.security.application-groups']);
      expect(plist, contains('<string>group.dev.coderoftime.vikunja</string>'));
      expect(plist, isNot(contains('keychain-access-groups')));
    });
  }
}
