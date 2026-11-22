// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_settings.dart';

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

/// The device-wide "Use system colours" switch, off until turned on.

@ProviderFor(UseSystemColors)
final useSystemColorsProvider = UseSystemColorsProvider._();

/// The device-wide "Use system colours" switch, off until turned on.
final class UseSystemColorsProvider
    extends $AsyncNotifierProvider<UseSystemColors, bool> {
  /// The device-wide "Use system colours" switch, off until turned on.
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

String _$useSystemColorsHash() => r'5d16e4a92a60b98ef791af318cd298bce3345ac7';

/// The device-wide "Use system colours" switch, off until turned on.

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
