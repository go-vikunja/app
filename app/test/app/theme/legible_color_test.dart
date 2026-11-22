import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/legible_color.dart';

void main() {
  final light = AppTheme.brandScheme(Brightness.light).surfaceContainerLow;
  final dark = AppTheme.brandScheme(Brightness.dark).surfaceContainerLow;

  Color hex(int rgb) => Color(0xFF000000 | rgb);
  double hue(Color color) => HSLColor.fromColor(color).hue;
  double lightness(Color color) => HSLColor.fromColor(color).lightness;

  test('a colour that stands out by 3:1 already is drawn as stored', () {
    for (final (color, surface) in [
      (hex(0x6a1b9a), light),
      (hex(0x1973ff), light),
      (hex(0xf0e442), dark),
      (hex(0x56b4e9), dark),
    ]) {
      expect(legibleOn(color, surface), color);
    }
  });

  test('a dark colour on the dark card gets just light enough, keeping its '
      'hue', () {
    for (final color in [hex(0x6a1b9a), hex(0x1565c0), hex(0x000000)]) {
      final drawn = legibleOn(color, dark);
      expect(contrastRatio(color, dark), lessThan(3));
      expect(contrastRatio(drawn, dark), inInclusiveRange(3, 3.15));
      expect(lightness(drawn), greaterThan(lightness(color)));
      if (color != hex(0x000000)) {
        expect((hue(drawn) - hue(color)).abs(), lessThan(8), reason: '$drawn');
      }
    }
  });

  test('a pale colour on the light card gets just dark enough, keeping its '
      'hue; the Okabe–Ito swatches too', () {
    for (final color in [
      hex(0xf0e442),
      hex(0x56b4e9),
      hex(0xe69f00),
      hex(0xcc79a7),
      hex(0xffffff),
    ]) {
      final drawn = legibleOn(color, light);
      expect(contrastRatio(drawn, light), inInclusiveRange(3, 3.15));
      expect(lightness(drawn), lessThan(lightness(color)));
      if (color != hex(0xffffff)) {
        expect((hue(drawn) - hue(color)).abs(), lessThan(8), reason: '$drawn');
      }
    }
  });

  test('a higher contrast for text, and the alpha kept', () {
    final drawn = legibleOn(
      hex(0xef6c00).withValues(alpha: 0.5),
      light,
      minContrast: 4.5,
    );
    expect(drawn.a, 0.5);
    expect(
      contrastRatio(drawn.withValues(alpha: 1), light),
      inInclusiveRange(4.5, 4.7),
    );
  });

  testWidgets('the surface behind is the nearest opaque Material, else the '
      "theme's surface", (tester) async {
    final theme = AppTheme.dark();
    late BuildContext onCard;
    late BuildContext onClear;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              Card(
                child: Builder(
                  builder: (context) {
                    onCard = context;
                    return const SizedBox.square(dimension: 10);
                  },
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Builder(
                  builder: (context) {
                    onClear = context;
                    return const SizedBox.square(dimension: 10);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(surfaceBehind(onCard), theme.colorScheme.surfaceContainerLow);
    expect(surfaceBehind(onClear), theme.colorScheme.surface);
    expect(
      legibleIn(onCard, hex(0x6a1b9a)),
      legibleOn(hex(0x6a1b9a), theme.colorScheme.surfaceContainerLow),
    );
  });
}
