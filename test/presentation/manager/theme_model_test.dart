import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/theming/app_colors.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/presentation/manager/theme_model.dart';

void main() {
  const dynamicLight = ColorScheme.light(primary: Color(0xFF00AA00));
  const dynamicDark = ColorScheme.dark(primary: Color(0xFF004400));

  group('getThemeMode', () {
    test('maps each stored mode onto a Flutter ThemeMode', () {
      expect(
        ThemeModel(themeMode: FlutterThemeMode.light).getThemeMode(),
        ThemeMode.light,
      );
      expect(
        ThemeModel(themeMode: FlutterThemeMode.dark).getThemeMode(),
        ThemeMode.dark,
      );
      expect(
        ThemeModel(themeMode: FlutterThemeMode.system).getThemeMode(),
        ThemeMode.system,
      );
    });

    test('defaults to light', () {
      expect(ThemeModel().getThemeMode(), ThemeMode.light);
    });
  });

  group('getTheme', () {
    test('uses the Vikunja palette when dynamic colours are off', () {
      final theme = ThemeModel(dynamicColors: false).getTheme(dynamicLight);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, isNot(dynamicLight.primary));
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('adopts the platform scheme when dynamic colours are on', () {
      final theme = ThemeModel(dynamicColors: true).getTheme(dynamicLight);

      expect(theme.colorScheme.primary, dynamicLight.primary);
      expect(theme.appBarTheme.backgroundColor, dynamicLight.primary);
    });

    test('always carries the semantic AppColors extension', () {
      for (final dynamicColors in [true, false]) {
        final theme = ThemeModel(
          dynamicColors: dynamicColors,
        ).getTheme(dynamicLight);
        final colors = theme.extension<AppColors>();

        expect(colors, isNotNull, reason: 'dynamicColors: $dynamicColors');
        expect(colors!.success, isNotNull);
        expect(colors.warning, isNotNull);
        expect(colors.danger, isNotNull);
      }
    });

    test('tolerates a null platform scheme', () {
      expect(
        () => ThemeModel(dynamicColors: true).getTheme(null),
        returnsNormally,
      );
    });
  });

  group('getDarkTheme', () {
    test('uses the Vikunja dark palette when dynamic colours are off', () {
      final theme = ThemeModel(dynamicColors: false).getDarkTheme(dynamicDark);

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, isNot(dynamicDark.primary));
    });

    test('adopts the platform scheme when dynamic colours are on', () {
      final theme = ThemeModel(dynamicColors: true).getDarkTheme(dynamicDark);

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, dynamicDark.primary);
      expect(theme.appBarTheme.backgroundColor, dynamicDark.primary);
    });

    test('always carries the semantic AppColors extension', () {
      for (final dynamicColors in [true, false]) {
        final theme = ThemeModel(
          dynamicColors: dynamicColors,
        ).getDarkTheme(dynamicDark);

        expect(
          theme.extension<AppColors>(),
          isNotNull,
          reason: 'dynamicColors: $dynamicColors',
        );
      }
    });
  });

  group('copyWith', () {
    test('keeps both fields when given nothing', () {
      final model = ThemeModel(
        themeMode: FlutterThemeMode.dark,
        dynamicColors: true,
      );

      final copy = model.copyWith();

      expect(copy.themeMode, FlutterThemeMode.dark);
      expect(copy.dynamicColors, isTrue);
    });

    test('replaces only the field it is given', () {
      final model = ThemeModel(themeMode: FlutterThemeMode.dark);

      expect(
        model.copyWith(dynamicColors: true).themeMode,
        FlutterThemeMode.dark,
      );
      expect(
        model.copyWith(themeMode: FlutterThemeMode.system).dynamicColors,
        isFalse,
      );
    });
  });

  group('AppColors extension', () {
    const colors = AppColors(
      success: Color(0xFF00FF00),
      onSuccess: Color(0xFF000000),
      warning: Color(0xFFFFFF00),
      onWarning: Color(0xFF000000),
      danger: Color(0xFFFF0000),
      onDanger: Color(0xFFFFFFFF),
    );

    test('copyWith replaces only what it is given', () {
      final copy = colors.copyWith(success: const Color(0xFF111111));

      expect(copy.success, const Color(0xFF111111));
      expect(copy.danger, colors.danger);
    });

    test('copyWith keeps everything when given nothing', () {
      final copy = colors.copyWith();

      expect(copy.success, colors.success);
      expect(copy.onDanger, colors.onDanger);
    });

    test('lerp at t=0 returns the starting colours', () {
      final lerped = colors.lerp(
        colors.copyWith(success: const Color(0xFF000000)),
        0,
      );

      expect(lerped.success, colors.success);
    });

    test('lerp with a non-AppColors other returns the receiver', () {
      expect(colors.lerp(null, 0.5), same(colors));
    });
  });
}
