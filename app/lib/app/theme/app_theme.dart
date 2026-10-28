import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const seedColor = Color(0xFF1973FF);
  static const amberSeedColor = Color(0xFFF5AE39);

  /// Its neutral tones are the cool grey-blue of the owner's mockups; the
  /// brand seed's own lean towards violet.
  static const _neutralSeedColor = Color(0xFF4285C8);

  /// The platform's monospace face: no font asset ships with the app.
  static const monospace = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Courier New', 'Courier'],
  );

  /// [colorScheme] replaces the brand colours, e.g. with the system's.
  static ThemeData light({ColorScheme? colorScheme}) => _build(
    colorScheme ?? brandScheme(Brightness.light),
    brand: colorScheme == null,
  );

  static ThemeData dark({ColorScheme? colorScheme}) => _build(
    colorScheme ?? brandScheme(Brightness.dark),
    brand: colorScheme == null,
  );

  /// When the platform asks for more contrast: the brand scheme at full
  /// contrast, or with [colorScheme] (the system's) a scheme from its
  /// primary, which keeps the user's hue.
  static ThemeData highContrastLight({ColorScheme? colorScheme}) =>
      _highContrast(Brightness.light, colorScheme);

  static ThemeData highContrastDark({ColorScheme? colorScheme}) =>
      _highContrast(Brightness.dark, colorScheme);

  static ThemeData _highContrast(Brightness brightness, ColorScheme? system) =>
      _build(
        system == null
            ? brandScheme(brightness, contrastLevel: 1)
            : ColorScheme.fromSeed(
                seedColor: system.primary,
                brightness: brightness,
                contrastLevel: 1,
              ),
        brand: system == null,
      );

  /// The seed's vibrant tones for the primary roles, its calmer tonal-spot
  /// ones for the secondary roles (the vibrant variant turns them violet)
  /// and an amber tertiary.
  static ColorScheme brandScheme(
    Brightness brightness, {
    double contrastLevel = 0,
  }) {
    ColorScheme seeded(Color seed, DynamicSchemeVariant variant) =>
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          dynamicSchemeVariant: variant,
          contrastLevel: contrastLevel,
        );
    final blue = seeded(seedColor, DynamicSchemeVariant.vibrant);
    final calm = seeded(seedColor, DynamicSchemeVariant.tonalSpot);
    final amber = seeded(amberSeedColor, DynamicSchemeVariant.fidelity);
    return seeded(_neutralSeedColor, DynamicSchemeVariant.vibrant).copyWith(
      primary: blue.primary,
      onPrimary: blue.onPrimary,
      primaryContainer: blue.primaryContainer,
      onPrimaryContainer: blue.onPrimaryContainer,
      primaryFixed: blue.primaryFixed,
      primaryFixedDim: blue.primaryFixedDim,
      onPrimaryFixed: blue.onPrimaryFixed,
      onPrimaryFixedVariant: blue.onPrimaryFixedVariant,
      inversePrimary: blue.inversePrimary,
      surfaceTint: blue.surfaceTint,
      secondary: calm.secondary,
      onSecondary: calm.onSecondary,
      secondaryContainer: calm.secondaryContainer,
      onSecondaryContainer: calm.onSecondaryContainer,
      secondaryFixed: calm.secondaryFixed,
      secondaryFixedDim: calm.secondaryFixedDim,
      onSecondaryFixed: calm.onSecondaryFixed,
      onSecondaryFixedVariant: calm.onSecondaryFixedVariant,
      tertiary: amber.primary,
      onTertiary: amber.onPrimary,
      tertiaryContainer: amber.primaryContainer,
      onTertiaryContainer: amber.onPrimaryContainer,
      tertiaryFixed: amber.primaryFixed,
      tertiaryFixedDim: amber.primaryFixedDim,
      onTertiaryFixed: amber.onPrimaryFixed,
      onTertiaryFixedVariant: amber.onPrimaryFixedVariant,
    );
  }

  /// Only what differs from the Material 3 defaults, which already give
  /// the mockups' app bars, FAB, chips, checkboxes, segmented buttons,
  /// dividers, menus, list tile icons, tabs and progress bars.
  static ThemeData _build(ColorScheme colors, {required bool brand}) {
    final base = ThemeData(colorScheme: colors);
    final text = base.textTheme;
    final selectedLabel = text.labelMedium?.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w700,
    );
    final unselectedLabel = text.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return base.copyWith(
      extensions: [HighlightColors.fromScheme(colors, brand: brand)],
      // Without it a scrolled-under app bar is tinted with the primary
      // colour on top of surfaceContainer, unlike the navigation bar below.
      appBarTheme: const AppBarThemeData(surfaceTintColor: Colors.transparent),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? selectedLabel
              : unselectedLabel,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainer,
        selectedLabelTextStyle: selectedLabel,
        unselectedLabelTextStyle: unselectedLabel,
      ),
      // The adaptive switches are CupertinoSwitches on Apple platforms,
      // which have no thumb icon.
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check)
              : null,
        ),
      ),
      // Colour and shape stay with the variant: Card.filled and
      // Card.outlined bring their own.
      cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainer,
        modalBackgroundColor: colors.surfaceContainer,
        showDragHandle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
    );
  }
}

/// The accent of a favourite's star and of a high priority: the brand's
/// amber, or the tertiary colour of a scheme from the system, whose
/// tertiary container is too pale to fill a small icon.
@immutable
final class HighlightColors extends ThemeExtension<HighlightColors> {
  const new({required this.highlight, required this.onHighlight});

  factory fromScheme(ColorScheme colors, {required bool brand}) => brand
      ? HighlightColors(
          highlight: colors.tertiaryContainer,
          onHighlight: colors.onTertiaryContainer,
        )
      : HighlightColors(
          highlight: colors.tertiary,
          onHighlight: colors.onTertiary,
        );

  factory of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HighlightColors>() ??
        HighlightColors.fromScheme(theme.colorScheme, brand: false);
  }

  /// For icons and fills, not for text on a surface: that takes
  /// `ColorScheme.tertiary`.
  final Color highlight;
  final Color onHighlight;

  @override
  HighlightColors copyWith({Color? highlight, Color? onHighlight}) =>
      HighlightColors(
        highlight: highlight ?? this.highlight,
        onHighlight: onHighlight ?? this.onHighlight,
      );

  @override
  HighlightColors lerp(HighlightColors? other, double t) => other == null
      ? this
      : HighlightColors(
          highlight: Color.lerp(highlight, other.highlight, t)!,
          onHighlight: Color.lerp(onHighlight, other.onHighlight, t)!,
        );
}
