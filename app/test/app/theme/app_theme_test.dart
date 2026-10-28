import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';

double _contrast(Color a, Color b) {
  final (light, dark) = a.computeLuminance() > b.computeLuminance()
      ? (a, b)
      : (b, a);
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}

/// The largest difference of one channel, 0 to 255.
int _distance(Color a, Color b) => [
  ((a.r - b.r) * 255).round().abs(),
  ((a.g - b.g) * 255).round().abs(),
  ((a.b - b.b) * 255).round().abs(),
].reduce((x, y) => x > y ? x : y);

void main() {
  group('brand scheme', () {
    final light = AppTheme.brandScheme(Brightness.light);

    test("lands close to the mockups' tokens", () {
      final tokens = {
        light.surface: const Color(0xFFF8FAFE),
        light.onSurface: const Color(0xFF161B24),
        light.surfaceContainerLow: const Color(0xFFEEF2F9),
        light.surfaceContainer: const Color(0xFFE8EDF6),
        light.surfaceContainerHighest: const Color(0xFFDEE3ED),
        light.primary: const Color(0xFF1E59CD),
        light.primaryContainer: const Color(0xFFC8DBFF),
        light.secondaryContainer: const Color(0xFFD7E2F7),
        light.outlineVariant: const Color(0xFFC6CBD5),
        light.error: const Color(0xFFC92324),
        light.inversePrimary: const Color(0xFF9DBDFF),
      };
      for (final MapEntry(key: actual, value: token) in tokens.entries) {
        expect(_distance(actual, token), lessThanOrEqualTo(32));
      }
      expect(light.tertiaryContainer, AppTheme.amberSeedColor);
    });

    for (final brightness in Brightness.values) {
      test('keeps text readable in $brightness', () {
        final colors = AppTheme.brandScheme(brightness);
        for (final (text, background) in [
          (colors.onSurface, colors.surface),
          (colors.onSurfaceVariant, colors.surfaceContainerLow),
          (colors.primary, colors.surfaceContainerLow),
          (colors.error, colors.surfaceContainerLow),
          (colors.tertiary, colors.surfaceContainerLow),
          (colors.onSecondaryContainer, colors.secondaryContainer),
          (colors.onPrimaryContainer, colors.primaryContainer),
          (colors.onTertiaryContainer, colors.tertiaryContainer),
        ]) {
          expect(_contrast(text, background), greaterThanOrEqualTo(4.5));
        }
      });
    }
  });

  group('component themes', () {
    final system = ColorScheme.fromSeed(seedColor: const Color(0xFF00AA44));

    for (final (name, theme, colors) in [
      ('brand', AppTheme.light(), AppTheme.brandScheme(Brightness.light)),
      ('system', AppTheme.light(colorScheme: system), system),
      ('dark brand', AppTheme.dark(), AppTheme.brandScheme(Brightness.dark)),
    ]) {
      test('apply to the $name scheme', () {
        expect(theme.colorScheme, colors);
        expect(theme.bottomSheetTheme.backgroundColor, colors.surfaceContainer);
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
        expect(
          theme.navigationRailTheme.backgroundColor,
          colors.surfaceContainer,
        );
        expect(
          theme.navigationBarTheme.labelTextStyle?.resolve({
            WidgetState.selected,
          })?.fontWeight,
          FontWeight.w700,
        );
        expect(
          theme.switchTheme.thumbIcon?.resolve({WidgetState.selected}),
          isA<Icon>(),
        );
        expect(theme.switchTheme.thumbIcon?.resolve({}), isNull);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.cardTheme.elevation, 0);
      });
    }

    for (final (name, theme) in [
      ('light', AppTheme.light()),
      ('dark', AppTheme.dark()),
    ]) {
      testWidgets('a scrolled-under app bar in $name is surfaceContainer, '
          'like the navigation bar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              appBar: AppBar(title: const Text('Title')),
              body: ListView(
                children: [
                  for (var i = 0; i < 40; i++) ListTile(title: Text('$i')),
                ],
              ),
            ),
          ),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();

        final appBar = tester.widget<PhysicalModel>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(PhysicalModel),
              )
              .first,
        );
        expect(appBar.elevation, greaterThan(0));
        expect(appBar.color, theme.colorScheme.surfaceContainer);
      });
    }

    test("the highlight is the brand's amber, else the system's tertiary", () {
      final brand = AppTheme.light().extension<HighlightColors>()!;
      expect(brand.highlight, AppTheme.amberSeedColor);
      final fromSystem = AppTheme.light(colorScheme: system)
          .extension<HighlightColors>()!;
      expect(fromSystem.highlight, system.tertiary);
    });
  });

  group('contrast by scheme (WCAG 1.4.3 and 1.4.11)', () {
    const text = 4.5;
    const component = 3.0;
    final schemes = {
      'brand light': AppTheme.light(),
      'brand dark': AppTheme.dark(),
      'high-contrast light': AppTheme.highContrastLight(),
      'high-contrast dark': AppTheme.highContrastDark(),
    };

    for (final MapEntry(key: name, value: theme) in schemes.entries) {
      final colors = theme.colorScheme;
      test('$name keeps text readable', () {
        for (final (pair, foreground, background) in [
          ('onSurface on surface', colors.onSurface, colors.surface),
          (
            'onSurfaceVariant on surface',
            colors.onSurfaceVariant,
            colors.surface,
          ),
          (
            'onSurfaceVariant on surfaceContainerHighest',
            colors.onSurfaceVariant,
            colors.surfaceContainerHighest,
          ),
          for (final (role, color) in [
            ('primary', colors.primary),
            ('tertiary', colors.tertiary),
            ('error', colors.error),
          ]) ...[
            ('$role on surface', color, colors.surface),
            (
              '$role on surfaceContainerHighest',
              color,
              colors.surfaceContainerHighest,
            ),
          ],
          (
            'an uncoloured label pill',
            colors.onSecondaryContainer,
            colors.secondaryContainer,
          ),
        ]) {
          expect(
            _contrast(foreground, background),
            greaterThanOrEqualTo(text),
            reason: pair,
          );
        }
      });

      test('$name keeps field borders visible', () {
        expect(
          _contrast(colors.outline, colors.surfaceContainer),
          greaterThanOrEqualTo(component),
        );
      });

      // The light brand amber is the one exception: it fills the star and
      // the high-priority flag beside an outline and a name in readable
      // colours, so it is never the only sign.
      if (name == 'brand light') {
        test('$name: the amber highlight is the named exception', () {
          final highlight = theme.extension<HighlightColors>()!.highlight;
          expect(
            _contrast(highlight, colors.surface),
            inInclusiveRange(1.7, 2.0),
          );
        });
      } else {
        test('$name: the highlight stands out from the surface', () {
          final highlight = theme.extension<HighlightColors>()!.highlight;
          expect(
            _contrast(highlight, colors.surface),
            greaterThanOrEqualTo(component),
          );
        });
      }
    }

    test("a label pill's text is readable on any server colour", () {
      for (var r = 0; r <= 255; r += 17) {
        for (var g = 0; g <= 255; g += 17) {
          for (var b = 0; b <= 255; b += 17) {
            final pill = Color.fromARGB(255, r, g, b);
            expect(
              _contrast(contrastingTextColor(pill), pill),
              greaterThanOrEqualTo(text),
              reason: pill.toString(),
            );
          }
        }
      }
    });
  });
}
