// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_language_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appLanguageSettings)
final appLanguageSettingsProvider = AppLanguageSettingsProvider._();

final class AppLanguageSettingsProvider
    extends
        $FunctionalProvider<
          AppLanguageSettings,
          AppLanguageSettings,
          AppLanguageSettings
        >
    with $Provider<AppLanguageSettings> {
  AppLanguageSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLanguageSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLanguageSettingsHash();

  @$internal
  @override
  $ProviderElement<AppLanguageSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppLanguageSettings create(Ref ref) {
    return appLanguageSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLanguageSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLanguageSettings>(value),
    );
  }
}

String _$appLanguageSettingsHash() =>
    r'58cd2cbfdc48e870cf6e96df4ee9acdff3e4d7a0';

/// False until [AppLanguageSettings.available] answered, and when it failed.

@ProviderFor(appLanguageSettingsAvailable)
final appLanguageSettingsAvailableProvider =
    AppLanguageSettingsAvailableProvider._();

/// False until [AppLanguageSettings.available] answered, and when it failed.

final class AppLanguageSettingsAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// False until [AppLanguageSettings.available] answered, and when it failed.
  AppLanguageSettingsAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLanguageSettingsAvailableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLanguageSettingsAvailableHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return appLanguageSettingsAvailable(ref);
  }
}

String _$appLanguageSettingsAvailableHash() =>
    r'23e6e7770e0e0cb40d423ee2df015ffabc043b73';
