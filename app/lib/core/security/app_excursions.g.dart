// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_excursions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appExcursions)
final appExcursionsProvider = AppExcursionsProvider._();

final class AppExcursionsProvider
    extends $FunctionalProvider<AppExcursions, AppExcursions, AppExcursions>
    with $Provider<AppExcursions> {
  AppExcursionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appExcursionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appExcursionsHash();

  @$internal
  @override
  $ProviderElement<AppExcursions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppExcursions create(Ref ref) {
    return appExcursions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppExcursions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppExcursions>(value),
    );
  }
}

String _$appExcursionsHash() => r'52629177f95e57546359d2541b69945598705b41';
