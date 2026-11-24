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
/// reminder included, whatever else the OS holds for it, and in the tray)
/// and forgets their preferences, the background notes, the last session
/// end, the sign-in page on another host it confirmed, that it was kept as
/// an http account, the unsent comments and the description draft, replaces
/// its home-screen widgets' content with "Account removed", stops its
/// outbox sender and sync engine, closes its database and deletes the
/// files: the database, the stored copies of queued uploads, the downloaded
/// attachments, the images kept on disk and, on Android, share_plus's copy
/// of the file shared last, whichever account it came from. Every part is
/// tried, also after one failed, and the first failure is thrown at the
/// end, so the account stays listed to delete and the next start tries
/// again (decision log: Accounts and sign-in).

@ProviderFor(accountDataWiper)
final accountDataWiperProvider = AccountDataWiperProvider._();

/// The last step of a sign-out: makes a background run in another isolate
/// let go of the account, drops its avatars and attachment images from
/// memory, cancels the account's notifications (scheduled, the session
/// reminder included, whatever else the OS holds for it, and in the tray)
/// and forgets their preferences, the background notes, the last session
/// end, the sign-in page on another host it confirmed, that it was kept as
/// an http account, the unsent comments and the description draft, replaces
/// its home-screen widgets' content with "Account removed", stops its
/// outbox sender and sync engine, closes its database and deletes the
/// files: the database, the stored copies of queued uploads, the downloaded
/// attachments, the images kept on disk and, on Android, share_plus's copy
/// of the file shared last, whichever account it came from. Every part is
/// tried, also after one failed, and the first failure is thrown at the
/// end, so the account stays listed to delete and the next start tries
/// again (decision log: Accounts and sign-in).

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
  /// reminder included, whatever else the OS holds for it, and in the tray)
  /// and forgets their preferences, the background notes, the last session
  /// end, the sign-in page on another host it confirmed, that it was kept as
  /// an http account, the unsent comments and the description draft, replaces
  /// its home-screen widgets' content with "Account removed", stops its
  /// outbox sender and sync engine, closes its database and deletes the
  /// files: the database, the stored copies of queued uploads, the downloaded
  /// attachments, the images kept on disk and, on Android, share_plus's copy
  /// of the file shared last, whichever account it came from. Every part is
  /// tried, also after one failed, and the first failure is thrown at the
  /// end, so the account stays listed to delete and the next start tries
  /// again (decision log: Accounts and sign-in).
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

String _$accountDataWiperHash() => r'8bf68884d8ca5646d1d28e095ee3f29bb21de18c';

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

String _$signOutHash() => r'4865fdf538be06782fa1d3016d936bc01ae3e08b';
