// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'startup_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(startupSync)
final startupSyncProvider = StartupSyncProvider._();

final class StartupSyncProvider
    extends $FunctionalProvider<StartupSync, StartupSync, StartupSync>
    with $Provider<StartupSync> {
  StartupSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startupSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startupSyncHash();

  @$internal
  @override
  $ProviderElement<StartupSync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StartupSync create(Ref ref) {
    return startupSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StartupSync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StartupSync>(value),
    );
  }
}

String _$startupSyncHash() => r'29ff2726a3da498fbc4ff31a02524995244f907b';
