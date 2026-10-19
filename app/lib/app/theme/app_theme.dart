import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const seedColor = Color(0xFF1973FF);

  /// [colorScheme] replaces the brand colours, e.g. with the system's.
  static ThemeData light({ColorScheme? colorScheme}) =>
      _build(colorScheme ?? _seeded(Brightness.light));

  static ThemeData dark({ColorScheme? colorScheme}) =>
      _build(colorScheme ?? _seeded(Brightness.dark));

  static ColorScheme _seeded(Brightness brightness) => ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  static ThemeData _build(ColorScheme colorScheme) {
    final base = ThemeData(colorScheme: colorScheme);
    return base.copyWith(
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    );
  }
}
