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
    required double textScale,
  }) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
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
      MediaQuery.textScalerOf(tester.element(text)).scale(100) / 100;

  testWidgets('iOS: at a size the bar does not follow, a long press shows '
      'the label at the full size, and lifting opens it', (tester) async {
    final selected = await pumpBar(
      tester,
      platform: TargetPlatform.iOS,
      textScale: 2,
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
    await pumpBar(tester, platform: TargetPlatform.iOS, textScale: 1.2);
    final bar = tester.getRect(find.byType(AdaptiveNavigationBar));

    final gesture = await tester.startGesture(
      Offset(bar.left + bar.width * 0.75, bar.center.dy),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('Upcoming'), findsOneWidget);
    await gesture.up();
  });

  testWidgets('Android: the same at a size the bar does not follow, without '
      "the tooltip at the bar's size", (tester) async {
    final selected = await pumpBar(
      tester,
      platform: TargetPlatform.android,
      textScale: 2,
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
