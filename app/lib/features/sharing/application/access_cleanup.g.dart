// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'access_cleanup.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [serverCleansUpAccess] for the active account's server.

@ProviderFor(activeServerCleansUpAccess)
final activeServerCleansUpAccessProvider =
    ActiveServerCleansUpAccessProvider._();

/// [serverCleansUpAccess] for the active account's server.

final class ActiveServerCleansUpAccessProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// [serverCleansUpAccess] for the active account's server.
  ActiveServerCleansUpAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeServerCleansUpAccessProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeServerCleansUpAccessHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return activeServerCleansUpAccess(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$activeServerCleansUpAccessHash() =>
    r'331acdd722d49b86ce7bb59cf1b77c60de4fc2e7';
