// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_backgrounding.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appBackgrounding)
final appBackgroundingProvider = AppBackgroundingProvider._();

final class AppBackgroundingProvider
    extends
        $FunctionalProvider<
          AppBackgrounding,
          AppBackgrounding,
          AppBackgrounding
        >
    with $Provider<AppBackgrounding> {
  AppBackgroundingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBackgroundingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBackgroundingHash();

  @$internal
  @override
  $ProviderElement<AppBackgrounding> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppBackgrounding create(Ref ref) {
    return appBackgrounding(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppBackgrounding value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppBackgrounding>(value),
    );
  }
}

String _$appBackgroundingHash() => r'a2bb31c738944613c8719f0c469807b13e871021';
