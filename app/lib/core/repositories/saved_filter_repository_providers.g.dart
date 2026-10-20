// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_filter_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountSavedFilterRepository)
final accountSavedFilterRepositoryProvider =
    AccountSavedFilterRepositoryFamily._();

final class AccountSavedFilterRepositoryProvider
    extends
        $FunctionalProvider<
          SavedFilterRepository,
          SavedFilterRepository,
          SavedFilterRepository
        >
    with $Provider<SavedFilterRepository> {
  AccountSavedFilterRepositoryProvider._({
    required AccountSavedFilterRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountSavedFilterRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountSavedFilterRepositoryHash();

  @override
  String toString() {
    return r'accountSavedFilterRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SavedFilterRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedFilterRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountSavedFilterRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedFilterRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedFilterRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountSavedFilterRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountSavedFilterRepositoryHash() =>
    r'780cea875143457c421da58a69dcace90795ec6b';

final class AccountSavedFilterRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<SavedFilterRepository, String> {
  AccountSavedFilterRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountSavedFilterRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountSavedFilterRepositoryProvider call(String accountId) =>
      AccountSavedFilterRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountSavedFilterRepositoryProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(savedFilterRepository)
final savedFilterRepositoryProvider = SavedFilterRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class SavedFilterRepositoryProvider
    extends
        $FunctionalProvider<
          SavedFilterRepository?,
          SavedFilterRepository?,
          SavedFilterRepository?
        >
    with $Provider<SavedFilterRepository?> {
  /// The active account's; null while nobody is signed in.
  SavedFilterRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedFilterRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedFilterRepositoryHash();

  @$internal
  @override
  $ProviderElement<SavedFilterRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedFilterRepository? create(Ref ref) {
    return savedFilterRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedFilterRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedFilterRepository?>(value),
    );
  }
}

String _$savedFilterRepositoryHash() =>
    r'd8e28c1c01a87cf1c930d6e77092edeabae41cbd';
