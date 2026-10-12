import 'package:flutter/widgets.dart';

/// The dialogs, sheets and pickers that are open, so that an account switch
/// can close them at once: an exit animation would show them with the next
/// account's data.
final class RootModalRoutes extends NavigatorObserver {
  final _routes = <Route<Object?>>[];

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    if (route.settings is! Page) _routes.add(route);
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    _routes.remove(oldRoute);
    if (newRoute != null && newRoute.settings is! Page) _routes.add(newRoute);
  }

  /// Whether a route pushed with [name] in its settings is open.
  bool isOpen(String name) =>
      _routes.any((route) => route.isActive && route.settings.name == name);

  /// Without animation, the topmost first; their futures complete with null.
  void closeAll() {
    for (final route in _routes.reversed.toList()) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
    _routes.clear();
  }
}
