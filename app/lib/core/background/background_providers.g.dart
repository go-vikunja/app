// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backgroundScheduler)
final backgroundSchedulerProvider = BackgroundSchedulerProvider._();

final class BackgroundSchedulerProvider
    extends
        $FunctionalProvider<
          BackgroundScheduler,
          BackgroundScheduler,
          BackgroundScheduler
        >
    with $Provider<BackgroundScheduler> {
  BackgroundSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundSchedulerHash();

  @$internal
  @override
  $ProviderElement<BackgroundScheduler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundScheduler create(Ref ref) {
    return backgroundScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundScheduler>(value),
    );
  }
}

String _$backgroundSchedulerHash() =>
    r'67dd5a7aadda2b57b050d8909c25db0525908a0c';

@ProviderFor(backgroundRunLog)
final backgroundRunLogProvider = BackgroundRunLogProvider._();

final class BackgroundRunLogProvider
    extends
        $FunctionalProvider<
          BackgroundRunLog,
          BackgroundRunLog,
          BackgroundRunLog
        >
    with $Provider<BackgroundRunLog> {
  BackgroundRunLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundRunLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundRunLogHash();

  @$internal
  @override
  $ProviderElement<BackgroundRunLog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackgroundRunLog create(Ref ref) {
    return backgroundRunLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundRunLog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundRunLog>(value),
    );
  }
}

String _$backgroundRunLogHash() => r'cd1b618c02f3e70c1aecb773a94d35655f10b1e0';

/// Beats while the app is visible: from now when it is, and from every
/// show or resume until it is hidden. Bootstrap listens.

@ProviderFor(foregroundHeartbeat)
final foregroundHeartbeatProvider = ForegroundHeartbeatProvider._();

/// Beats while the app is visible: from now when it is, and from every
/// show or resume until it is hidden. Bootstrap listens.

final class ForegroundHeartbeatProvider
    extends
        $FunctionalProvider<
          ForegroundHeartbeat,
          ForegroundHeartbeat,
          ForegroundHeartbeat
        >
    with $Provider<ForegroundHeartbeat> {
  /// Beats while the app is visible: from now when it is, and from every
  /// show or resume until it is hidden. Bootstrap listens.
  ForegroundHeartbeatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundHeartbeatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundHeartbeatHash();

  @$internal
  @override
  $ProviderElement<ForegroundHeartbeat> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ForegroundHeartbeat create(Ref ref) {
    return foregroundHeartbeat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ForegroundHeartbeat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ForegroundHeartbeat>(value),
    );
  }
}

String _$foregroundHeartbeatHash() =>
    r'954bc7e222b64d688f70fd9c1ba755fcac7742a6';

/// Keeps the OS's periodic job in step with the accounts: registered while
/// at least one account is signed in (again on every app start, which
/// updates rather than duplicates it), cancelled after the last sign-out.
/// Bootstrap listens once `Workmanager` is initialised.

@ProviderFor(backgroundRegistration)
final backgroundRegistrationProvider = BackgroundRegistrationProvider._();

/// Keeps the OS's periodic job in step with the accounts: registered while
/// at least one account is signed in (again on every app start, which
/// updates rather than duplicates it), cancelled after the last sign-out.
/// Bootstrap listens once `Workmanager` is initialised.

final class BackgroundRegistrationProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Keeps the OS's periodic job in step with the accounts: registered while
  /// at least one account is signed in (again on every app start, which
  /// updates rather than duplicates it), cancelled after the last sign-out.
  /// Bootstrap listens once `Workmanager` is initialised.
  BackgroundRegistrationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundRegistrationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundRegistrationHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return backgroundRegistration(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$backgroundRegistrationHash() =>
    r'379331f2cc1bf5266eca36111b2a1a1c7cf985cc';
