import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/platform/app_backgrounding.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_configure_page.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../accounts/accounts_harness.dart';
import 'widget_pages_harness.dart';

void main() {
  late WidgetPagesHarness harness;

  setUp(() => harness = WidgetPagesHarness());

  final page = find.byType(WidgetConfigurePage);

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(of: page, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapInPage(WidgetTester tester, String text) async {
    final finder = find.descendant(of: page, matching: find.text(text));
    await scrollTo(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String title) async {
    final row = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(title),
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// The configs the save published.
  Future<List<WidgetConfig>> save(WidgetTester tester) async {
    final before = harness.refresher.published.length;
    await tester.tap(find.text(en.widgetConfigureSave));
    await tester.pumpAndSettle();
    return harness.refresher.published.sublist(before);
  }

  testWidgets('a new widget shows Today of the active account, with its '
      'preview, until saved', (tester) async {
    await harness.pump(tester);
    final today = WidgetConfig(
      accountId: harness.activeAccountId(tester),
      kind: const TodayKind(),
    );
    harness.refresher.previews[today] = samplePreview(
      today,
      title: 'Today',
      total: 9,
    );
    unawaited(harness.routerOf(tester).push(AppRoutes.widgetConfigure(12)));
    await tester.pumpAndSettle();

    expect(page, findsOneWidget);
    expect(harness.refresher.previewed, [today]);
    // One account: nothing to choose.
    expect(find.text(en.widgetConfigureAccountHeading), findsNothing);
    await scrollTo(tester, find.text('+7 more'));
    expect(
      find.text('Preview task 1 with a title long enough to wrap'),
      findsOneWidget,
    );
    expect(find.text('Yesterday'), findsOneWidget);
    expect(harness.host.placed, isEmpty);

    final published = await save(tester);

    expect(harness.host.placed, {12: today});
    expect(harness.host.calls, contains('saveConfig 12'));
    expect(published, [today]);
    expect(page, findsNothing);
    expect(find.text(en.widgetConfigureSaved), findsOneWidget);
  });

  testWidgets('set up from the home screen, Save returns there; from the '
      'widgets page, it stays in the app', (tester) async {
    final background = _RecordingBackgrounding();
    await harness.pump(
      tester,
      overrides: [appBackgroundingProvider.overrideWithValue(background)],
    );

    unawaited(harness.routerOf(tester).push(AppRoutes.widgetConfigure(12)));
    await tester.pumpAndSettle();
    await save(tester);
    expect(background.moves, 0);

    unawaited(
      harness
          .routerOf(tester)
          .push(AppRoutes.widgetConfigure(12, fromWidget: true)),
    );
    await tester.pumpAndSettle();
    await save(tester);
    expect(page, findsNothing);
    expect(background.moves, 1);
  });

  testWidgets('a saved setup comes back and its days change', (tester) async {
    await harness.pump(tester);
    final account = harness.activeAccountId(tester);
    harness.host.placed[12] = WidgetConfig(
      accountId: account,
      kind: const UpcomingKind(14),
    );
    unawaited(harness.routerOf(tester).push(AppRoutes.widgetConfigure(12)));
    await tester.pumpAndSettle();

    final fourteen = find.widgetWithText(ChoiceChip, en.widgetUpcomingDays(14));
    expect(tester.widget<ChoiceChip>(fourteen).selected, isTrue);
    await tapInPage(tester, en.widgetUpcomingDays(3));
    await save(tester);

    expect(
      harness.host.placed[12],
      WidgetConfig(accountId: account, kind: const UpcomingKind(3)),
    );
  });

  testWidgets('a project comes from the tree without archived ones', (
    tester,
  ) async {
    await harness.pump(tester, location: AppRoutes.widgetConfigure(3));

    await tapInPage(tester, en.widgetKindProject);
    expect(find.text('Old stuff'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
    await pick(tester, 'Garage Sale');

    expect(
      find.descendant(of: page, matching: find.text('Garage Sale')),
      findsOneWidget,
    );
    await save(tester);
    expect(harness.host.placed[3]?.kind, const ProjectTasksKind(3));
  });

  testWidgets('a label and a saved filter are picked the same way', (
    tester,
  ) async {
    await harness.seedLabels();
    await harness.pump(tester, location: AppRoutes.widgetConfigure(3));

    await tapInPage(tester, en.widgetKindLabel);
    await pick(tester, 'Errands');
    expect(
      find.descendant(of: page, matching: find.text('Errands')),
      findsOneWidget,
    );

    await tapInPage(tester, en.widgetKindSavedFilter);
    await pick(tester, 'Urgent');
    await save(tester);

    expect(harness.host.placed[3]?.kind, const SavedFilterKind(2));
  });

  testWidgets('dismissing a picker keeps the choice', (tester) async {
    await harness.pump(tester, location: AppRoutes.widgetConfigure(3));

    await tapInPage(tester, en.widgetKindLabel);
    expect(find.text(en.widgetConfigureNoLabels), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await save(tester);

    expect(harness.host.placed[3]?.kind, const TodayKind());
  });

  testWidgets('a failed save says so and stays', (tester) async {
    await harness.pump(tester, location: AppRoutes.widgetConfigure(3));
    harness.host.failure = Exception('disk full');

    final published = await save(tester);

    expect(page, findsOneWidget);
    expect(find.text(en.widgetConfigureSaveFailed), findsOneWidget);
    expect(published, isEmpty);
  });

  testWidgets('a guest has no saved filters', (tester) async {
    final auth = AuthFakes();
    await pumpGuestApp(
      tester,
      auth: auth,
      data: harness.data,
      overrides: harness.overrides,
    );
    unawaited(harness.routerOf(tester).push(AppRoutes.widgetConfigure(3)));
    await tester.pumpAndSettle();

    expect(page, findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text(en.widgetKindLabel)),
      findsOneWidget,
    );
    expect(find.text(en.widgetKindSavedFilter), findsNothing);
  });

  testWidgets('with several accounts the account is chosen first, and a '
      'project of the previous one goes', (tester) async {
    final accounts = ThreeAccounts();
    await accounts.seed();
    accounts.aliceData.projects.all = [sampleProject(id: 1, title: 'Work')];
    accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
    harness.host.placed[3] = WidgetConfig(
      accountId: accounts.alice.id,
      kind: const ProjectTasksKind(1),
    );
    await accounts.pump(tester, overrides: harness.overrides);
    unawaited(harness.routerOf(tester).push(AppRoutes.widgetConfigure(3)));
    await tester.pumpAndSettle();

    expect(find.text(en.widgetConfigureAccountHeading), findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text('Work')),
      findsOneWidget,
    );
    await tapInPage(tester, 'Bob');
    final published = await save(tester);

    final bobToday = WidgetConfig(
      accountId: accounts.bob.id,
      kind: const TodayKind(),
    );
    expect(harness.host.placed[3], bobToday);
    expect(published, [bobToday]);
  });
}

final class _RecordingBackgrounding implements AppBackgrounding {
  int moves = 0;

  @override
  Future<void> moveToBack() async => moves++;
}
