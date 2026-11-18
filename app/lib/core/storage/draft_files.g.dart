// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_files.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the unsent comments and description edits are kept: files in the
/// accounts folder, which iOS backups leave out (D66), while the
/// preferences go into them.

@ProviderFor(draftStore)
final draftStoreProvider = DraftStoreProvider._();

/// Where the unsent comments and description edits are kept: files in the
/// accounts folder, which iOS backups leave out (D66), while the
/// preferences go into them.

final class DraftStoreProvider
    extends
        $FunctionalProvider<
          PreferencesStore,
          PreferencesStore,
          PreferencesStore
        >
    with $Provider<PreferencesStore> {
  /// Where the unsent comments and description edits are kept: files in the
  /// accounts folder, which iOS backups leave out (D66), while the
  /// preferences go into them.
  DraftStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftStoreHash();

  @$internal
  @override
  $ProviderElement<PreferencesStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PreferencesStore create(Ref ref) {
    return draftStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreferencesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreferencesStore>(value),
    );
  }
}

String _$draftStoreHash() => r'68cd6049f425806d7b4d7c2eede3f14f6d53dd34';
