// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The sync status of the active account: loading until its engine has
/// reported, and forever while nobody is signed in. Its `value` is null
/// before the first report; during an account switch it stays the previous
/// account's until the new engine reports, so a switch between two synced
/// accounts never passes through the first-sync screen.

@ProviderFor(syncStatus)
final syncStatusProvider = SyncStatusProvider._();

/// The sync status of the active account: loading until its engine has
/// reported, and forever while nobody is signed in. Its `value` is null
/// before the first report; during an account switch it stays the previous
/// account's until the new engine reports, so a switch between two synced
/// accounts never passes through the first-sync screen.

final class SyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus>,
          SyncStatus,
          Stream<SyncStatus>
        >
    with $FutureModifier<SyncStatus>, $StreamProvider<SyncStatus> {
  /// The sync status of the active account: loading until its engine has
  /// reported, and forever while nobody is signed in. Its `value` is null
  /// before the first report; during an account switch it stays the previous
  /// account's until the new engine reports, so a switch between two synced
  /// accounts never passes through the first-sync screen.
  SyncStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @$internal
  @override
  $StreamProviderElement<SyncStatus> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SyncStatus> create(Ref ref) {
    return syncStatus(ref);
  }
}

String _$syncStatusHash() => r'a37a7ae6757cad6d792e18732bcdbd0b91517974';
