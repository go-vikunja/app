import 'package:flutter/widgets.dart';

/// The dialogs, sheets and pickers that are open, so that an account switch
/// can close them at once: an exit animation would show them with the next
/// account's data. An opening can also let them go as Back would, so that
/// one that asks first stays until it is answered.
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

  /// Whether one is open on [navigator]; the shell's tab navigators report
  /// here too, so this finds a tab's popup menu.
  bool isOpenOn(NavigatorState navigator) =>
      _routes.any((route) => route.isActive && route.navigator == navigator);

  /// The newest one open on [navigator].
  Route<Object?>? lastOn(NavigatorState navigator) => _routes
      .where((route) => route.isActive && route.navigator == navigator)
      .lastOrNull;

  /// Without animation, the topmost first; their futures complete with null.
  void closeAll() {
    for (final route in _routes.reversed.toList()) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
    _routes.clear();
  }

  /// Like [closeAll], the newest first, but only down to the first one Back
  /// would not close because it asks first or is busy; that one is
  /// returned, and it and the ones under it stay.
  Route<Object?>? closeDownToGuarded() {
    for (final route in _routes.reversed.toList()) {
      if (!route.isActive) continue;
      if (route.popDisposition == RoutePopDisposition.doNotPop) return route;
      route.navigator?.removeRoute(route);
    }
    return null;
  }
}
