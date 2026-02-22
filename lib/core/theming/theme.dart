import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff0055ce),
      surfaceTint: Color(0xff0056d1),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff126cfd),
      onPrimaryContainer: Color(0xfffffeff),
      secondary: Color(0xff435c9b),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffa1baff),
      onSecondaryContainer: Color(0xff2e4886),
      tertiary: Color(0xff9129b6),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffad47d1),
      onTertiaryContainer: Color(0xfffffeff),
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
      inverseSurface: Color(0xff2e3039),
      inversePrimary: Color(0xffb2c5ff),
      primaryFixed: Color(0xffdae2ff),
      onPrimaryFixed: Color(0xff001847),
      primaryFixedDim: Color(0xffb2c5ff),
      onPrimaryFixedVariant: Color(0xff0040a0),
      secondaryFixed: Color(0xffdae2ff),
      onSecondaryFixed: Color(0xff001847),
      secondaryFixedDim: Color(0xffb2c5ff),
      onSecondaryFixedVariant: Color(0xff2a4482),
      tertiaryFixed: Color(0xfffad7ff),
      onTertiaryFixed: Color(0xff330045),
      tertiaryFixedDim: Color(0xffefb0ff),
      onTertiaryFixedVariant: Color(0xff76009b),
      surfaceDim: Color(0xffd8d9e5),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff2f3ff),
      surfaceContainer: Color(0xffecedf9),
      surfaceContainerHigh: Color(0xffe6e7f4),
      surfaceContainerHighest: Color(0xffe1e2ee),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff00317e),
      surfaceTint: Color(0xff0056d1),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff0063f0),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff163370),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff526bab),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff5c007a),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffa33dc7),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff0e1119),
      onSurfaceVariant: Color(0xff313644),
      outline: Color(0xff4e5261),
      outlineVariant: Color(0xff686d7c),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2e3039),
      inversePrimary: Color(0xffb2c5ff),
      primaryFixed: Color(0xff0063f0),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff004dbd),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff526bab),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff395291),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xffa33dc7),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff871cac),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc4c6d2),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff2f3ff),
      surfaceContainer: Color(0xffe6e7f4),
      surfaceContainerHigh: Color(0xffdbdce8),
      surfaceContainerHighest: Color(0xffd0d1dd),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff002869),
      surfaceTint: Color(0xff0056d1),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff0042a5),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff062866),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff2c4784),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff4d0066),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff7a01a0),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff272c3a),
      outlineVariant: Color(0xff444958),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2e3039),
      inversePrimary: Color(0xffb2c5ff),
      primaryFixed: Color(0xff0042a5),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff002e77),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff2c4784),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff112f6c),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff7a01a0),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff570073),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb7b8c4),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeff0fc),
      surfaceContainer: Color(0xffe1e2ee),
      surfaceContainerHigh: Color(0xffd2d4e0),
      surfaceContainerHighest: Color(0xffc4c6d2),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffb2c5ff),
      surfaceTint: Color(0xffb2c5ff),
      onPrimary: Color(0xff002c72),
      primaryContainer: Color(0xff126cfd),
      onPrimaryContainer: Color(0xfffffeff),
      secondary: Color(0xffb2c5ff),
      onSecondary: Color(0xff0d2d6a),
      secondaryContainer: Color(0xff2a4482),
      onSecondaryContainer: Color(0xff9bb3f9),
      tertiary: Color(0xffefb0ff),
      onTertiary: Color(0xff53006e),
      tertiaryContainer: Color(0xffad47d1),
      onTertiaryContainer: Color(0xfffffeff),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff10131b),
      onSurface: Color(0xffe1e2ee),
      onSurfaceVariant: Color(0xffc2c6d8),
      outline: Color(0xff8c90a1),
      outlineVariant: Color(0xff424655),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2ee),
      inversePrimary: Color(0xff0056d1),
      primaryFixed: Color(0xffdae2ff),
      onPrimaryFixed: Color(0xff001847),
      primaryFixedDim: Color(0xffb2c5ff),
      onPrimaryFixedVariant: Color(0xff0040a0),
      secondaryFixed: Color(0xffdae2ff),
      onSecondaryFixed: Color(0xff001847),
      secondaryFixedDim: Color(0xffb2c5ff),
      onSecondaryFixedVariant: Color(0xff2a4482),
      tertiaryFixed: Color(0xfffad7ff),
      onTertiaryFixed: Color(0xff330045),
      tertiaryFixedDim: Color(0xffefb0ff),
      onTertiaryFixedVariant: Color(0xff76009b),
      surfaceDim: Color(0xff10131b),
      surfaceBright: Color(0xff363942),
      surfaceContainerLowest: Color(0xff0b0e16),
      surfaceContainerLow: Color(0xff191b24),
      surfaceContainer: Color(0xff1d1f28),
      surfaceContainerHigh: Color(0xff272a33),
      surfaceContainerHighest: Color(0xff32343e),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd1dbff),
      surfaceTint: Color(0xffb2c5ff),
      onPrimary: Color(0xff00225c),
      primaryContainer: Color(0xff5b8cff),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffd1dbff),
      onSecondary: Color(0xff00225c),
      secondaryContainer: Color(0xff768fd2),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xfff8cfff),
      onTertiary: Color(0xff430059),
      tertiaryContainer: Color(0xffcb64ef),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff10131b),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd8dbee),
      outline: Color(0xffadb1c3),
      outlineVariant: Color(0xff8c90a1),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2ee),
      inversePrimary: Color(0xff0041a3),
      primaryFixed: Color(0xffdae2ff),
      onPrimaryFixed: Color(0xff000f32),
      primaryFixedDim: Color(0xffb2c5ff),
      onPrimaryFixedVariant: Color(0xff00317e),
      secondaryFixed: Color(0xffdae2ff),
      onSecondaryFixed: Color(0xff000f32),
      secondaryFixedDim: Color(0xffb2c5ff),
      onSecondaryFixedVariant: Color(0xff163370),
      tertiaryFixed: Color(0xfffad7ff),
      onTertiaryFixed: Color(0xff230030),
      tertiaryFixedDim: Color(0xffefb0ff),
      onTertiaryFixedVariant: Color(0xff5c007a),
      surfaceDim: Color(0xff10131b),
      surfaceBright: Color(0xff42444e),
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
      surfaceTint: Color(0xffb2c5ff),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffacc1ff),
      onPrimaryContainer: Color(0xff000926),
      secondary: Color(0xffedefff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffacc1ff),
      onSecondaryContainer: Color(0xff000926),
      tertiary: Color(0xffffeaff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffedabff),
      onTertiaryContainer: Color(0xff190024),
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
      inverseSurface: Color(0xffe1e2ee),
      inversePrimary: Color(0xff0041a3),
      primaryFixed: Color(0xffdae2ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffb2c5ff),
      onPrimaryFixedVariant: Color(0xff000f32),
      secondaryFixed: Color(0xffdae2ff),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb2c5ff),
      onSecondaryFixedVariant: Color(0xff000f32),
      tertiaryFixed: Color(0xfffad7ff),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffefb0ff),
      onTertiaryFixedVariant: Color(0xff230030),
      surfaceDim: Color(0xff10131b),
      surfaceBright: Color(0xff4d505a),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1d1f28),
      surfaceContainer: Color(0xff2e3039),
      surfaceContainerHigh: Color(0xff393b44),
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
    scaffoldBackgroundColor: colorScheme.surface,
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
