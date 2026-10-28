import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';

import '../../a11y/sweep_data.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/task_detail_panes.dart';

typedef _Site = ({
  String name,
  int taskId,
  Future<void> Function(WidgetTester tester) open,
  Finder Function(int taskId) target,
});

final _android = TargetPlatformVariant.only(TargetPlatform.android);

const _titles = [
  'Call the plumber',
  'Buy seeds',
  'Write the report',
  'Plan the team day',
  'Water the roses',
  'Read the contract',
  'Send the invoice',
];

Future<void> _pumpWithView(WidgetTester tester, int viewId) async {
  final data = sweepData();
  data.listPreferences.lastViews[workProjectId] = viewId;
  await pumpSweepApp(tester, data: data);
  goTo(tester, AppRoutes.project(workProjectId));
  await tester.pumpAndSettle();
}

Future<void> _pumpAt(WidgetTester tester, String location) async {
  await pumpSweepApp(tester);
  goTo(tester, location);
  await tester.pumpAndSettle();
}

final List<_Site> _tabSites = [
  (name: 'the Overview', taskId: 1, open: pumpSweepApp, target: taskRowOf),
  (
    name: 'Upcoming',
    taskId: 3,
    open: (tester) => _pumpAt(tester, AppRoutes.upcoming),
    target: taskRowOf,
  ),
  (
    name: 'the Favourites',
    taskId: 6,
    open: (tester) => _pumpAt(tester, AppRoutes.project(Project.favoritesId)),
    target: taskRowOf,
  ),
  (
    name: "a project's list",
    taskId: 4,
    open: (tester) => _pumpWithView(tester, listViewId),
    target: taskRowOf,
  ),
  (
    name: "a project's table",
    taskId: 4,
    open: (tester) => _pumpWithView(tester, tableViewId),
    target: taskRowOf,
  ),
  (
    name: "a project's board",
    taskId: 4,
    open: (tester) => _pumpWithView(tester, kanbanViewId),
    target: boardCardOf,
  ),
  (
    name: "a project's timeline",
    taskId: 3,
    open: (tester) => _pumpWithView(tester, ganttViewId),
    target: (taskId) => find.descendant(
      of: timelineRowOf(taskId),
      matching: find.text('Write the report'),
    ),
  ),
];

void _expectNoRowSelected(WidgetTester tester) {
  final states = selectedStatesOf(tester, _titles);
  expect(states, isNotEmpty);
  expect(
    [
      for (final state in states)
        if (state.selected != Tristate.none) state.label,
    ],
    isEmpty,
    reason: 'rows with a selected state',
  );
}

void main() {
  group('a task opens in the pane beside the list', () {
    for (final (size, variant) in [
      (androidTabletLandscape, _android),
      (iPad11Landscape, iOSOnly),
    ]) {
      for (final site in _tabSites) {
        testWidgets('from ${site.name} at ${sizeName(size)}', (tester) async {
          useWindow(tester, size);
          await site.open(tester);
          await tapOutsidePane(tester, site.target(site.taskId));
          expectPane(tester, taskId: site.taskId);
          expect(paneTaskId(tester), site.taskId);
          expect(tester.takeException(), isNull);
        }, variant: variant);
      }
    }

    for (final size in [iPad13Portrait, iPad13Landscape]) {
      testWidgets('on the 13" iPad at ${sizeName(size)}', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);
        await tapTaskRow(tester, 1);
        expectPane(tester, taskId: 1);
      }, variant: iOSOnly);
    }
  });

  group('pages over the shell open the sheet', () {
    for (final (size, variant) in [
      (androidTabletLandscape, _android),
      (iPad11Landscape, iOSOnly),
    ]) {
      testWidgets('search at ${sizeName(size)}', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);
        pushTo(tester, AppRoutes.search);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(SearchPage),
            matching: find.byType(TextField),
          ),
          'plumber',
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await tapOutsidePane(
          tester,
          find.descendant(of: find.byType(SearchPage), matching: taskRowOf(1)),
        );
        expectSheet(tester, taskId: 1);
        expect(find.byType(SearchPage), findsOneWidget);
      }, variant: variant);

      testWidgets('label tasks at ${sizeName(size)}', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);
        pushTo(tester, AppRoutes.labelTasks(calls.id));
        await tester.pumpAndSettle();
        await tapOutsidePane(
          tester,
          find.descendant(
            of: find.byType(LabelTasksScreen),
            matching: taskRowOf(1),
          ),
        );
        expectSheet(tester, taskId: 1);
        expect(find.byType(LabelTasksScreen), findsOneWidget);
      }, variant: variant);

      testWidgets('the inbox at ${sizeName(size)}', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);
        pushTo(tester, AppRoutes.inbox);
        await tester.pumpAndSettle();
        unawaited(
          containerOf(tester)
              .read(taskOpenerProvider)
              .openInActiveAccount(const TaskById(1)),
        );
        await tester.pumpAndSettle();
        expectSheet(tester, taskId: 1);
        expect(find.byType(InboxScreen), findsOneWidget);
      }, variant: variant);
    }
  });

  group('without room for the pane a row opens the sheet', () {
    for (final (size, variant) in [
      for (final size in [
        androidPhone,
        androidSmallLandscape,
        androidLandscape,
        defaultSurface,
        androidTabletPortrait,
      ])
        (size, _android),
      for (final size in [
        iPhone,
        iPhoneLandscape,
        iPad11Portrait,
        iPadMiniPortrait,
      ])
        (size, iOSOnly),
    ]) {
      testWidgets('at ${sizeName(size)}', (tester) async {
        useWindow(tester, size);
        final semantics = tester.ensureSemantics();
        await pumpSweepApp(tester);
        _expectNoRowSelected(tester);

        await tapTaskRow(tester, 1);
        expectSheet(tester, taskId: 1);
        final scope = tester.widget<TaskDetailPaneScope>(
          find.byType(TaskDetailPaneScope),
        );
        expect(scope.available, isFalse);
        expect(scope.selectedTaskId, isNull);
        _expectNoRowSelected(tester);
        semantics.dispose();
      }, variant: variant);
    }
  });
}
