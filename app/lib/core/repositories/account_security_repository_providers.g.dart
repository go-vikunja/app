// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_security_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountSecurityRepositoryFor)
final accountSecurityRepositoryForProvider =
    AccountSecurityRepositoryForFamily._();

final class AccountSecurityRepositoryForProvider
    extends
        $FunctionalProvider<
          AccountSecurityRepository,
          AccountSecurityRepository,
          AccountSecurityRepository
        >
    with $Provider<AccountSecurityRepository> {
  AccountSecurityRepositoryForProvider._({
    required AccountSecurityRepositoryForFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountSecurityRepositoryForProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountSecurityRepositoryForHash();

  @override
  String toString() {
    return r'accountSecurityRepositoryForProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountSecurityRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountSecurityRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountSecurityRepositoryFor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSecurityRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSecurityRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountSecurityRepositoryForProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountSecurityRepositoryForHash() =>
    r'b5c8d876b353efc20d218a9a0e351be61c75cc17';

final class AccountSecurityRepositoryForFamily extends $Family
    with $FunctionalFamilyOverride<AccountSecurityRepository, String> {
  AccountSecurityRepositoryForFamily._()
    : super(
        retry: null,
        name: r'accountSecurityRepositoryForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountSecurityRepositoryForProvider call(String accountId) =>
      AccountSecurityRepositoryForProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountSecurityRepositoryForProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(accountSecurityRepository)
final accountSecurityRepositoryProvider = AccountSecurityRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class AccountSecurityRepositoryProvider
    extends
        $FunctionalProvider<
          AccountSecurityRepository?,
          AccountSecurityRepository?,
          AccountSecurityRepository?
        >
    with $Provider<AccountSecurityRepository?> {
  /// The active account's; null while nobody is signed in.
  AccountSecurityRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSecurityRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSecurityRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountSecurityRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountSecurityRepository? create(Ref ref) {
    return accountSecurityRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSecurityRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSecurityRepository?>(value),
    );
  }
}

String _$accountSecurityRepositoryHash() =>
    r'0e0b2182c8bf2877535ec50ee74745b6e7cf6f87';
