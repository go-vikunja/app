import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The page routes a navigator pushes, so that [PagePush.pushPage] can wait
/// for the page it pushed to close.
final class PushedPages extends NavigatorObserver {
  Completer<Route<Object?>>? _next;

  Future<Route<Object?>> _nextPage() => (_next ??= Completer()).future;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    if (route is! PageRoute<Object?>) return;
    _next?.complete(route);
    _next = null;
  }
}

extension PagePush on BuildContext {
  /// [GoRouter.push] with a result that arrives even when go_router's own
  /// future never does: once the platform reports the route list back, as
  /// Android does when the app is opened again, go_router rebuilds the list
  /// with new futures (flutter/flutter#128122). The pushed route survives
  /// that and still reports its pop.
  Future<T?> pushPage<T>(String location, {Object? extra}) {
    final router = GoRouter.of(this);
    final pushed = router.observers
        ?.whereType<PushedPages>()
        .firstOrNull
        ?._nextPage();
    final viaRouter = router.push<T>(location, extra: extra);
    if (pushed == null) return viaRouter;
    final viaRoute = pushed
        .then((route) => route.popped)
        .then((result) => result as T?);
    return Future.any([viaRouter, viaRoute]);
  }
}
