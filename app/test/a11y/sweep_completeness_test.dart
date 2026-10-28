import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/pump_app.dart';
import 'overlay_inventory.dart';
import 'overlay_sites.dart';
import 'route_walk.dart';
import 'scenarios_overlays.dart';
import 'sweep_harness.dart';
import 'sweep_suites.dart';

/// Every scenario the sweep files run.
final List<SweepScenario> allScenarios = [
  for (final suite in sweepSuites.values) ...suite,
];

void main() {
  test('every suite has its sweep file, which sweeps it, and every sweep '
      'file a suite', () {
    final files = {
      for (final file in Directory('test/a11y').listSync().whereType<File>())
        if (file.path.endsWith('_sweep_test.dart'))
          file.uri.pathSegments.last: file,
    };
    expect(files.keys.toSet(), {
      for (final name in sweepSuites.keys) '${name}_sweep_test.dart',
    });
    for (final name in sweepSuites.keys) {
      expect(
        files['${name}_sweep_test.dart']!.readAsStringSync(),
        contains("sweep(sweepSuites['$name']!)"),
        reason: '${name}_sweep_test.dart',
      );
    }
  });

  test('the route walk names a route without a scenario, a stale scenario '
      'and a stale exemption', () {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox(),
          routes: [GoRoute(path: 'about', builder: (_, _) => const SizedBox())],
        ),
        GoRoute(path: '/old', redirect: (_, _) => '/'),
        GoRoute(
          path: '/items',
          builder: (_, _) => const SizedBox(),
          routes: [GoRoute(path: ':id', builder: (_, _) => const SizedBox())],
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/a', builder: (_, _) => const SizedBox()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/b', builder: (_, _) => const SizedBox()),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final result = compareRouteCoverage(
      routes: router.configuration.routes,
      fullPath: router.configuration.locationForRoute,
      covered: {'/', '/about', '/items', '/a', '/gone'},
      exemptions: {'/b': 'a reason', '/nowhere': 'a reason'},
      variants: {
        '/items/:id': {'one', 'two'},
      },
    );

    expect(result.missing, ['/items/:id [one]', '/items/:id [two]']);
    expect(result.stale, ['exemption /nowhere', 'scenario /gone']);
  });

  testWidgets('every route of the app has a scenario, and every variant of '
      'the routes that build several screens', (tester) async {
    await pumpVikunjaApp(tester);
    final configuration = routerOf(tester).configuration;

    final result = compareRouteCoverage(
      routes: configuration.routes,
      fullPath: configuration.locationForRoute,
      covered: {
        for (final scenario in allScenarios)
          if (scenario.kind == SweepKind.route) scenario.key,
      },
    );

    expect(result.missing, isEmpty, reason: 'routes without a scenario');
    expect(
      result.stale,
      isEmpty,
      reason:
          'scenarios and exemptions of no '
          'route',
    );
  });

  test('every scenario has its own title', () {
    final titles = [for (final scenario in allScenarios) scenario.title];
    expect(titles.toSet().length, titles.length);
  });

  test('the overlay scenarios are exactly the registry', () {
    expect([
      for (final scenario in overlayScenarios) scenario.name,
    ], overlayRegistry);
  });

  test('every dialog, sheet and menu call in app/lib is swept or exempt '
      'with a reason', () {
    final sites = scanOverlaySites(Directory('lib'));
    final unclassified = [
      for (final site in sites)
        if (!overlayInventory.containsKey(site.key))
          '${site.location} (${site.key})',
    ];
    final found = {for (final site in sites) site.key};
    final stale = [
      for (final key in overlayInventory.keys)
        if (!found.contains(key)) key,
    ];
    final unknownScenarios = [
      for (final MapEntry(:key, :value) in overlayInventory.entries)
        if (value case Swept(:final scenario)
            when !overlayRegistry.contains(scenario))
          '$key -> $scenario',
    ];
    final blankReasons = [
      for (final MapEntry(:key, :value) in overlayInventory.entries)
        if (value case Exempt(:final reason) when reason.trim().isEmpty) key,
    ];

    expect(unclassified, isEmpty, reason: 'calls without an inventory entry');
    expect(stale, isEmpty, reason: 'inventory entries of no call');
    expect(unknownScenarios, isEmpty, reason: 'scenarios not in the registry');
    expect(blankReasons, isEmpty, reason: 'exemptions without a reason');
  });
}
