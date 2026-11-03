/// The generated Material 3 palette. `ThemeModel` picks between these schemes;
/// this file checks the schemes themselves are well-formed and distinct.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/theming/theme.dart';

void main() {
  final theme = MaterialTheme(const TextTheme());

  group('colour schemes', () {
    final schemes = <String, ColorScheme>{
      'light': MaterialTheme.lightScheme(),
      'lightMediumContrast': MaterialTheme.lightMediumContrastScheme(),
      'lightHighContrast': MaterialTheme.lightHighContrastScheme(),
      'dark': MaterialTheme.darkScheme(),
      'darkMediumContrast': MaterialTheme.darkMediumContrastScheme(),
      'darkHighContrast': MaterialTheme.darkHighContrastScheme(),
    };

    schemes.forEach((name, scheme) {
      test('$name carries the core roles', () {
        expect(scheme.primary, isNotNull);
        expect(scheme.onPrimary, isNotNull);
        expect(scheme.surface, isNotNull);
        expect(scheme.error, isNotNull);
      });
    });

    test('light and dark schemes declare opposite brightness', () {
      expect(MaterialTheme.lightScheme().brightness, Brightness.light);
      expect(
        MaterialTheme.lightMediumContrastScheme().brightness,
        Brightness.light,
      );
      expect(
        MaterialTheme.lightHighContrastScheme().brightness,
        Brightness.light,
      );
      expect(MaterialTheme.darkScheme().brightness, Brightness.dark);
      expect(
        MaterialTheme.darkMediumContrastScheme().brightness,
        Brightness.dark,
      );
      expect(
        MaterialTheme.darkHighContrastScheme().brightness,
        Brightness.dark,
      );
    });

    test('light and dark are not the same palette', () {
      expect(
        MaterialTheme.lightScheme().surface,
        isNot(MaterialTheme.darkScheme().surface),
      );
    });

    test('each contrast level is its own palette', () {
      final surfaces = {
        MaterialTheme.lightScheme().onSurface,
        MaterialTheme.lightMediumContrastScheme().onSurface,
        MaterialTheme.lightHighContrastScheme().onSurface,
      };

      expect(surfaces, hasLength(3));
    });
  });

  group('themes', () {
    test('each factory builds a ThemeData with its own scheme', () {
      expect(theme.light().colorScheme, MaterialTheme.lightScheme());
      expect(
        theme.lightMediumContrast().colorScheme,
        MaterialTheme.lightMediumContrastScheme(),
      );
      expect(
        theme.lightHighContrast().colorScheme,
        MaterialTheme.lightHighContrastScheme(),
      );
      expect(theme.dark().colorScheme, MaterialTheme.darkScheme());
      expect(
        theme.darkMediumContrast().colorScheme,
        MaterialTheme.darkMediumContrastScheme(),
      );
      expect(
        theme.darkHighContrast().colorScheme,
        MaterialTheme.darkHighContrastScheme(),
      );
    });

    test('a built theme adopts the scheme it was given', () {
      const scheme = ColorScheme.light(primary: Color(0xFF123456));

      expect(theme.theme(scheme).colorScheme.primary, const Color(0xFF123456));
    });

    test('a built theme takes its brightness from the scheme', () {
      expect(
        theme.theme(MaterialTheme.darkScheme()).brightness,
        Brightness.dark,
      );
      expect(
        theme.theme(MaterialTheme.lightScheme()).brightness,
        Brightness.light,
      );
    });
  });

  group('extended colours', () {
    test('exposes success, danger and warning', () {
      expect(theme.extendedColors, [
        MaterialTheme.success,
        MaterialTheme.danger,
        MaterialTheme.warning,
      ]);
    });

    test('each extended colour has a light and a dark variant', () {
      for (final color in theme.extendedColors) {
        expect(color.light.color, isNotNull);
        expect(color.light.onColor, isNotNull);
        expect(color.dark.color, isNotNull);
        expect(color.dark.onColor, isNotNull);
      }
    });

    test('each extended colour has container variants', () {
      for (final color in theme.extendedColors) {
        expect(color.light.colorContainer, isNotNull);
        expect(color.light.onColorContainer, isNotNull);
        expect(color.dark.colorContainer, isNotNull);
        expect(color.dark.onColorContainer, isNotNull);
      }
    });

    test('success, danger and warning are visually distinct', () {
      final colors = {
        MaterialTheme.success.light.color,
        MaterialTheme.danger.light.color,
        MaterialTheme.warning.light.color,
      };

      expect(colors, hasLength(3));
    });

    test('an extended colour differs between light and dark', () {
      expect(
        MaterialTheme.success.light.color,
        isNot(MaterialTheme.success.dark.color),
      );
    });
  });
}
