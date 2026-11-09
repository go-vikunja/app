// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trashRepositoryFor)
final trashRepositoryForProvider = TrashRepositoryForFamily._();

final class TrashRepositoryForProvider
    extends
        $FunctionalProvider<TrashRepository, TrashRepository, TrashRepository>
    with $Provider<TrashRepository> {
  TrashRepositoryForProvider._({
    required TrashRepositoryForFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'trashRepositoryForProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trashRepositoryForHash();

  @override
  String toString() {
    return r'trashRepositoryForProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TrashRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrashRepository create(Ref ref) {
    final argument = this.argument as String;
    return trashRepositoryFor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrashRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrashRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TrashRepositoryForProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trashRepositoryForHash() =>
    r'c3a35f6f6c8da12875a5201c18ebb3f2e88d0a69';

final class TrashRepositoryForFamily extends $Family
    with $FunctionalFamilyOverride<TrashRepository, String> {
  TrashRepositoryForFamily._()
    : super(
        retry: null,
        name: r'trashRepositoryForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TrashRepositoryForProvider call(String accountId) =>
      TrashRepositoryForProvider._(argument: accountId, from: this);

  @override
  String toString() => r'trashRepositoryForProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(trashRepository)
final trashRepositoryProvider = TrashRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class TrashRepositoryProvider
    extends
        $FunctionalProvider<
          TrashRepository?,
          TrashRepository?,
          TrashRepository?
        >
    with $Provider<TrashRepository?> {
  /// The active account's; null while nobody is signed in.
  TrashRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrashRepository?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrashRepository? create(Ref ref) {
    return trashRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrashRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrashRepository?>(value),
    );
  }
}

String _$trashRepositoryHash() => r'0718b8ba2fca5cc4f81f032a1f478474ad3aed5f';

/// Whether the active account's server has a trash (Vikunja 2.8.0 and
/// later on `/api/v2`); false while nobody is signed in. Every mention of
/// the bin, the Undo of a delete and the bin page depend on it.

@ProviderFor(activeServerHasTrash)
final activeServerHasTrashProvider = ActiveServerHasTrashProvider._();

/// Whether the active account's server has a trash (Vikunja 2.8.0 and
/// later on `/api/v2`); false while nobody is signed in. Every mention of
/// the bin, the Undo of a delete and the bin page depend on it.

final class ActiveServerHasTrashProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the active account's server has a trash (Vikunja 2.8.0 and
  /// later on `/api/v2`); false while nobody is signed in. Every mention of
  /// the bin, the Undo of a delete and the bin page depend on it.
  ActiveServerHasTrashProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeServerHasTrashProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeServerHasTrashHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return activeServerHasTrash(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$activeServerHasTrashHash() =>
    r'b431280251de5e78b015959d1ecdac89f4685612';
