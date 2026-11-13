// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The device's theme, the same for every account and for guests; the
/// system's until it is read.

@ProviderFor(themeMode)
final themeModeProvider = ThemeModeProvider._();

/// The device's theme, the same for every account and for guests; the
/// system's until it is read.

final class ThemeModeProvider
    extends $FunctionalProvider<ThemeMode, ThemeMode, ThemeMode>
    with $Provider<ThemeMode> {
  /// The device's theme, the same for every account and for guests; the
  /// system's until it is read.
  ThemeModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeHash();

  @$internal
  @override
  $ProviderElement<ThemeMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeMode create(Ref ref) {
    return themeMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeHash() => r'e130875307eec9381944c7c3f12ee8ce2f82ebf4';

/// The device-wide light, dark or system theme, the system's unless
/// another was picked.

@ProviderFor(ThemeChoice)
final themeChoiceProvider = ThemeChoiceProvider._();

/// The device-wide light, dark or system theme, the system's unless
/// another was picked.
final class ThemeChoiceProvider
    extends $AsyncNotifierProvider<ThemeChoice, ThemeMode> {
  /// The device-wide light, dark or system theme, the system's unless
  /// another was picked.
  ThemeChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeChoiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeChoiceHash();

  @$internal
  @override
  ThemeChoice create() => ThemeChoice();
}

String _$themeChoiceHash() => r'af9b6ca8bad8d5d838d847b45f44042eada61913';

/// The device-wide light, dark or system theme, the system's unless
/// another was picked.

abstract class _$ThemeChoice extends $AsyncNotifier<ThemeMode> {
  FutureOr<ThemeMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The palette Android 12 and later derive from the wallpaper, as light
/// and dark schemes; null on other platforms and older versions. Read
/// again whenever the app comes back to the front, as the wallpaper may
/// have changed meanwhile.

@ProviderFor(SystemColors)
final systemColorsProvider = SystemColorsProvider._();

/// The palette Android 12 and later derive from the wallpaper, as light
/// and dark schemes; null on other platforms and older versions. Read
/// again whenever the app comes back to the front, as the wallpaper may
/// have changed meanwhile.
final class SystemColorsProvider
    extends $AsyncNotifierProvider<SystemColors, ColorSchemes?> {
  /// The palette Android 12 and later derive from the wallpaper, as light
  /// and dark schemes; null on other platforms and older versions. Read
  /// again whenever the app comes back to the front, as the wallpaper may
  /// have changed meanwhile.
  SystemColorsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemColorsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemColorsHash();

  @$internal
  @override
  SystemColors create() => SystemColors();
}

String _$systemColorsHash() => r'36bcb60813a95d3bf107bbf3c8894a1044c1b876';

/// The palette Android 12 and later derive from the wallpaper, as light
/// and dark schemes; null on other platforms and older versions. Read
/// again whenever the app comes back to the front, as the wallpaper may
/// have changed meanwhile.

abstract class _$SystemColors extends $AsyncNotifier<ColorSchemes?> {
  FutureOr<ColorSchemes?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ColorSchemes?>, ColorSchemes?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ColorSchemes?>, ColorSchemes?>,
              AsyncValue<ColorSchemes?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The device-wide "Use system colours" switch, on unless turned off.

@ProviderFor(UseSystemColors)
final useSystemColorsProvider = UseSystemColorsProvider._();

/// The device-wide "Use system colours" switch, on unless turned off.
final class UseSystemColorsProvider
    extends $AsyncNotifierProvider<UseSystemColors, bool> {
  /// The device-wide "Use system colours" switch, on unless turned off.
  UseSystemColorsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'useSystemColorsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$useSystemColorsHash();

  @$internal
  @override
  UseSystemColors create() => UseSystemColors();
}

String _$useSystemColorsHash() => r'e1869966896569dcb8021b5b5f41cd72961b9fc5';

/// The device-wide "Use system colours" switch, on unless turned off.

abstract class _$UseSystemColors extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The schemes the themes use instead of the brand blue; null for the
/// brand blue.

@ProviderFor(appColorSchemes)
final appColorSchemesProvider = AppColorSchemesProvider._();

/// The schemes the themes use instead of the brand blue; null for the
/// brand blue.

final class AppColorSchemesProvider
    extends $FunctionalProvider<ColorSchemes?, ColorSchemes?, ColorSchemes?>
    with $Provider<ColorSchemes?> {
  /// The schemes the themes use instead of the brand blue; null for the
  /// brand blue.
  AppColorSchemesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appColorSchemesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appColorSchemesHash();

  @$internal
  @override
  $ProviderElement<ColorSchemes?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ColorSchemes? create(Ref ref) {
    return appColorSchemes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ColorSchemes? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ColorSchemes?>(value),
    );
  }
}

String _$appColorSchemesHash() => r'4c27e8410c2023e97e8fd8041cc6f0db8f27623d';
