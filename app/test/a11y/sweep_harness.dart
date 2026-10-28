import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';

import '../helpers/pump_app.dart';
import 'sweep_guidelines.dart';

const Set<TargetPlatform> bothPlatforms = {
  TargetPlatform.android,
  TargetPlatform.iOS,
};
const Set<TargetPlatform> androidOnly = {TargetPlatform.android};

const sweepLocales = [Locale('en'), Locale('de')];

/// Guideline evaluations per scenario: the first frame, then one per
/// scroll of the main list, because the guidelines skip nodes off screen
/// or at a scroll edge.
const maxScrollStops = 10;

enum SweepKind { route, overlay, state }

typedef SweepStep = Future<void> Function(
  WidgetTester tester,
  AppLocalizations l10n,
);
typedef ScreenFinder = Finder Function(AppLocalizations l10n);

/// One screen of the accessibility sweep.
///
/// [setUp] seeds the fakes and pumps the app; [navigate] reaches the
/// screen through the router or the app's own show functions, never by
/// tapping visible text. A route scenario then has to show [route] (its
/// GoRoute pattern), so a silent redirect fails. [expectScreen] finds
/// exactly one widget of the screen. With [settle] false the screen never
/// settles (an indeterminate progress indicator) and is evaluated once
/// [expectScreen] matches.
final class SweepScenario {
  const new({
    required this.kind,
    required this.name,
    required this.setUp,
    required this.expectScreen,
    this.variant = '',
    this.navigate,
    this.route,
    this.platforms = bothPlatforms,
    this.settle = true,
    this.tearDown,
    this.iOSSurface,
  });

  factory route(
    String pattern, {
    required SweepStep setUp,
    required ScreenFinder expectScreen,
    String variant = '',
    SweepStep? navigate,
    Set<TargetPlatform> platforms = bothPlatforms,
    bool settle = true,
    SweepStep? tearDown,
  }) => SweepScenario(
    kind: SweepKind.route,
    name: pattern,
    route: pattern,
    setUp: setUp,
    expectScreen: expectScreen,
    variant: variant,
    navigate: navigate,
    platforms: platforms,
    settle: settle,
    tearDown: tearDown,
  );

  final SweepKind kind;

  /// The route pattern of a route scenario, the registry id of an overlay
  /// scenario, a short description of a state.
  final String name;
  final String variant;
  final SweepStep setUp;
  final SweepStep? navigate;
  final ScreenFinder expectScreen;

  /// The GoRoute pattern the router shows once [navigate] is done.
  final String? route;
  final Set<TargetPlatform> platforms;
  final bool settle;

  /// Runs before the end of the test, e.g. to close a snackbar whose timer
  /// would still be pending.
  final SweepStep? tearDown;

  /// The iOS variant's surface instead of [phoneSize], with the reason at
  /// the scenario.
  final Size? iOSSurface;

  /// What the completeness checks match: the route and its variant.
  String get key => variant.isEmpty ? name : '$name [$variant]';

  String get title => switch (kind) {
    SweepKind.route => 'route $key',
    SweepKind.overlay => 'overlay $key',
    SweepKind.state => 'state $key',
  };
}

/// An AlertDialog.adaptive, which is a subclass on both platforms.
final Finder alertDialog = find.byWidgetPredicate(
  (widget) => widget is AlertDialog,
);

GoRouter routerOf(WidgetTester tester) =>
    containerOf(tester).read(appRouterProvider);

/// The guidelines every scenario meets on [platform].
List<(String, AccessibilityGuideline)> sweepGuidelines(
  TargetPlatform platform,
) => [
  if (platform == TargetPlatform.iOS)
    ('iOS tap target', sweepIOSTapTargetGuideline)
  else
    ('Android tap target', sweepAndroidTapTargetGuideline),
  ('labelled tap target', labeledTapTargetGuideline),
  ('text contrast', sweepTextContrastGuideline),
  ('heading level', headingLevelGuideline),
  ('heading not a control', headingNotControlGuideline),
  ('image label', imageLabelGuideline),
  ('action labels', actionLabelGuideline),
  ('distinct tap labels', distinctTapLabelGuideline),
];

/// One test per scenario, brightness and language, each on the scenario's
/// platforms.
void sweep(List<SweepScenario> scenarios) {
  for (final scenario in scenarios) {
    for (final brightness in Brightness.values) {
      for (final locale in sweepLocales) {
        testWidgets(
          '${scenario.title} ${brightness.name} ${locale.languageCode}',
          (tester) => runScenario(
            tester,
            scenario,
            brightness: brightness,
            locale: locale,
          ),
          variant: TargetPlatformVariant(scenario.platforms),
          timeout: const Timeout(Duration(seconds: 30)),
        );
      }
    }
  }
}

Future<void> runScenario(
  WidgetTester tester,
  SweepScenario scenario, {
  required Brightness brightness,
  required Locale locale,
}) async {
  usePhoneSurface(
    tester,
    logicalSize: defaultTargetPlatform == TargetPlatform.iOS
        ? scenario.iOSSurface ?? phoneSize
        : phoneSize,
  );
  useLocale(tester, locale);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final l10n = lookupAppLocalizations(locale);
  await scenario.setUp(tester, l10n);
  await scenario.navigate?.call(tester, l10n);
  await _settle(tester, scenario);
  if (!scenario.settle) await pumpUntil(tester, scenario.expectScreen(l10n));

  if (scenario.route case final route?) {
    expect(
      routerOf(tester).state.fullPath,
      route,
      reason: 'the router redirected away from ${scenario.key}',
    );
  }
  expect(scenario.expectScreen(l10n), findsOneWidget);
  expect(tester.takeException(), isNull);

  final failures = <String>[];
  final guidelines = sweepGuidelines(defaultTargetPlatform);
  Future<void> evaluate(String where) async {
    for (final (name, guideline) in guidelines) {
      final evaluation = await guideline.evaluate(tester);
      if (!evaluation.passed) {
        failures.add('FAILED $name at $where:\n${evaluation.reason ?? ''}');
      }
    }
  }

  await evaluate('first frame');
  final position = _mainScrollPosition(tester);
  for (var stop = 1; stop < maxScrollStops && position != null; stop++) {
    if (position.extentAfter <= 0) break;
    position.jumpTo(
      math.min(
        position.maxScrollExtent,
        position.pixels + position.viewportDimension * 0.8,
      ),
    );
    await _settle(tester, scenario);
    expect(tester.takeException(), isNull);
    await evaluate('scroll stop $stop');
  }

  await scenario.tearDown?.call(tester, l10n);
  if (failures.isNotEmpty) {
    fail(
      '${scenario.title} fails ${failures.length} evaluation(s):\n'
      '${failures.join('\n')}',
    );
  }
}

Future<void> _settle(WidgetTester tester, SweepScenario scenario) async {
  if (scenario.settle) {
    await tester.pumpAndSettle();
  } else {
    // Past any route transition, which would fade the text under test.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

/// The largest vertical list in front: a sheet's or a dialog's over the
/// page below.
ScrollPosition? _mainScrollPosition(WidgetTester tester) {
  ScrollPosition? largest;
  var largestArea = 0.0;
  for (final element in find.byType(Scrollable).hitTestable().evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    final position = state.position;
    if (position.axis != Axis.vertical) continue;
    final size = element.size ?? Size.zero;
    final area = size.width * size.height;
    if (area > largestArea) {
      largest = position;
      largestArea = area;
    }
  }
  return largest;
}
