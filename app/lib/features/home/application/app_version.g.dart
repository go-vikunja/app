// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's version and build number, as it reports itself to servers.

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// The app's version and build number, as it reports itself to servers.

final class AppVersionProvider
    extends $FunctionalProvider<AppVersion, AppVersion, AppVersion>
    with $Provider<AppVersion> {
  /// The app's version and build number, as it reports itself to servers.
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $ProviderElement<AppVersion> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppVersion create(Ref ref) {
    return appVersion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppVersion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppVersion>(value),
    );
  }
}

String _$appVersionHash() => r'460ebb6c8e3ab10c0cbc3618c060c0cb2aff42fc';
