import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';

import '../helpers/large_screens.dart';
import '../helpers/pump_app.dart';
import 'readable_widths.dart';
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

/// The phone of the 36a sweep, or the platform's tablet (step 36b): an
/// Android tablet at 1280×800, an 11" iPad at 1194×834, or turned.
enum SweepSurface {
  phone,
  tabletLandscape,
  tabletPortrait;

  String get label => switch (this) {
    phone => 'phone',
    tabletLandscape => 'tablet landscape',
    tabletPortrait => 'tablet portrait',
  };
}

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

/// One test per scenario, brightness and language on the phone, each on
/// the scenario's platforms. On the tablet in both orientations, dark and
/// in both languages, one test with the guidelines and the readable-width
/// checks, and one at 200 % text that only looks for an overflow.
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
    for (final surface in [
      SweepSurface.tabletLandscape,
      SweepSurface.tabletPortrait,
    ]) {
      for (final largeText in [false, true]) {
        for (final locale in sweepLocales) {
          testWidgets(
            '${scenario.title} ${surface.label}${largeText ? ' 200 %' : ''} '
            'dark ${locale.languageCode}',
            (tester) => runScenario(
              tester,
              scenario,
              brightness: Brightness.dark,
              locale: locale,
              surface: surface,
              largeText: largeText,
            ),
            variant: TargetPlatformVariant(scenario.platforms),
            timeout: const Timeout(Duration(seconds: 30)),
          );
        }
      }
    }
  }
}

Size _surfaceSize(SweepSurface surface, SweepScenario scenario) {
  final apple = defaultTargetPlatform == TargetPlatform.iOS;
  return switch (surface) {
    SweepSurface.phone => apple ? scenario.iOSSurface ?? phoneSize : phoneSize,
    SweepSurface.tabletLandscape =>
      apple ? iPad11Landscape : androidTabletLandscape,
    SweepSurface.tabletPortrait =>
      apple ? iPad11Portrait : androidTabletPortrait,
  };
}

/// With [largeText] the text is at 200 % and the guidelines stay off: the
/// screen only has to show, without an overflow at any scroll stop.
Future<void> runScenario(
  WidgetTester tester,
  SweepScenario scenario, {
  required Brightness brightness,
  required Locale locale,
  SweepSurface surface = SweepSurface.phone,
  bool largeText = false,
}) async {
  final size = _surfaceSize(surface, scenario);
  if (surface == SweepSurface.phone) {
    usePhoneSurface(tester, logicalSize: size);
  } else {
    useWindow(tester, size);
  }
  useLocale(tester, locale);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  if (largeText) {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

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
  if (surface != SweepSurface.phone && !largeText) {
    _expectReadableWidths(tester, scenario);
  }

  final failures = <String>[];
  final guidelines = largeText
      ? const <(String, AccessibilityGuideline)>[]
      : sweepGuidelines(defaultTargetPlatform);
  Future<void> evaluate(String where) async {
    for (final (name, guideline) in guidelines) {
      final evaluation = await guideline.evaluate(tester);
      if (!evaluation.passed) {
        failures.add('FAILED $name at $where:\n${evaluation.reason ?? ''}');
      }
    }
  }

  await evaluate('first frame');
  final position = _mainScrollable(tester)?.position;
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
ScrollableState? _mainScrollable(WidgetTester tester) {
  ScrollableState? largest;
  var largestArea = 0.0;
  for (final element in find.byType(Scrollable).hitTestable().evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (state.position.axis != Axis.vertical) continue;
    final size = element.size ?? Size.zero;
    final area = size.width * size.height;
    if (area > largestArea) {
      largest = state;
      largestArea = area;
    }
  }
  return largest;
}

/// What a card keeps clear of its band's edges.
const _cardMargin = 16.0;

/// A capped screen's main list spans the window beside the rail, so its
/// margins scroll, and its boxes fill the band; an uncapped screen reaches
/// past the list band, a screen with its own cap keeps to it; an overlay
/// keeps to its cap.
void _expectReadableWidths(WidgetTester tester, SweepScenario scenario) {
  switch (scenario.kind) {
    case SweepKind.route:
      switch (readableWidths[scenario.key]) {
        case ReadableClass.list840:
          _expectInBand(tester, scenario, ReadableWidth.list);
        case ReadableClass.form640:
          _expectInBand(tester, scenario, ReadableWidth.form);
        case ReadableClass.uncapped:
          _expectPastListBand(tester, scenario);
        case ReadableClass.ownCap:
          _expectWithinOwnCap(tester, scenario);
        case null:
          return;
      }
    case SweepKind.overlay:
      final picker = find.byWidgetPredicate(
        (widget) => widget is DatePickerDialog || widget is TimePickerDialog,
      );
      if (find.byType(Dialog).evaluate().isNotEmpty &&
          picker.evaluate().isEmpty) {
        expect(
          dialogRect(tester).width,
          lessThanOrEqualTo(ReadableWidth.dialog + layoutTolerance),
        );
      }
      if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        expect(
          bottomSheetRect(tester).width,
          lessThanOrEqualTo(materialSheetMaxWidth + layoutTolerance),
        );
      }
      if (find.byType(ReadableSheetWidth).evaluate().isNotEmpty) {
        final card = iOSSheetContentRect(tester);
        expect(
          card.width,
          lessThanOrEqualTo(ReadableWidth.sheet + layoutTolerance),
        );
        expect(
          card.center.dx,
          moreOrLessEquals(
            windowSize(tester).width / 2,
            epsilon: layoutTolerance,
          ),
        );
      }
    case SweepKind.state:
      return;
  }
}

Rect _rectOf(WidgetTester tester, Element element) => tester.getRect(
  find.byElementPredicate((candidate) => candidate == element),
);

Finder _mainList(WidgetTester tester, SweepScenario scenario) {
  final scrollable = _mainScrollable(tester);
  expect(scrollable, isNotNull, reason: '${scenario.key} has no list');
  return find.byElementPredicate((element) => element == scrollable!.context);
}

/// Every box lies in the band, and the outermost reach its edges but for
/// a card's margin: a narrower cap, or an inset applied twice, fails.
void _expectInBand(
  WidgetTester tester,
  SweepScenario scenario,
  double maxWidth,
) {
  final list = _mainList(tester, scenario);
  expectFillsBand(tester.getRect(list), (
    left: railRight(tester),
    right: windowSize(tester).width,
  ), reason: 'the list of ${scenario.key} spans the window');
  final (boxes, _) =
      readableBoxOverrides[scenario.key] ?? (readableContentBoxes, '');
  final inList = find.descendant(of: list, matching: boxes);
  expect(inList, findsAtLeastNWidgets(1), reason: scenario.key);
  final band = readableBand(tester, maxWidth);
  final found = [
    for (final box in inList.evaluate())
      (type: box.widget.runtimeType, rect: _rectOf(tester, box)),
  ];
  for (final (:type, :rect) in found) {
    expectInBand(rect, band, reason: '$type of ${scenario.key}');
  }
  final rects = found.map((box) => box.rect);
  expect(
    rects.map((rect) => rect.left).reduce(math.min),
    lessThanOrEqualTo(band.left + _cardMargin + layoutTolerance),
    reason: 'the content of ${scenario.key} reaches the start of its band',
  );
  expect(
    rects.map((rect) => rect.right).reduce(math.max),
    greaterThanOrEqualTo(band.right - _cardMargin - layoutTolerance),
    reason: 'the content of ${scenario.key} reaches the end of its band',
  );
}

/// Where the list band leaves margins, some box of the screen lies in
/// them.
void _expectPastListBand(WidgetTester tester, SweepScenario scenario) {
  final boxes = uncappedContentBoxes.evaluate();
  expect(boxes, isNotEmpty, reason: scenario.key);
  final band = readableBand(tester, ReadableWidth.list);
  if (band.left - railRight(tester) <= _cardMargin) return;
  expect(
    boxes
        .map((box) => _rectOf(tester, box))
        .any(
          (rect) =>
              rect.left < band.left - layoutTolerance ||
              rect.right > band.right + layoutTolerance,
        ),
    isTrue,
    reason: '${scenario.key} takes the whole width',
  );
}

void _expectWithinOwnCap(WidgetTester tester, SweepScenario scenario) {
  final cap = readableOwnCaps[scenario.key]!;
  final boxes = find
      .descendant(of: _mainList(tester, scenario), matching: ownCapContentBoxes)
      .evaluate();
  expect(boxes, isNotEmpty, reason: scenario.key);
  final content = boxes
      .map((box) => _rectOf(tester, box))
      .reduce((all, rect) => all.expandToInclude(rect));
  expect(
    content.width,
    lessThanOrEqualTo(cap + layoutTolerance),
    reason: '${scenario.key} keeps to its own cap',
  );
}
