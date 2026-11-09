// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Observes the root navigator, whose dialogs and sheets an account switch
/// closes.

@ProviderFor(rootModalRoutes)
final rootModalRoutesProvider = RootModalRoutesProvider._();

/// Observes the root navigator, whose dialogs and sheets an account switch
/// closes.

final class RootModalRoutesProvider
    extends
        $FunctionalProvider<RootModalRoutes, RootModalRoutes, RootModalRoutes>
    with $Provider<RootModalRoutes> {
  /// Observes the root navigator, whose dialogs and sheets an account switch
  /// closes.
  RootModalRoutesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rootModalRoutesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rootModalRoutesHash();

  @$internal
  @override
  $ProviderElement<RootModalRoutes> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RootModalRoutes create(Ref ref) {
    return rootModalRoutes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RootModalRoutes value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RootModalRoutes>(value),
    );
  }
}

String _$rootModalRoutesHash() => r'255be473fc2f430716d2ce192c908c9a02d81559';

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'754f8577496a0482d2f69635196fa2e3ea1f453f';
