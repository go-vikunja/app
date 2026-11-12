// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_permissions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backgroundPermissions)
final backgroundPermissionsProvider = BackgroundPermissionsProvider._();

final class BackgroundPermissionsProvider
    extends
        $FunctionalProvider<
          BackgroundPermissions,
          BackgroundPermissions,
          BackgroundPermissions
        >
    with $Provider<BackgroundPermissions> {
  BackgroundPermissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundPermissionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundPermissionsHash();

  @$internal
  @override
  $ProviderElement<BackgroundPermissions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundPermissions create(Ref ref) {
    return backgroundPermissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundPermissions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundPermissions>(value),
    );
  }
}

String _$backgroundPermissionsHash() =>
    r'01dd5f0ac429d493e568913bc5e2ab433a7756b3';
