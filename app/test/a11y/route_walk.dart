import 'package:go_router/go_router.dart';

/// GoRoutes the sweep leaves out, by full path, each with the reason.
const routeExemptions = <String, String>{
  '/splash':
      'An empty Scaffold for the frames before the account registry is '
      'read; there is nothing on it to check.',
};

/// The routes that build different screens for different data, with the
/// variants each must be swept in.
const requiredVariants = <String, Set<String>>{
  '/home/projects/:id': {
    'list',
    'kanban',
    'table',
    'gantt',
    'favourites',
    'saved filter',
  },
  '/connection': {
    'https',
    'http',
    'headers',
    'certificate',
    'clientCertificate',
  },
};

/// The key a scenario of [route] in [variant] covers.
String coverageKey(String route, [String variant = '']) =>
    variant.isEmpty ? route : '$route [$variant]';

/// Compares the routes of a router configuration with the keys the
/// scenarios cover: `missing` are the routes (or route variants) without
/// a scenario, `stale` the scenario keys and exemptions that match no
/// route.
/// A GoRoute without a builder only redirects and is skipped; [fullPath]
/// is the configuration's `locationForRoute`.
({List<String> missing, List<String> stale}) compareRouteCoverage({
  required List<RouteBase> routes,
  required String? Function(RouteBase route) fullPath,
  required Set<String> covered,
  Map<String, String> exemptions = routeExemptions,
  Map<String, Set<String>> variants = requiredVariants,
}) {
  final required = <String>{};
  final paths = <String>{};
  void walk(List<RouteBase> routes) {
    for (final route in routes) {
      if (route is GoRoute &&
          (route.builder != null || route.pageBuilder != null)) {
        final path = fullPath(route) ?? route.path;
        paths.add(path);
        if (!exemptions.containsKey(path)) {
          final routeVariants = variants[path];
          if (routeVariants == null) {
            required.add(coverageKey(path));
          } else {
            required.addAll([
              for (final variant in routeVariants) coverageKey(path, variant),
            ]);
          }
        }
      }
      walk(route.routes);
    }
  }

  walk(routes);
  return (
    missing: [
      for (final key in required)
        if (!covered.contains(key)) key,
    ]..sort(),
    stale: [
      for (final key in covered)
        if (!required.contains(key)) 'scenario $key',
      for (final path in exemptions.keys)
        if (!paths.contains(path)) 'exemption $path',
      for (final path in variants.keys)
        if (!paths.contains(path)) 'variants of $path',
    ]..sort(),
  );
}
