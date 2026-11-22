import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';

void main() {
  const destinations = [
    AdaptiveDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Overview',
    ),
    AdaptiveDestination(
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: 'Upcoming',
    ),
  ];

  Future<List<int>> pumpBar(
    WidgetTester tester, {
    required TargetPlatform platform,
    required TextScaler textScaler,
  }) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: AdaptiveNavigationBar(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: selected.add,
          ),
        ),
      ),
    );
    return selected;
  }

  double scaleOf(WidgetTester tester, Finder text) =>
      MediaQuery.textScalerOf(tester.element(text)).scale(12) / 12;

  testWidgets('iOS: at a size the bar does not follow, a long press shows '
      'the label at the full size, and lifting opens it', (tester) async {
    final selected = await pumpBar(
      tester,
      platform: TargetPlatform.iOS,
      textScaler: const TextScaler.linear(2),
    );
    expect(find.text('Upcoming'), findsOneWidget);
    final bar = tester.getRect(find.byType(AdaptiveNavigationBar));

    final gesture = await tester.startGesture(
      Offset(bar.left + bar.width * 0.75, bar.center.dy),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(find.text('Upcoming'), findsNWidgets(2));
    expect(scaleOf(tester, find.text('Upcoming').last), 2);

    await gesture.up();
    await tester.pump();
    expect(find.text('Upcoming'), findsOneWidget);
    expect(selected, [1]);
  });

  testWidgets('iOS: at a size the bar follows, a long press shows nothing', (
    tester,
  ) async {
    await pumpBar(
      tester,
      platform: TargetPlatform.iOS,
      textScaler: const TextScaler.linear(1.2),
    );
    final bar = tester.getRect(find.byType(AdaptiveNavigationBar));

    final gesture = await tester.startGesture(
      Offset(bar.left + bar.width * 0.75, bar.center.dy),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('Upcoming'), findsOneWidget);
    await gesture.up();
  });

  testWidgets("Android: at the bar's own 115 %, in Android's float "
      'arithmetic, the bar keeps its tooltips: it follows that size', (
    tester,
  ) async {
    await pumpBar(
      tester,
      platform: TargetPlatform.android,
      textScaler: const _AndroidFloatAt115(),
    );

    expect(
      tester
          .widget<NavigationDestination>(
            find.byType(NavigationDestination).first,
          )
          .tooltip,
      isNull,
    );
  });

  for (final (name, scaler) in [
    ('linear', const TextScaler.linear(2)),
    ("Android 14's nonlinear", const _Android14At200()),
  ]) {
    testWidgets('Android: the same at a size the bar does not follow, '
        "without the tooltip at the bar's size ($name)", (tester) async {
      final selected = await pumpBar(
        tester,
        platform: TargetPlatform.android,
        textScaler: scaler,
      );
      final bar = tester.getRect(find.byType(AdaptiveNavigationBar));

      final gesture = await tester.startGesture(
        Offset(bar.left + bar.width * 0.75, bar.center.dy),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      // The bar's label and the large one; no tooltip as a third.
      expect(find.text('Upcoming'), findsNWidgets(2));
      expect(scaleOf(tester, find.text('Upcoming').last), 2);

      await gesture.up();
      await tester.pump();
      expect(selected, [1]);
    });
  }

  group('a dot on a destination', () {
    const dotted = [
      AdaptiveDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Overview',
        dot: 'Activity, 3 unread',
      ),
      AdaptiveDestination(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: 'Upcoming',
      ),
    ];

    Future<void> pumpDotted(
      WidgetTester tester, {
      required TargetPlatform platform,
      bool rail = false,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: rail
              ? Row(
                  children: [
                    AdaptiveNavigationRail(
                      destinations: dotted,
                      selectedIndex: 1,
                      onDestinationSelected: (_) {},
                    ),
                  ],
                )
              : null,
          bottomNavigationBar: rail
              ? null
              : AdaptiveNavigationBar(
                  destinations: dotted,
                  selectedIndex: 1,
                  onDestinationSelected: (_) {},
                ),
        ),
      ),
    );

    Finder dots() => find.byWidgetPredicate(
      (widget) => widget is Badge && widget.isLabelVisible,
    );

    for (final (name, platform, rail) in [
      ('the bar', TargetPlatform.android, false),
      ('the rail', TargetPlatform.android, true),
    ]) {
      testWidgets('$name shows it on that icon, and screen readers hear '
          'it last, as Android reads a hint', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpDotted(tester, platform: platform, rail: rail);

        expect(dots(), findsOneWidget);
        expect(
          find.descendant(
            of: dots(),
            matching: find.byIcon(Icons.home_outlined),
          ),
          findsOneWidget,
        );
        final node = tester.getSemantics(find.text('Overview'));
        expect(node.label, startsWith('Overview'));
        expect(node.hint, 'Activity, 3 unread');
        expect(tester.getSemantics(find.text('Upcoming')).hint, isEmpty);
        semantics.dispose();
      });
    }

    testWidgets("the iOS tab bar: VoiceOver reads it as the tab's value, "
        'after its name', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDotted(tester, platform: TargetPlatform.iOS);

      expect(dots(), findsOneWidget);
      final node = tester.getSemantics(find.text('Overview'));
      expect(node.label, 'Overview');
      expect(node.value, 'Activity, 3 unread');
      semantics.dispose();
    });
  });
}

/// Android's 115 %, as its float arithmetic gives it: a hair above 1.15.
final class _AndroidFloatAt115 extends TextScaler {
  const new();

  @override
  double scale(double fontSize) =>
      fontSize == 12 ? 13.800000190734863 : fontSize * 1.15;

  @override
  double get textScaleFactor => 1.15;
}

/// A simplified curve like Android 14's for 200 %: twice the size at the
/// label's 12 sp (Android's own table grows less above about 14 sp), 100 sp
/// as it is.
final class _Android14At200 extends TextScaler {
  const new();

  @override
  double scale(double fontSize) => switch (fontSize) {
    <= 30 => fontSize * 2,
    < 100 => 60 + (fontSize - 30) * 40 / 70,
    _ => fontSize,
  };

  @override
  double get textScaleFactor => 2;
}
