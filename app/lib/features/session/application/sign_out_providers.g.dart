// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The last step of a sign-out: makes a background run in another isolate
/// let go of the account, drops its avatars and attachment images from
/// memory, cancels the account's notifications (scheduled, the session
/// reminder included, and in the tray) and forgets their preferences, the
/// background notes, the last session end, the sign-in page on another
/// host it confirmed, that it was kept as an http account, the unsent
/// comments and the description draft, replaces its home-screen widgets'
/// content with "Account removed", stops its outbox sender and sync engine,
/// closes its database and deletes the files: the database, the stored
/// copies of queued uploads, the downloaded attachments and the images
/// kept on disk.

@ProviderFor(accountDataWiper)
final accountDataWiperProvider = AccountDataWiperProvider._();

/// The last step of a sign-out: makes a background run in another isolate
/// let go of the account, drops its avatars and attachment images from
/// memory, cancels the account's notifications (scheduled, the session
/// reminder included, and in the tray) and forgets their preferences, the
/// background notes, the last session end, the sign-in page on another
/// host it confirmed, that it was kept as an http account, the unsent
/// comments and the description draft, replaces its home-screen widgets'
/// content with "Account removed", stops its outbox sender and sync engine,
/// closes its database and deletes the files: the database, the stored
/// copies of queued uploads, the downloaded attachments and the images
/// kept on disk.

final class AccountDataWiperProvider
    extends
        $FunctionalProvider<
          AccountDataWiper,
          AccountDataWiper,
          AccountDataWiper
        >
    with $Provider<AccountDataWiper> {
  /// The last step of a sign-out: makes a background run in another isolate
  /// let go of the account, drops its avatars and attachment images from
  /// memory, cancels the account's notifications (scheduled, the session
  /// reminder included, and in the tray) and forgets their preferences, the
  /// background notes, the last session end, the sign-in page on another
  /// host it confirmed, that it was kept as an http account, the unsent
  /// comments and the description draft, replaces its home-screen widgets'
  /// content with "Account removed", stops its outbox sender and sync engine,
  /// closes its database and deletes the files: the database, the stored
  /// copies of queued uploads, the downloaded attachments and the images
  /// kept on disk.
  AccountDataWiperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDataWiperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDataWiperHash();

  @$internal
  @override
  $ProviderElement<AccountDataWiper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountDataWiper create(Ref ref) {
    return accountDataWiper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDataWiper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDataWiper>(value),
    );
  }
}

String _$accountDataWiperHash() => r'b200cdb67f3a98f1b3edc12dab1a6a8d65da87cf';

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

String _$accountDeletionsHash() => r'27dcf0dc650da283299a61a51daa4e0496109f60';

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
