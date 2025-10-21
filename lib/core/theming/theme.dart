import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff0055c7),
      surfaceTint: Color(0xff0058cc),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff026cf8),
      onPrimaryContainer: Color(0xfffefcff),
      secondary: Color(0xff435d99),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffa1bafd),
      onSecondaryContainer: Color(0xff2e4984),
      tertiary: Color(0xff9029b1),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffac47cc),
      onTertiaryContainer: Color(0xfffffbff),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff191b24),
      onSurfaceVariant: Color(0xff424655),
      outline: Color(0xff727787),
      outlineVariant: Color(0xffc2c6d8),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2d3039),
      inversePrimary: Color(0xffb0c6ff),
      primaryFixed: Color(0xffd9e2ff),
      onPrimaryFixed: Color(0xff001945),
      primaryFixedDim: Color(0xffb0c6ff),
      onPrimaryFixedVariant: Color(0xff00419c),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff001945),
      secondaryFixedDim: Color(0xffb0c6ff),
      onSecondaryFixedVariant: Color(0xff29457f),
      tertiaryFixed: Color(0xfffbd7ff),
      onTertiaryFixed: Color(0xff330044),
      tertiaryFixedDim: Color(0xfff0b0ff),
      onTertiaryFixedVariant: Color(0xff770099),
      surfaceDim: Color(0xffd8d9e5),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff2f3ff),
      surfaceContainer: Color(0xffecedf9),
      surfaceContainerHigh: Color(0xffe6e7f3),
      surfaceContainerHighest: Color(0xffe1e2ed),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff00327b),
      surfaceTint: Color(0xff0058cc),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff0065ea),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff15346e),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff526ca9),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff5d0078),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffa33ec4),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff0e1119),
      onSurfaceVariant: Color(0xff313644),
      outline: Color(0xff4d5261),
      outlineVariant: Color(0xff686d7c),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2d3039),
      inversePrimary: Color(0xffb0c6ff),
      primaryFixed: Color(0xff0065ea),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff004fb8),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff526ca9),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff38538f),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xffa33ec4),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff871fa9),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc4c6d1),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff2f3ff),
      surfaceContainer: Color(0xffe6e7f3),
      surfaceContainerHigh: Color(0xffdbdce8),
      surfaceContainerHighest: Color(0xffcfd1dc),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff002867),
      surfaceTint: Color(0xff0058cc),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff0044a1),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff052963),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff2c4782),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff4d0065),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff7a079c),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff272c39),
      outlineVariant: Color(0xff444957),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2d3039),
      inversePrimary: Color(0xffb0c6ff),
      primaryFixed: Color(0xff0044a1),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff002f74),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff2c4782),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff10306a),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff7a079c),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff580071),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb6b8c3),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeff0fc),
      surfaceContainer: Color(0xffe1e2ed),
      surfaceContainerHigh: Color(0xffd2d4df),
      surfaceContainerHighest: Color(0xffc4c6d1),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffb0c6ff),
      surfaceTint: Color(0xffb0c6ff),
      onPrimary: Color(0xff002c6f),
      primaryContainer: Color(0xff578cff),
      onPrimaryContainer: Color(0xff000c2a),
      secondary: Color(0xffb0c6ff),
      onSecondary: Color(0xff0d2e68),
      secondaryContainer: Color(0xff2c4782),
      onSecondaryContainer: Color(0xff9db7fa),
      tertiary: Color(0xfff0b0ff),
      onTertiary: Color(0xff54006d),
      tertiaryContainer: Color(0xffcc65eb),
      onTertiaryContainer: Color(0xff1f002a),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff10131b),
      onSurface: Color(0xffe1e2ed),
      onSurfaceVariant: Color(0xffc2c6d8),
      outline: Color(0xff8c90a1),
      outlineVariant: Color(0xff424655),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2ed),
      inversePrimary: Color(0xff0058cc),
      primaryFixed: Color(0xffd9e2ff),
      onPrimaryFixed: Color(0xff001945),
      primaryFixedDim: Color(0xffb0c6ff),
      onPrimaryFixedVariant: Color(0xff00419c),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff001945),
      secondaryFixedDim: Color(0xffb0c6ff),
      onSecondaryFixedVariant: Color(0xff29457f),
      tertiaryFixed: Color(0xfffbd7ff),
      onTertiaryFixed: Color(0xff330044),
      tertiaryFixedDim: Color(0xfff0b0ff),
      onTertiaryFixedVariant: Color(0xff770099),
      surfaceDim: Color(0xff10131b),
      surfaceBright: Color(0xff363942),
      surfaceContainerLowest: Color(0xff0b0e16),
      surfaceContainerLow: Color(0xff191b24),
      surfaceContainer: Color(0xff1d1f28),
      surfaceContainerHigh: Color(0xff272a32),
      surfaceContainerHighest: Color(0xff32353d),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd0dcff),
      surfaceTint: Color(0xffb0c6ff),
      onPrimary: Color(0xff00225a),
      primaryContainer: Color(0xff578cff),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffd0dcff),
      onSecondary: Color(0xff00225a),
      secondaryContainer: Color(0xff768fcf),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xfff9cfff),
      onTertiary: Color(0xff430058),
      tertiaryContainer: Color(0xffcc65eb),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff10131b),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd8dcee),
      outline: Color(0xffadb1c3),
      outlineVariant: Color(0xff8b90a0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2ed),
      inversePrimary: Color(0xff00439f),
      primaryFixed: Color(0xffd9e2ff),
      onPrimaryFixed: Color(0xff000f30),
      primaryFixedDim: Color(0xffb0c6ff),
      onPrimaryFixedVariant: Color(0xff00327b),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff000f30),
      secondaryFixedDim: Color(0xffb0c6ff),
      onSecondaryFixedVariant: Color(0xff15346e),
      tertiaryFixed: Color(0xfffbd7ff),
      onTertiaryFixed: Color(0xff23002f),
      tertiaryFixedDim: Color(0xfff0b0ff),
      onTertiaryFixedVariant: Color(0xff5d0078),
      surfaceDim: Color(0xff10131b),
      surfaceBright: Color(0xff42444d),
      surfaceContainerLowest: Color(0xff05070f),
      surfaceContainerLow: Color(0xff1b1d26),
      surfaceContainer: Color(0xff252830),
      surfaceContainerHigh: Color(0xff30323b),
      surfaceContainerHighest: Color(0xff3b3d47),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffedefff),
      surfaceTint: Color(0xffb0c6ff),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffaac2ff),
      onPrimaryContainer: Color(0xff000a24),
      secondary: Color(0xffedefff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffaac2ff),
      onSecondaryContainer: Color(0xff000a24),
      tertiary: Color(0xffffe9ff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffefaaff),
      onTertiaryContainer: Color(0xff1a0024),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff10131b),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffedefff),
      outlineVariant: Color(0xffbec2d4),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2ed),
      inversePrimary: Color(0xff00439f),
      primaryFixed: Color(0xffd9e2ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffb0c6ff),
      onPrimaryFixedVariant: Color(0xff000f30),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb0c6ff),
      onSecondaryFixedVariant: Color(0xff000f30),
      tertiaryFixed: Color(0xfffbd7ff),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xfff0b0ff),
      onTertiaryFixedVariant: Color(0xff23002f),
      surfaceDim: Color(0xff10131b),
      surfaceBright: Color(0xff4d5059),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1d1f28),
      surfaceContainer: Color(0xff2d3039),
      surfaceContainerHigh: Color(0xff383b44),
      surfaceContainerHighest: Color(0xff444650),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: colorScheme.background,
    canvasColor: colorScheme.surface,
  );

  /// success
  static const success = ExtendedColor(
    seed: Color(0xff00db60),
    value: Color(0xff00db60),
    light: ColorFamily(
      color: Color(0xff006e2c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xff00db60),
      onColorContainer: Color(0xff005a23),
    ),
    lightMediumContrast: ColorFamily(
      color: Color(0xff006e2c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xff00db60),
      onColorContainer: Color(0xff005a23),
    ),
    lightHighContrast: ColorFamily(
      color: Color(0xff006e2c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xff00db60),
      onColorContainer: Color(0xff005a23),
    ),
    dark: ColorFamily(
      color: Color(0xff43f879),
      onColor: Color(0xff003913),
      colorContainer: Color(0xff00db60),
      onColorContainer: Color(0xff005a23),
    ),
    darkMediumContrast: ColorFamily(
      color: Color(0xff43f879),
      onColor: Color(0xff003913),
      colorContainer: Color(0xff00db60),
      onColorContainer: Color(0xff005a23),
    ),
    darkHighContrast: ColorFamily(
      color: Color(0xff43f879),
      onColor: Color(0xff003913),
      colorContainer: Color(0xff00db60),
      onColorContainer: Color(0xff005a23),
    ),
  );

  /// danger
  static const danger = ExtendedColor(
    seed: Color(0xffff4136),
    value: Color(0xffff4136),
    light: ColorFamily(
      color: Color(0xffbb020c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffe02923),
      onColorContainer: Color(0xfffffbff),
    ),
    lightMediumContrast: ColorFamily(
      color: Color(0xffbb020c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffe02923),
      onColorContainer: Color(0xfffffbff),
    ),
    lightHighContrast: ColorFamily(
      color: Color(0xffbb020c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffe02923),
      onColorContainer: Color(0xfffffbff),
    ),
    dark: ColorFamily(
      color: Color(0xffffb4aa),
      onColor: Color(0xff690003),
      colorContainer: Color(0xffff5446),
      onColorContainer: Color(0xff4f0002),
    ),
    darkMediumContrast: ColorFamily(
      color: Color(0xffffb4aa),
      onColor: Color(0xff690003),
      colorContainer: Color(0xffff5446),
      onColorContainer: Color(0xff4f0002),
    ),
    darkHighContrast: ColorFamily(
      color: Color(0xffffb4aa),
      onColor: Color(0xff690003),
      colorContainer: Color(0xffff5446),
      onColorContainer: Color(0xff4f0002),
    ),
  );

  /// warning
  static const warning = ExtendedColor(
    seed: Color(0xffff851b),
    value: Color(0xffff851b),
    light: ColorFamily(
      color: Color(0xff964900),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffff851b),
      onColorContainer: Color(0xff612d00),
    ),
    lightMediumContrast: ColorFamily(
      color: Color(0xff964900),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffff851b),
      onColorContainer: Color(0xff612d00),
    ),
    lightHighContrast: ColorFamily(
      color: Color(0xff964900),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffff851b),
      onColorContainer: Color(0xff612d00),
    ),
    dark: ColorFamily(
      color: Color(0xffffb787),
      onColor: Color(0xff502400),
      colorContainer: Color(0xffff851b),
      onColorContainer: Color(0xff612d00),
    ),
    darkMediumContrast: ColorFamily(
      color: Color(0xffffb787),
      onColor: Color(0xff502400),
      colorContainer: Color(0xffff851b),
      onColorContainer: Color(0xff612d00),
    ),
    darkHighContrast: ColorFamily(
      color: Color(0xffffb787),
      onColor: Color(0xff502400),
      colorContainer: Color(0xffff851b),
      onColorContainer: Color(0xff612d00),
    ),
  );

  List<ExtendedColor> get extendedColors => [success, danger, warning];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
