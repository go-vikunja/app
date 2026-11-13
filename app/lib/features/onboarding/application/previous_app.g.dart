// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'previous_app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(previousAppPlatform)
final previousAppPlatformProvider = PreviousAppPlatformProvider._();

final class PreviousAppPlatformProvider
    extends
        $FunctionalProvider<
          PreviousAppPlatform,
          PreviousAppPlatform,
          PreviousAppPlatform
        >
    with $Provider<PreviousAppPlatform> {
  PreviousAppPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previousAppPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previousAppPlatformHash();

  @$internal
  @override
  $ProviderElement<PreviousAppPlatform> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PreviousAppPlatform create(Ref ref) {
    return previousAppPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreviousAppPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreviousAppPlatform>(value),
    );
  }
}

String _$previousAppPlatformHash() =>
    r'6d883549f342cce09bd88bc7b1e16a545e993c1a';

@ProviderFor(previousAppSignIn)
final previousAppSignInProvider = PreviousAppSignInProvider._();

final class PreviousAppSignInProvider
    extends
        $FunctionalProvider<
          PreviousAppSignIn,
          PreviousAppSignIn,
          PreviousAppSignIn
        >
    with $Provider<PreviousAppSignIn> {
  PreviousAppSignInProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previousAppSignInProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previousAppSignInHash();

  @$internal
  @override
  $ProviderElement<PreviousAppSignIn> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PreviousAppSignIn create(Ref ref) {
    return previousAppSignIn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreviousAppSignIn value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreviousAppSignIn>(value),
    );
  }
}

String _$previousAppSignInHash() => r'a1768ad4462663d6c1e38080523ac5072a9bb2ac';

/// What this app took over from the previous Vikunja app it replaced on
/// Android, for Connect and the first sync.

@ProviderFor(PreviousApp)
final previousAppProvider = PreviousAppProvider._();

/// What this app took over from the previous Vikunja app it replaced on
/// Android, for Connect and the first sync.
final class PreviousAppProvider
    extends $AsyncNotifierProvider<PreviousApp, PreviousAppState> {
  /// What this app took over from the previous Vikunja app it replaced on
  /// Android, for Connect and the first sync.
  PreviousAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previousAppProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previousAppHash();

  @$internal
  @override
  PreviousApp create() => PreviousApp();
}

String _$previousAppHash() => r'ea35faf7dee23c510887cc2b22fbf1a2309c0478';

/// What this app took over from the previous Vikunja app it replaced on
/// Android, for Connect and the first sync.

abstract class _$PreviousApp extends $AsyncNotifier<PreviousAppState> {
  FutureOr<PreviousAppState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PreviousAppState>, PreviousAppState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PreviousAppState>, PreviousAppState>,
              AsyncValue<PreviousAppState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
