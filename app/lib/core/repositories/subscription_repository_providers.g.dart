// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountSubscriptionRepository)
final accountSubscriptionRepositoryProvider =
    AccountSubscriptionRepositoryFamily._();

final class AccountSubscriptionRepositoryProvider
    extends
        $FunctionalProvider<
          SubscriptionRepository,
          SubscriptionRepository,
          SubscriptionRepository
        >
    with $Provider<SubscriptionRepository> {
  AccountSubscriptionRepositoryProvider._({
    required AccountSubscriptionRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountSubscriptionRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountSubscriptionRepositoryHash();

  @override
  String toString() {
    return r'accountSubscriptionRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SubscriptionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscriptionRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountSubscriptionRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriptionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriptionRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountSubscriptionRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountSubscriptionRepositoryHash() =>
    r'ad52d3fe6a0ff6ddde0a21723c33906b2d489f80';

final class AccountSubscriptionRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<SubscriptionRepository, String> {
  AccountSubscriptionRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountSubscriptionRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountSubscriptionRepositoryProvider call(String accountId) =>
      AccountSubscriptionRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountSubscriptionRepositoryProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(subscriptionRepository)
final subscriptionRepositoryProvider = SubscriptionRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class SubscriptionRepositoryProvider
    extends
        $FunctionalProvider<
          SubscriptionRepository?,
          SubscriptionRepository?,
          SubscriptionRepository?
        >
    with $Provider<SubscriptionRepository?> {
  /// The active account's; null while nobody is signed in.
  SubscriptionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionRepositoryHash();

  @$internal
  @override
  $ProviderElement<SubscriptionRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscriptionRepository? create(Ref ref) {
    return subscriptionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriptionRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriptionRepository?>(value),
    );
  }
}

String _$subscriptionRepositoryHash() =>
    r'75f949e383d126d87d7b6b626f257b3f7a200e7c';
