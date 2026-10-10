import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';

void main() {
  test('parses six hex digits with or without #', () {
    expect(parseHexColor('1973ff'), const Color(0xFF1973FF));
    expect(parseHexColor('#1973FF'), const Color(0xFF1973FF));
    expect(parseHexColor(''), isNull);
    expect(parseHexColor('#'), isNull);
    expect(parseHexColor('fff'), isNull);
    expect(parseHexColor('var(--x)'), isNull);
    expect(parseHexColor('1973ff00'), isNull);
  });

  test('text colour follows the web rule', () {
    // From the web's getTextColor test.
    expect(
      contrastingTextColor(const Color(0xFFE74C3C)),
      const Color(0xFF000000),
    );
    expect(
      contrastingTextColor(const Color(0xFF4287F5)),
      const Color(0xFF000000),
    );
    expect(
      contrastingTextColor(const Color(0xFFFFFFFF)),
      const Color(0xFF000000),
    );
    expect(
      contrastingTextColor(const Color(0xFF000000)),
      const Color(0xFFFFFFFF),
    );
    expect(
      contrastingTextColor(const Color(0xFF1A1A1A)),
      const Color(0xFFFFFFFF),
    );
    expect(
      contrastingTextColor(const Color(0xFF800000)),
      const Color(0xFFFFFFFF),
    );
  });

  test('every chip colour keeps at least 4.5:1 contrast', () {
    for (var r = 0; r < 256; r += 51) {
      for (var g = 0; g < 256; g += 51) {
        for (var b = 0; b < 256; b += 51) {
          final background = Color.fromARGB(255, r, g, b);
          final text = contrastingTextColor(background);
          final lighter = [
            background.computeLuminance(),
            text.computeLuminance(),
          ]..sort();
          final ratio = (lighter[1] + 0.05) / (lighter[0] + 0.05);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$background');
        }
      }
    }
  });
}
