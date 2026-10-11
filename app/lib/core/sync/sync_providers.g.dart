// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One account's sync status: loading until its engine has reported. Kept
/// alive, so that once its engine has reported, an account that becomes
/// active has its status at once.

@ProviderFor(accountSyncStatus)
final accountSyncStatusProvider = AccountSyncStatusFamily._();

/// One account's sync status: loading until its engine has reported. Kept
/// alive, so that once its engine has reported, an account that becomes
/// active has its status at once.

final class AccountSyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus>,
          SyncStatus,
          Stream<SyncStatus>
        >
    with $FutureModifier<SyncStatus>, $StreamProvider<SyncStatus> {
  /// One account's sync status: loading until its engine has reported. Kept
  /// alive, so that once its engine has reported, an account that becomes
  /// active has its status at once.
  AccountSyncStatusProvider._({
    required AccountSyncStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountSyncStatusProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountSyncStatusHash();

  @override
  String toString() {
    return r'accountSyncStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<SyncStatus> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SyncStatus> create(Ref ref) {
    final argument = this.argument as String;
    return accountSyncStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountSyncStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountSyncStatusHash() => r'5945a68d49c5b2b8364ab61455fcd6f6c2f6c0b8';

/// One account's sync status: loading until its engine has reported. Kept
/// alive, so that once its engine has reported, an account that becomes
/// active has its status at once.

final class AccountSyncStatusFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SyncStatus>, String> {
  AccountSyncStatusFamily._()
    : super(
        retry: null,
        name: r'accountSyncStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One account's sync status: loading until its engine has reported. Kept
  /// alive, so that once its engine has reported, an account that becomes
  /// active has its status at once.

  AccountSyncStatusProvider call(String accountId) =>
      AccountSyncStatusProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountSyncStatusProvider';
}

/// The sync status of the active account: loading until its engine has
/// reported, and forever while nobody is signed in. Never the previous
/// account's status, nor that of an engine a sign-out replaced, which a
/// reloading provider would otherwise carry as its value.

@ProviderFor(syncStatus)
final syncStatusProvider = SyncStatusProvider._();

/// The sync status of the active account: loading until its engine has
/// reported, and forever while nobody is signed in. Never the previous
/// account's status, nor that of an engine a sign-out replaced, which a
/// reloading provider would otherwise carry as its value.

final class SyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus>,
          AsyncValue<SyncStatus>,
          AsyncValue<SyncStatus>
        >
    with $Provider<AsyncValue<SyncStatus>> {
  /// The sync status of the active account: loading until its engine has
  /// reported, and forever while nobody is signed in. Never the previous
  /// account's status, nor that of an engine a sign-out replaced, which a
  /// reloading provider would otherwise carry as its value.
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
  $ProviderElement<AsyncValue<SyncStatus>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<SyncStatus> create(Ref ref) {
    return syncStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<SyncStatus> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<SyncStatus>>(value),
    );
  }
}

String _$syncStatusHash() => r'ddca395eac6a9787ec75a7ff8ed5ac374849c536';
