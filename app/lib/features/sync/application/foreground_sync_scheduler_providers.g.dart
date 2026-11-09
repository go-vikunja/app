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
    r'c6aaa7b358e784c1b662c53e3e93f9d2434ae785';
