// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_switcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountSwitcher)
final accountSwitcherProvider = AccountSwitcherProvider._();

final class AccountSwitcherProvider
    extends
        $FunctionalProvider<AccountSwitcher, AccountSwitcher, AccountSwitcher>
    with $Provider<AccountSwitcher> {
  AccountSwitcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSwitcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSwitcherHash();

  @$internal
  @override
  $ProviderElement<AccountSwitcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountSwitcher create(Ref ref) {
    return accountSwitcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountSwitcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSwitcher>(value),
    );
  }
}

String _$accountSwitcherHash() => r'c6724e73bce6b193df8f3af77f8c13f40ae6f9d4';

/// The queued changes of one account, active or not; opens its database.

@ProviderFor(accountPendingChanges)
final accountPendingChangesProvider = AccountPendingChangesFamily._();

/// The queued changes of one account, active or not; opens its database.

final class AccountPendingChangesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// The queued changes of one account, active or not; opens its database.
  AccountPendingChangesProvider._({
    required AccountPendingChangesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountPendingChangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountPendingChangesHash();

  @override
  String toString() {
    return r'accountPendingChangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as String;
    return accountPendingChanges(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountPendingChangesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountPendingChangesHash() =>
    r'555f2345488b8b922d672064dfdbf4aad490441c';

/// The queued changes of one account, active or not; opens its database.

final class AccountPendingChangesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, String> {
  AccountPendingChangesFamily._()
    : super(
        retry: null,
        name: r'accountPendingChangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The queued changes of one account, active or not; opens its database.

  AccountPendingChangesProvider call(String accountId) =>
      AccountPendingChangesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountPendingChangesProvider';
}
