// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials. The
/// sync tells it the user's `updated` (`AvatarCache.noteUpdated`).

@ProviderFor(accountAvatarCache)
final accountAvatarCacheProvider = AccountAvatarCacheFamily._();

/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials. The
/// sync tells it the user's `updated` (`AvatarCache.noteUpdated`).

final class AccountAvatarCacheProvider
    extends $FunctionalProvider<AvatarCache, AvatarCache, AvatarCache>
    with $Provider<AvatarCache> {
  /// Read lazily: the sync engine keeps the account's read client alive, and
  /// without one (signed out, or in tests) every avatar is the initials. The
  /// sync tells it the user's `updated` (`AvatarCache.noteUpdated`).
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
    r'92eaf23fd89d1e8d082a169ac7b19fb6a096bd81';

/// Read lazily: the sync engine keeps the account's read client alive, and
/// without one (signed out, or in tests) every avatar is the initials. The
/// sync tells it the user's `updated` (`AvatarCache.noteUpdated`).

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
  /// without one (signed out, or in tests) every avatar is the initials. The
  /// sync tells it the user's `updated` (`AvatarCache.noteUpdated`).

  AccountAvatarCacheProvider call(String accountId) =>
      AccountAvatarCacheProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountAvatarCacheProvider';
}

/// [AvatarCache.generationOf] the user in the account's cache, rebuilt on
/// every eviction: an avatar widget keys its request on it.

@ProviderFor(avatarGeneration)
final avatarGenerationProvider = AvatarGenerationFamily._();

/// [AvatarCache.generationOf] the user in the account's cache, rebuilt on
/// every eviction: an avatar widget keys its request on it.

final class AvatarGenerationProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// [AvatarCache.generationOf] the user in the account's cache, rebuilt on
  /// every eviction: an avatar widget keys its request on it.
  AvatarGenerationProvider._({
    required AvatarGenerationFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'avatarGenerationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$avatarGenerationHash();

  @override
  String toString() {
    return r'avatarGenerationProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    final argument = this.argument as (String, String);
    return avatarGeneration(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AvatarGenerationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$avatarGenerationHash() => r'21f9010d74578bb2b11eb2fed8245625c7323d54';

/// [AvatarCache.generationOf] the user in the account's cache, rebuilt on
/// every eviction: an avatar widget keys its request on it.

final class AvatarGenerationFamily extends $Family
    with $FunctionalFamilyOverride<int, (String, String)> {
  AvatarGenerationFamily._()
    : super(
        retry: null,
        name: r'avatarGenerationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [AvatarCache.generationOf] the user in the account's cache, rebuilt on
  /// every eviction: an avatar widget keys its request on it.

  AvatarGenerationProvider call(String accountId, String username) =>
      AvatarGenerationProvider._(argument: (accountId, username), from: this);

  @override
  String toString() => r'avatarGenerationProvider';
}
