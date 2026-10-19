// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bucket_repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountBucketRepository)
final accountBucketRepositoryProvider = AccountBucketRepositoryFamily._();

final class AccountBucketRepositoryProvider
    extends
        $FunctionalProvider<
          BucketRepository,
          BucketRepository,
          BucketRepository
        >
    with $Provider<BucketRepository> {
  AccountBucketRepositoryProvider._({
    required AccountBucketRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountBucketRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountBucketRepositoryHash();

  @override
  String toString() {
    return r'accountBucketRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<BucketRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BucketRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountBucketRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BucketRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BucketRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountBucketRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountBucketRepositoryHash() =>
    r'71c26ebfce4eecc051486c10d473506f6c7f7804';

final class AccountBucketRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<BucketRepository, String> {
  AccountBucketRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountBucketRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountBucketRepositoryProvider call(String accountId) =>
      AccountBucketRepositoryProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountBucketRepositoryProvider';
}

/// The active account's; null while nobody is signed in.

@ProviderFor(bucketRepository)
final bucketRepositoryProvider = BucketRepositoryProvider._();

/// The active account's; null while nobody is signed in.

final class BucketRepositoryProvider
    extends
        $FunctionalProvider<
          BucketRepository?,
          BucketRepository?,
          BucketRepository?
        >
    with $Provider<BucketRepository?> {
  /// The active account's; null while nobody is signed in.
  BucketRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bucketRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bucketRepositoryHash();

  @$internal
  @override
  $ProviderElement<BucketRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BucketRepository? create(Ref ref) {
    return bucketRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BucketRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BucketRepository?>(value),
    );
  }
}

String _$bucketRepositoryHash() => r'86845af267fe230dca44978f5bac452c61de9e00';
