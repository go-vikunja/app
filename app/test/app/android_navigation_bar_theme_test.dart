import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// The items of each style in a styles.xml, by style name.
Map<String, Map<String, String>> _styles(String folder) {
  final xml = File('$_res/$folder/styles.xml').readAsStringSync();
  return {
    for (final style in RegExp(
      r'<style name="(\w+)" parent="([^"]+)">(.*?)</style>',
      dotAll: true,
    ).allMatches(xml))
      style.group(1)!: {
        'parent': style.group(2)!,
        for (final item in RegExp(
          '<item name="([^"]+)"[^>]*>([^<]*)</item>',
        ).allMatches(style.group(3)!))
          item.group(1)!: item.group(2)!,
      },
  };
}

void main() {
  for (final (base, versioned, lightIcons) in const [
    ('values', 'values-v27', 'true'),
    ('values-night', 'values-night-v27', 'false'),
  ]) {
    test('$versioned gives the navigation bar a transparent colour and '
        'icons for its theme, and otherwise equals $base', () {
      final plain = _styles(base);
      final themes = _styles(versioned);
      expect(themes.keys, unorderedEquals(['LaunchTheme', 'NormalTheme']));
      for (final MapEntry(key: name, value: items) in themes.entries) {
        // A colour the theme names keeps Android 15 and later from forcing
        // light icons after the window's background.
        expect(
          items['android:navigationBarColor'],
          '@android:color/transparent',
          reason: name,
        );
        expect(
          items['android:windowLightNavigationBar'],
          lightIcons,
          reason: name,
        );
        expect(
          Map.of(items)
            ..remove('android:navigationBarColor')
            ..remove('android:windowLightNavigationBar'),
          plain[name],
          reason: '$name as in $base',
        );
      }
    });
  }
}
