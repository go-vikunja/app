// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foreground_sync_scheduler_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active account's scheduler, replaced on an account switch and gone
/// while nobody is signed in, while the session needs a new sign-in (a run
/// cannot reach the server) and during a sign-out (a run would race the
/// wipe). The shell listens; while nobody does (the first-sync screen, a
/// sign-out from there) the scheduler rests, because a provider without
/// listeners is not rebuilt either.

@ProviderFor(foregroundSyncScheduler)
final foregroundSyncSchedulerProvider = ForegroundSyncSchedulerProvider._();

/// The active account's scheduler, replaced on an account switch and gone
/// while nobody is signed in, while the session needs a new sign-in (a run
/// cannot reach the server) and during a sign-out (a run would race the
/// wipe). The shell listens; while nobody does (the first-sync screen, a
/// sign-out from there) the scheduler rests, because a provider without
/// listeners is not rebuilt either.

final class ForegroundSyncSchedulerProvider
    extends
        $FunctionalProvider<
          ForegroundSyncScheduler?,
          ForegroundSyncScheduler?,
          ForegroundSyncScheduler?
        >
    with $Provider<ForegroundSyncScheduler?> {
  /// The active account's scheduler, replaced on an account switch and gone
  /// while nobody is signed in, while the session needs a new sign-in (a run
  /// cannot reach the server) and during a sign-out (a run would race the
  /// wipe). The shell listens; while nobody does (the first-sync screen, a
  /// sign-out from there) the scheduler rests, because a provider without
  /// listeners is not rebuilt either.
  ForegroundSyncSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundSyncSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundSyncSchedulerHash();

  @$internal
  @override
  $ProviderElement<ForegroundSyncScheduler?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ForegroundSyncScheduler? create(Ref ref) {
    return foregroundSyncScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ForegroundSyncScheduler? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ForegroundSyncScheduler?>(value),
    );
  }
}

String _$foregroundSyncSchedulerHash() =>
    r'12bf2cb53be899517ac9a89a07955505dc9e6d21';

/// What a run that found something new stores, and every local write:
/// the account's tasks, projects, labels and queued changes. A run that
/// finds nothing new writes none of them, so the foreground sync can
/// wait longer then.

@ProviderFor(accountDataWrites)
final accountDataWritesProvider = AccountDataWritesFamily._();

/// What a run that found something new stores, and every local write:
/// the account's tasks, projects, labels and queued changes. A run that
/// finds nothing new writes none of them, so the foreground sync can
/// wait longer then.

final class AccountDataWritesProvider
    extends
        $FunctionalProvider<
          Raw<Stream<void>>,
          Raw<Stream<void>>,
          Raw<Stream<void>>
        >
    with $Provider<Raw<Stream<void>>> {
  /// What a run that found something new stores, and every local write:
  /// the account's tasks, projects, labels and queued changes. A run that
  /// finds nothing new writes none of them, so the foreground sync can
  /// wait longer then.
  AccountDataWritesProvider._({
    required AccountDataWritesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountDataWritesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountDataWritesHash();

  @override
  String toString() {
    return r'accountDataWritesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Raw<Stream<void>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Raw<Stream<void>> create(Ref ref) {
    final argument = this.argument as String;
    return accountDataWrites(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Raw<Stream<void>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Raw<Stream<void>>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountDataWritesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountDataWritesHash() => r'afd2b1b72d8a189658e3fd2ae1291e601e0e2219';

/// What a run that found something new stores, and every local write:
/// the account's tasks, projects, labels and queued changes. A run that
/// finds nothing new writes none of them, so the foreground sync can
/// wait longer then.

final class AccountDataWritesFamily extends $Family
    with $FunctionalFamilyOverride<Raw<Stream<void>>, String> {
  AccountDataWritesFamily._()
    : super(
        retry: null,
        name: r'accountDataWritesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// What a run that found something new stores, and every local write:
  /// the account's tasks, projects, labels and queued changes. A run that
  /// finds nothing new writes none of them, so the foreground sync can
  /// wait longer then.

  AccountDataWritesProvider call(String accountId) =>
      AccountDataWritesProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountDataWritesProvider';
}
