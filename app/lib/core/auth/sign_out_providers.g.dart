// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountDeletions)
final accountDeletionsProvider = AccountDeletionsProvider._();

final class AccountDeletionsProvider
    extends
        $FunctionalProvider<
          AccountDeletions,
          AccountDeletions,
          AccountDeletions
        >
    with $Provider<AccountDeletions> {
  AccountDeletionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionsHash();

  @$internal
  @override
  $ProviderElement<AccountDeletions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountDeletions create(Ref ref) {
    return accountDeletions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDeletions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDeletions>(value),
    );
  }
}

String _$accountDeletionsHash() => r'5b1d70ee629d4ec43b3b533a514d4d41da6e9ce5';

@ProviderFor(signOut)
final signOutProvider = SignOutProvider._();

final class SignOutProvider
    extends $FunctionalProvider<SignOut, SignOut, SignOut>
    with $Provider<SignOut> {
  SignOutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signOutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signOutHash();

  @$internal
  @override
  $ProviderElement<SignOut> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SignOut create(Ref ref) {
    return signOut(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SignOut value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SignOut>(value),
    );
  }
}

String _$signOutHash() => r'e1df79231ce00d7798edb25c968b9aacc00611e5';
