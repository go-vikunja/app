import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_configure_page.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widgets_page.dart';

import '../features/accounts/accounts_harness.dart';
import '../features/widgets/widget_pages_harness.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';

// The home-screen widgets page and a widget's setup at 200 % text in dark
// mode on a small phone, in English and German. Layout overflows are
// reported as test failures, so reaching the end of each scenario without
// an exception is the assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

  void useWorstCase(WidgetTester tester, Locale locale) {
    usePhoneSurface(tester, logicalSize: smallPhone);
    useAccessibilityExtremes(tester);
    useLocale(tester, locale);
  }

  Future<void> scrollToEnd(WidgetTester tester, Type page) async {
    final scrollable = find
        .descendant(of: find.byType(page), matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    for (var i = 0; i < 80 && position.extentAfter > 0; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  /// Scrolls [page]'s list until [finder] shows, then to its top: a row
  /// just inside the edge would take a tap meant for its middle elsewhere.
  Future<void> bringIntoView(
    WidgetTester tester,
    Type page,
    Finder finder, {
    double delta = 200,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find
          .descendant(of: find.byType(page), matching: find.byType(Scrollable))
          .first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  for (final locale in locales) {
    testWidgets('the widgets page with placed widgets and the "cannot add" '
        'note at 200 % in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final harness = WidgetPagesHarness(launcherDeclinesPins: true);
      await harness.pump(tester);
      final account = harness.activeAccountId(tester);
      final project = WidgetConfig(
        accountId: account,
        kind: const ProjectTasksKind(3),
      );
      harness.host.placed
        ..[12] = project
        ..[13] = WidgetConfig(accountId: account, kind: const UpcomingKind(14))
        ..[14] = const WidgetConfig(accountId: 'removed', kind: TodayKind());
      harness.refresher.previews[project] = samplePreview(
        project,
        title: 'A project with a name long enough to wrap twice',
      );
      unawaited(harness.routerOf(tester).push(AppRoutes.widgets));
      await tester.pumpAndSettle();

      expect(find.byType(WidgetsPage), findsOneWidget);
      await bringIntoView(
        tester,
        WidgetsPage,
        find.text(l10n.widgetKindFavorites),
      );
      await tester.tap(find.text(l10n.widgetKindFavorites));
      await tester.pumpAndSettle();
      await bringIntoView(
        tester,
        WidgetsPage,
        find.text(l10n.widgetsPinUnsupported),
      );
      await scrollToEnd(tester, WidgetsPage);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a widget setup with several accounts, the days, a picker and '
        'the preview at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final harness = WidgetPagesHarness();
      final accounts = ThreeAccounts();
      await accounts.seed(aliceName: 'Alice Example-Longname von Beispiel');
      accounts.aliceData.projects.all = [
        for (var i = 1; i <= 12; i++)
          sampleProject(
            id: i,
            title: 'A project with a rather long title number $i',
            parent: i > 6 ? 1 : 0,
            hexColor: i.isEven ? 'ff006e' : '',
          ),
      ];
      final upcoming = WidgetConfig(
        accountId: accounts.alice.id,
        kind: const UpcomingKind(7),
      );
      harness.host.placed[21] = upcoming;
      harness.refresher.previews[upcoming] = samplePreview(
        upcoming,
        title: l10n.widgetKindUpcoming,
        subtitle: 'Alice Example-Longname von Beispiel · vikunja.example.com',
        rows: 3,
        total: 12,
      );
      await accounts.pump(tester, overrides: harness.overrides);
      unawaited(harness.routerOf(tester).push(AppRoutes.widgetConfigure(21)));
      await tester.pumpAndSettle();

      expect(find.byType(WidgetConfigurePage), findsOneWidget);
      await scrollToEnd(tester, WidgetConfigurePage);
      expect(tester.takeException(), isNull);

      final projectRow = find.descendant(
        of: find.byType(WidgetConfigurePage),
        matching: find.text(l10n.widgetKindProject),
      );
      await bringIntoView(tester, WidgetConfigurePage, projectRow, delta: -200);
      await tester.tap(projectRow);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a widget setup whose account ended, without a preview, at '
        '200 % in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final harness = WidgetPagesHarness();
      await harness.pump(tester);
      final config = WidgetConfig(
        accountId: harness.activeAccountId(tester),
        kind: const TodayKind(),
      );
      harness.refresher.previews[config] = WidgetSnapshot(
        key: config.key,
        accountId: config.accountId,
        state: WidgetSnapshotState.needsReauth,
        title: 'Today',
        generatedAt: widgetsNow,
        validUntil: widgetsNow,
        message: const WidgetText(
          'Your session ended. Sign in again to see new tasks.',
          body: 'The list below is from before.',
          action: 'Sign in again',
        ),
      );
      unawaited(harness.routerOf(tester).push(AppRoutes.widgetConfigure(4)));
      await tester.pumpAndSettle();

      await scrollToEnd(tester, WidgetConfigurePage);
      expect(tester.takeException(), isNull);
    });
  }
}
