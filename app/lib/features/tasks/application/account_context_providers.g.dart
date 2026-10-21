// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_context_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active account's server and frontend, which rich text needs for its
/// attachment images and task links; null while nobody is signed in.

@ProviderFor(activeLinkBases)
final activeLinkBasesProvider = ActiveLinkBasesProvider._();

/// The active account's server and frontend, which rich text needs for its
/// attachment images and task links; null while nobody is signed in.

final class ActiveLinkBasesProvider
    extends
        $FunctionalProvider<
          AccountLinkBases?,
          AccountLinkBases?,
          AccountLinkBases?
        >
    with $Provider<AccountLinkBases?> {
  /// The active account's server and frontend, which rich text needs for its
  /// attachment images and task links; null while nobody is signed in.
  ActiveLinkBasesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeLinkBasesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeLinkBasesHash();

  @$internal
  @override
  $ProviderElement<AccountLinkBases?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountLinkBases? create(Ref ref) {
    return activeLinkBases(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountLinkBases? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountLinkBases?>(value),
    );
  }
}

String _$activeLinkBasesHash() => r'3d7d28da30d329fcc0c70624ff525168cc490fba';

/// The signed-in user's id on the active account's server.

@ProviderFor(activeUserId)
final activeUserIdProvider = ActiveUserIdProvider._();

/// The signed-in user's id on the active account's server.

final class ActiveUserIdProvider extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// The signed-in user's id on the active account's server.
  ActiveUserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeUserIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeUserIdHash();

  @$internal
  @override
  $ProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int? create(Ref ref) {
    return activeUserId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$activeUserIdHash() => r'6e871f0561d93bc3ec105f4479426cbe7610cd8a';

/// The signed-in user of the active account as the server lists people,
/// e.g. among those who reacted.

@ProviderFor(activeUser)
final activeUserProvider = ActiveUserProvider._();

/// The signed-in user of the active account as the server lists people,
/// e.g. among those who reacted.

final class ActiveUserProvider extends $FunctionalProvider<User?, User?, User?>
    with $Provider<User?> {
  /// The signed-in user of the active account as the server lists people,
  /// e.g. among those who reacted.
  ActiveUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeUserHash();

  @$internal
  @override
  $ProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  User? create(Ref ref) {
    return activeUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(User? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<User?>(value),
    );
  }
}

String _$activeUserHash() => r'00877f32896c0dd742d6674a467014ea4b9cb86c';

/// Whether the active account's server has comments switched on.

@ProviderFor(activeServerOffersComments)
final activeServerOffersCommentsProvider =
    ActiveServerOffersCommentsProvider._();

/// Whether the active account's server has comments switched on.

final class ActiveServerOffersCommentsProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the active account's server has comments switched on.
  ActiveServerOffersCommentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeServerOffersCommentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeServerOffersCommentsHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return activeServerOffersComments(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$activeServerOffersCommentsHash() =>
    r'f5e75a1d40d52d49d6ae5098d1756f6f7c55805a';
