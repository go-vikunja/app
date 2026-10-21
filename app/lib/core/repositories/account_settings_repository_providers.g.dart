// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_settings_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountSettingsRepositoryFor)
final accountSettingsRepositoryForProvider =
    AccountSettingsRepositoryForFamily._();

final class AccountSettingsRepositoryForProvider
    extends
        $FunctionalProvider<
          AccountSettingsRepository,
          AccountSettingsRepository,
          AccountSettingsRepository
        >
    with $Provider<AccountSettingsRepository> {
  AccountSettingsRepositoryForProvider._({
    required AccountSettingsRepositoryForFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountSettingsRepositoryForProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountSettingsRepositoryForHash();

  @override
  String toString() {
    return r'accountSettingsRepositoryForProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountSettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountSettingsRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountSettingsRepositoryFor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSettingsRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountSettingsRepositoryForProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountSettingsRepositoryForHash() =>
    r'57cdf362ead0e080ed4ee6b09f164f84077f8f97';

final class AccountSettingsRepositoryForFamily extends $Family
    with $FunctionalFamilyOverride<AccountSettingsRepository, String> {
  AccountSettingsRepositoryForFamily._()
    : super(
        retry: null,
        name: r'accountSettingsRepositoryForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountSettingsRepositoryForProvider call(String accountId) =>
      AccountSettingsRepositoryForProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountSettingsRepositoryForProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(accountSettingsRepository)
final accountSettingsRepositoryProvider = AccountSettingsRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class AccountSettingsRepositoryProvider
    extends
        $FunctionalProvider<
          AccountSettingsRepository?,
          AccountSettingsRepository?,
          AccountSettingsRepository?
        >
    with $Provider<AccountSettingsRepository?> {
  /// The active account's; null while nobody is signed in.
  AccountSettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSettingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSettingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountSettingsRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountSettingsRepository? create(Ref ref) {
    return accountSettingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSettingsRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSettingsRepository?>(value),
    );
  }
}

String _$accountSettingsRepositoryHash() =>
    r'c641ba4d4c51a9e77ba4c7aad2b4c762ad74f494';

/// The active account's settings, profile and avatar provider as stored;
/// empty while nobody is signed in.

@ProviderFor(accountSettings)
final accountSettingsProvider = AccountSettingsProvider._();

/// The active account's settings, profile and avatar provider as stored;
/// empty while nobody is signed in.

final class AccountSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountSettingsState>,
          AccountSettingsState,
          Stream<AccountSettingsState>
        >
    with
        $FutureModifier<AccountSettingsState>,
        $StreamProvider<AccountSettingsState> {
  /// The active account's settings, profile and avatar provider as stored;
  /// empty while nobody is signed in.
  AccountSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSettingsHash();

  @$internal
  @override
  $StreamProviderElement<AccountSettingsState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AccountSettingsState> create(Ref ref) {
    return accountSettings(ref);
  }
}

String _$accountSettingsHash() => r'ded879e540a27496bcd0f28fae84b3cc560091dd';
