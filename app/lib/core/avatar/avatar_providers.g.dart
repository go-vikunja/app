// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials.

@ProviderFor(accountAvatarCache)
final accountAvatarCacheProvider = AccountAvatarCacheFamily._();

/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials.

final class AccountAvatarCacheProvider
    extends $FunctionalProvider<AvatarCache, AvatarCache, AvatarCache>
    with $Provider<AvatarCache> {
  /// Read lazily: the sync engine keeps the account's read client alive, and
  /// without one (signed out, or in tests) every avatar is the initials.
  AccountAvatarCacheProvider._({
    required AccountAvatarCacheFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountAvatarCacheProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountAvatarCacheHash();

  @override
  String toString() {
    return r'accountAvatarCacheProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AvatarCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AvatarCache create(Ref ref) {
    final argument = this.argument as String;
    return accountAvatarCache(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AvatarCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AvatarCache>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountAvatarCacheProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountAvatarCacheHash() =>
    r'8e594e57687df608f6daf05df81e36b803b1773d';

/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials.

final class AccountAvatarCacheFamily extends $Family
    with $FunctionalFamilyOverride<AvatarCache, String> {
  AccountAvatarCacheFamily._()
    : super(
        retry: null,
        name: r'accountAvatarCacheProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Read lazily: the sync engine keeps the account's read client alive, and
  /// without one (signed out, or in tests) every avatar is the initials.

  AccountAvatarCacheProvider call(String accountId) =>
      AccountAvatarCacheProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountAvatarCacheProvider';
}
