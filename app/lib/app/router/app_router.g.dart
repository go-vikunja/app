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

/// Registers [_AppSchemeLinks] with the binding while it lives.

@ProviderFor(appSchemeLinks)
final appSchemeLinksProvider = AppSchemeLinksProvider._();

/// Registers [_AppSchemeLinks] with the binding while it lives.

final class AppSchemeLinksProvider
    extends
        $FunctionalProvider<
          WidgetsBindingObserver,
          WidgetsBindingObserver,
          WidgetsBindingObserver
        >
    with $Provider<WidgetsBindingObserver> {
  /// Registers [_AppSchemeLinks] with the binding while it lives.
  AppSchemeLinksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSchemeLinksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSchemeLinksHash();

  @$internal
  @override
  $ProviderElement<WidgetsBindingObserver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WidgetsBindingObserver create(Ref ref) {
    return appSchemeLinks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WidgetsBindingObserver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WidgetsBindingObserver>(value),
    );
  }
}

String _$appSchemeLinksHash() => r'00c7dfa771a44f86fce7aae2d3b2bf50d5ca7960';

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

String _$appRouterHash() => r'd4533069bd3e6bd82388257c57dbb7d2a0ea50f2';
