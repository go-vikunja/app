// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

String _$appColorSchemesHash() => r'cb703d0293499b8288646fc6a52521e07aa1bfb6';
