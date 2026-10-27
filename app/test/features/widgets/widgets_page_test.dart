import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_configure_page.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widgets_page.dart';

import '../../helpers/pump_app.dart';
import 'widget_pages_harness.dart';

void main() {
  late WidgetPagesHarness harness;

  setUp(() => harness = WidgetPagesHarness());

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(WidgetsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Account tab leads to the widgets page', (tester) async {
    await harness.pump(tester);
    await openTab(tester, en.tabAccount);

    final entry = find.text(en.widgetsEntryTitle);
    await tester.scrollUntilVisible(
      entry,
      200,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(WidgetsPage), findsOneWidget);
    expect(harness.routerOf(tester).state.matchedLocation, AppRoutes.widgets);
    expect(find.text(en.widgetsIntro), findsOneWidget);
    await scrollTo(tester, find.text(en.widgetsPrivacyNote));
    expect(find.text(en.widgetsPrivacyNote), findsOneWidget);
  });

  testWidgets('Android adds a kind for the active account', (tester) async {
    await harness.pump(tester, location: AppRoutes.widgets);

    expect(find.text(en.widgetsHowToAndroid), findsOneWidget);
    expect(find.text(en.widgetsHowToIos), findsNothing);
    await scrollTo(tester, find.text(en.widgetKindQuickAdd));
    await tester.tap(find.text(en.widgetKindQuickAdd));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text(en.widgetKindUpcoming));
    await tester.tap(find.text(en.widgetKindUpcoming));
    await tester.pumpAndSettle();

    final account = harness.activeAccountId(tester);
    final requested = [
      WidgetConfig(accountId: account, kind: const QuickAddKind()),
      WidgetConfig(accountId: account, kind: const UpcomingKind(7)),
    ];
    expect(harness.host.pinRequests, requested);
    expect(
      harness.refresher.published,
      requested,
      reason: 'the snapshot is there before the launcher draws the widget',
    );
    expect(find.text(en.widgetsPinUnsupported), findsNothing);
  });

  testWidgets("the launcher's dialog does not lock the app until the app is "
      'back from it', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await harness.pump(tester, location: AppRoutes.widgets);
    final excursions = containerOf(tester).read(appExcursionsProvider);

    await scrollTo(tester, find.text(en.widgetKindToday));
    await tester.tap(find.text(en.widgetKindToday));
    await tester.pumpAndSettle();
    expect(harness.host.pinRequests, hasLength(1));
    expect(excursions.active, isTrue);

    const [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(excursions.active, isFalse);
  });

  testWidgets('a launcher that cannot pin leaves only the steps', (
    tester,
  ) async {
    harness.host.pinSupported = false;
    await harness.pump(tester, location: AppRoutes.widgets);

    expect(find.text(en.widgetsHowToAndroid), findsOneWidget);
    expect(find.text(en.widgetsAddHeading), findsNothing);
  });

  testWidgets('a launcher that declines says so on the page', (tester) async {
    harness = WidgetPagesHarness(launcherDeclinesPins: true);
    await harness.pump(tester, location: AppRoutes.widgets);

    await scrollTo(tester, find.text(en.widgetKindToday));
    await tester.tap(find.text(en.widgetKindToday));
    await tester.pumpAndSettle();

    expect(harness.host.pinRequests, hasLength(1));
    expect(containerOf(tester).read(appExcursionsProvider).active, isFalse);
    await scrollTo(tester, find.text(en.widgetsPinUnsupported));
    expect(find.text(en.widgetsPinUnsupported), findsOneWidget);
  });

  testWidgets('iOS explains the Home Screen and adds nothing itself', (
    tester,
  ) async {
    await harness.pump(tester, location: AppRoutes.widgets);

    expect(find.text(en.widgetsHowToIos), findsOneWidget);
    expect(find.text(en.widgetsAddHeading), findsNothing);
    expect(find.text(en.widgetsPlacedHeading), findsNothing);
    expect(harness.host.pinRequests, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('placed widgets show what they show and open their setup', (
    tester,
  ) async {
    await harness.pump(tester);
    final account = harness.activeAccountId(tester);
    final project = WidgetConfig(
      accountId: account,
      kind: const ProjectTasksKind(3),
    );
    harness.host.placed
      ..[12] = project
      ..[14] = const WidgetConfig(accountId: 'removed', kind: TodayKind())
      ..[16] = null;
    harness.refresher.previews[project] = samplePreview(
      project,
      title: 'Garage Sale',
    );
    unawaited(harness.routerOf(tester).push(AppRoutes.widgets));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(en.widgetsPlacedNotSetUp));
    expect(find.text(en.widgetsPlacedAccountRemoved), findsOneWidget);
    expect(find.text('Garage Sale'), findsOneWidget);
    expect(find.text(en.widgetKindProject), findsOneWidget);

    await tester.tap(find.text('Garage Sale'));
    await tester.pumpAndSettle();
    expect(find.byType(WidgetConfigurePage), findsOneWidget);
    expect(
      harness.routerOf(tester).state.uri.toString(),
      AppRoutes.widgetConfigure(12),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.widgetsPlacedNotSetUp));
    await tester.pumpAndSettle();
    expect(
      harness.routerOf(tester).state.uri.toString(),
      AppRoutes.widgetConfigure(16),
      reason: 'below Android 12 the only way to set it up',
    );
  });
}
