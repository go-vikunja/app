import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';

// The native launch screens cannot read the Flutter theme, so they repeat its
// surface colours. This keeps them in sync when the seed colour changes.
Color _androidLaunchColor(String valuesDir) {
  final xml = File('android/app/src/main/res/$valuesDir/colors.xml')
      .readAsStringSync();
  final hex = RegExp('name="launch_background">#([0-9A-Fa-f]{6})<')
      .firstMatch(xml)!
      .group(1)!;
  return Color(int.parse('FF$hex', radix: 16));
}

({Color light, Color dark}) _iosLaunchColors() {
  final contents = jsonDecode(
    File('ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  final entries = (contents['colors']! as List).cast<Map<String, Object?>>();

  bool isDark(Map<String, Object?> entry) =>
      (entry['appearances'] as List?)?.any(
        (appearance) =>
            appearance is Map &&
            appearance['appearance'] == 'luminosity' &&
            appearance['value'] == 'dark',
      ) ??
      false;

  // Xcode writes components either as "0xFA" or as a float such as "0.980".
  int channel(Object? component) {
    final text = component! as String;
    return text.startsWith('0x')
        ? int.parse(text.substring(2), radix: 16)
        : (double.parse(text) * 255).round();
  }

  Color colorOf(Map<String, Object?> entry) {
    final color = entry['color']! as Map<String, Object?>;
    expect(color['color-space'], 'srgb');
    final components = color['components']! as Map<String, Object?>;
    return Color.fromARGB(
      255,
      channel(components['red']),
      channel(components['green']),
      channel(components['blue']),
    );
  }

  return (
    light: colorOf(entries.singleWhere((entry) => !isDark(entry))),
    dark: colorOf(entries.singleWhere(isDark)),
  );
}

void main() {
  test('the native launch screens use the theme surface colours', () {
    final light = AppTheme.light().colorScheme.surface;
    final dark = AppTheme.dark().colorScheme.surface;

    expect(_androidLaunchColor('values'), light);
    expect(_androidLaunchColor('values-night'), dark);

    final ios = _iosLaunchColors();
    expect(ios.light, light);
    expect(ios.dark, dark);
  });

  test('the iOS launch screen takes its background from the colour set', () {
    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
        .readAsStringSync();

    expect(
      storyboard,
      contains('<color key="backgroundColor" name="LaunchBackground"/>'),
    );
  });
}
