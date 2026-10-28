import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../a11y/sweep_data.dart';
import '../../a11y/sweep_harness.dart' show routerOf;
import '../../helpers/auth_fakes.dart';
import '../../helpers/back_gestures.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const _iOS = TargetPlatformVariant({TargetPlatform.iOS});

Finder _inPane(Finder matching) =>
    find.descendant(of: find.byType(TaskDetailPane), matching: matching);

Finder _paneTitle(String title) => _inPane(find.text(title));

int? _selected(WidgetTester tester) => tester
    .widget<TaskDetailPaneScope>(find.byType(TaskDetailPaneScope))
    .selectedTaskId;

Future<void> _tapRow(WidgetTester tester, String title) async {
  final row = find.text(title).first;
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _openProject(WidgetTester tester) async {
  goTo(tester, AppRoutes.project(workProjectId));
  await tester.pumpAndSettle();
}

void _expectSheet(WidgetTester tester) {
  expect(find.byType(TaskDetailPane), findsNothing);
  expect(find.byType(TaskDetailSheet), findsOneWidget);
}

void _expectPane(WidgetTester tester, String title) {
  expect(find.byType(TaskDetailPane), findsOneWidget);
  expect(_inPane(find.byType(TaskDetailSheet)), findsOneWidget);
  expect(find.byType(BottomSheet), findsNothing);
  expect(find.byType(ReadableSheetWidth), findsNothing);
  expect(_paneTitle(title), findsWidgets);
}

void main() {
  testWidgets('a row of the Overview opens the task in the pane beside the '
      'list, and the close button closes it', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);

    await _tapRow(tester, 'Call the plumber');
    _expectPane(tester, 'Call the plumber');
    expect(_selected(tester), 1);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TaskDetailPane>(),
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<IconButton>()
          ?.tooltip,
      en.taskEdit,
    );

    final rail = railRight(tester);
    final contentWidth = androidTabletLandscape.width - rail;
    final paneWidth = (contentWidth * 0.4).clamp(360, 480);
    expect(
      tester.getRect(find.byType(TaskDetailPane)).width,
      moreOrLessEquals(paneWidth.toDouble()),
    );
    expect(
      tester.getRect(find.byType(TaskDetailPane)).right,
      androidTabletLandscape.width,
    );

    await tester.tap(_inPane(find.byTooltip(en.taskDetailClose)));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane), findsNothing);
    expect(find.byType(TaskDetailSheet), findsNothing);
    expect(_selected(tester), isNull);
  });

  testWidgets('the 800×600 surface and a phone keep the sheet', (tester) async {
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    _expectSheet(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('on an iPad in landscape the task opens in the pane', (
    tester,
  ) async {
    useWindow(tester, iPad11Landscape);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    _expectPane(tester, 'Call the plumber');
  }, variant: _iOS);

  testWidgets('a related task opens inside the pane, its back arrow returns, '
      'and back goes pane stack, pane, then the project page', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _openProject(tester);

    await _tapRow(tester, 'Plan the team day');
    _expectPane(tester, 'Plan the team day');
    expect(_inPane(find.byType(BackButtonIcon)), findsNothing);

    final related = _inPane(find.byType(RelationRow));
    await tester.scrollUntilVisible(
      related,
      200,
      scrollable: _inPane(find.byType(Scrollable)).first,
    );
    await tester.tap(related);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane), findsOneWidget);
    expect(_selected(tester), 3);
    expect(
      _inPane(find.byTooltip(en.taskDetailPaneBack('Plan the team day'))),
      findsOneWidget,
    );

    await tester.tap(_inPane(find.byType(BackButtonIcon)));
    await tester.pumpAndSettle();
    expect(_selected(tester), 4);
    expect(_inPane(find.byType(BackButtonIcon)), findsNothing);

    await tester.tap(related.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_selected(tester), 3);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_selected(tester), 4);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane), findsNothing);
    expect(
      routerOf(tester).routerDelegate.state.matchedLocation,
      '/home/projects/1',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      routerOf(tester).routerDelegate.state.matchedLocation,
      AppRoutes.projects,
    );
  });

  testWidgets('the edit page opens over the shell with the pane under it', (
    tester,
  ) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    await tester.tap(_inPane(find.byTooltip(en.taskEdit)));
    await tester.pumpAndSettle();
    expect(
      routerOf(tester).routerDelegate.state.matchedLocation,
      AppRoutes.taskEdit(1),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectPane(tester, 'Call the plumber');
  });

  testWidgets('delete closes the pane and says so on the screen beside it', (
    tester,
  ) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    await tester.tap(
      _inPane(find.byTooltip(en.taskDetailPaneMore('Call the plumber'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskDeleteDialogConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane), findsNothing);
    expect(find.text(en.taskDeleted), findsOneWidget);
    expect(
      routerOf(tester).routerDelegate.state.matchedLocation,
      AppRoutes.overview,
    );
  });

  testWidgets('losing the room for the pane opens the same task as a sheet; '
      'growing again keeps the sheet', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    _expectPane(tester, 'Call the plumber');

    useWindow(tester, const Size(700, 1000));
    await tester.pumpAndSettle();
    _expectSheet(tester);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Call the plumber'),
      ),
      findsWidgets,
    );

    useWindow(tester, androidTabletLandscape);
    await tester.pumpAndSettle();
    _expectSheet(tester);
  });

  testWidgets('switching tabs keeps each tab its own pane', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    await openTab(tester, en.tabUpcoming);
    expect(find.byType(TaskDetailPane), findsNothing);
    await openTab(tester, en.tabOverview);
    _expectPane(tester, 'Call the plumber');

    await openTab(tester, en.tabOverview);
    expect(find.byType(TaskDetailPane), findsNothing);
  });

  testWidgets('the task opener shows a task in the Overview pane when there '
      'is room, else in a sheet', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _openProject(tester);
    final opener = containerOf(tester).read(taskOpenerProvider);
    final task = sweepData().tasks.all.firstWhere((task) => task.id == 6);

    unawaited(opener.showTask(task));
    await tester.pumpAndSettle();
    expect(
      routerOf(tester).routerDelegate.state.matchedLocation,
      AppRoutes.overview,
    );
    _expectPane(tester, 'Read the contract');

    pushTo(tester, AppRoutes.search);
    await tester.pumpAndSettle();
    unawaited(opener.showTask(task));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('an account switch closes the panes', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final data = sweepData();
    final auth = AuthFakes();
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: sweepNow, userId: 8, username: 'bob'),
      displayName: 'Bob',
      activate: false,
    );
    data.accounts[bob.id] = AccountDataFakes(now: sweepNow)
      ..projects.all = [sampleProject(id: 7, title: 'Bob project')];
    await pumpSweepApp(tester, data: data, auth: auth);
    await _tapRow(tester, 'Call the plumber');
    _expectPane(tester, 'Call the plumber');

    await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane), findsNothing);
    expect(_selected(tester), isNull);
  });

  testWidgets('another project closes the pane, a page over the shell keeps '
      'it', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _openProject(tester);
    await _tapRow(tester, 'Plan the team day');

    pushTo(tester, AppRoutes.search);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectPane(tester, 'Plan the team day');

    goTo(tester, AppRoutes.project(gardenProjectId));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane), findsNothing);
  });

  testWidgets('losing the room under the edit page opens the sheet once the '
      'shell is in front again', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    await tester.tap(_inPane(find.byTooltip(en.taskEdit)));
    await tester.pumpAndSettle();

    useWindow(tester, androidTabletPortrait);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectSheet(tester);
  });

  testWidgets('a vertical fold places the split on it; a tabletop fold '
      'keeps the sheet', (tester) async {
    useWindow(tester, androidTabletLandscape);
    tester.view.displayFeatures = [
      const DisplayFeature(
        bounds: Rect.fromLTWH(640, 0, 0, 800),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ];
    addTearDown(tester.view.resetDisplayFeatures);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    final pane = tester.getRect(find.byType(TaskDetailPane));
    expect(pane.left, 640);
    expect(pane.width, 640);
    expect(find.byType(VerticalDivider), findsNothing);

    tester.view.displayFeatures = [
      const DisplayFeature(
        bounds: Rect.fromLTWH(0, 400, 1280, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ];
    await tester.pumpAndSettle();
    _expectSheet(tester);
  });

  testWidgets('on the Overview, Android hears that the app handles back '
      'while the pane is open, and no longer once it closed', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final backReports = recordBackReports(tester);
    await pumpSweepApp(tester);
    expect(backReports.last, isFalse);
    await _tapRow(tester, 'Call the plumber');
    expect(backReports.last, isTrue);

    await swipeBack(tester);
    expect(find.byType(TaskDetailPane), findsNothing);
    expect(backReports.last, isFalse);
  });

  testWidgets('a back swipe with the pane open closes the pane, not a page '
      'of a hidden tab', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _openProject(tester);
    await openTab(tester, en.tabOverview);
    await _tapRow(tester, 'Call the plumber');

    await swipeBack(tester);
    expect(find.byType(TaskDetailPane), findsNothing);
    await openTab(tester, en.tabProjects);
    expect(
      routerOf(tester).routerDelegate.state.matchedLocation,
      AppRoutes.project(workProjectId),
    );
  });
}
