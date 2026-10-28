import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTabBar;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_chart.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

import '../../a11y/readable_widths.dart' show readableContentBoxes;
import '../../a11y/sweep_data.dart';
import '../../a11y/sweep_harness.dart' show routerOf;
import '../../helpers/announcer_region.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_detail_panes.dart';

final _android = TargetPlatformVariant.only(TargetPlatform.android);

SyncFakes _offlineData() {
  const unreachable = NetworkFailure(NetworkProblem.unreachable);
  return sweepData(
    status: SyncFailed(
      failure: unreachable,
      lastSyncedAt: sweepNow.subtract(const Duration(days: 3)),
    ),
  )..engine.onRefresh = () async => throw unreachable;
}

Rect _paneRect(WidgetTester tester) =>
    tester.getRect(find.byType(TaskDetailPane));

Future<void> _pumpWithView(
  WidgetTester tester,
  int viewId, {
  SyncFakes? data,
}) async {
  final seeded = data ?? sweepData();
  seeded.listPreferences.lastViews[workProjectId] = viewId;
  await pumpSweepApp(tester, data: seeded);
  goTo(tester, AppRoutes.project(workProjectId));
  await tester.pumpAndSettle();
}

/// Where the focused node is: the rail, the list (the tab's screen with its
/// FAB), the pane or the offline banner.
String? _focusRegion() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  if (context.findAncestorWidgetOfExactType<NavigationRail>() != null) {
    return 'rail';
  }
  if (context.findAncestorWidgetOfExactType<TaskDetailPane>() != null) {
    return 'pane';
  }
  if (context.findAncestorWidgetOfExactType<OfflineBanner>() != null) {
    return 'banner';
  }
  if (context.findAncestorWidgetOfExactType<TaskDetailPaneScope>() != null) {
    return 'list';
  }
  return 'elsewhere';
}

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

bool _onRow(int taskId) =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<TaskRow>()
        ?.task
        .id ==
    taskId;

/// Tabs to the row of [taskId] and presses Enter on it.
Future<void> _enterOnRow(WidgetTester tester, int taskId) async {
  for (var presses = 0; presses < 150 && !_onRow(taskId); presses++) {
    await _tab(tester);
  }
  expect(_onRow(taskId), isTrue, reason: 'Tab reaches the row');
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

/// The Semantics around the tabs, which makes the list a region of its own
/// beside the pane.
Semantics _listRegion(WidgetTester tester) => tester.widget<Semantics>(
  find
      .ancestor(
        of: find.byType(TaskDetailPaneScope),
        matching: find.byType(Semantics),
      )
      .first,
);

/// The semantics nodes with a label or value, in a screen reader's order,
/// each with whether it lies in [region].
List<({String label, bool inRegion})> _traversal(
  WidgetTester tester,
  SemanticsNode region,
) {
  final nodes = <({String label, bool inRegion})>[];
  void visit(SemanticsNode node, {required bool inRegion}) {
    final inside = inRegion || node == region;
    if (node.isMergedIntoParent) return;
    final data = node.getSemanticsData();
    if (data.label.isNotEmpty || data.value.isNotEmpty) {
      nodes.add((label: '${data.label}${data.value}', inRegion: inside));
    }
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child, inRegion: inside);
    }
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
    inRegion: false,
  );
  return nodes;
}

void main() {
  group('beside the list', () {
    for (final (size, variant) in [
      (androidTabletLandscape, _android),
      (iPad11Landscape, iOSOnly),
    ]) {
      testWidgets('at ${sizeName(size)}: the pane on the end side, its '
          'divider, the list up to it, the FAB and the banner', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester, data: _offlineData());
        await tapTaskRow(tester, 1);

        final pane = _paneRect(tester);
        expect(pane.width, moreOrLessEquals(expectedPaneWidth(tester, size)));
        expect(pane.right, size.width);

        final divider = tester.getRect(find.byType(VerticalDivider));
        expect(divider.width, 1);
        expect(divider.right, pane.left);
        final context = tester.element(find.byType(VerticalDivider));
        final line = tester.widget<Container>(
          find.descendant(
            of: find.byType(VerticalDivider),
            matching: find.byType(Container),
          ),
        );
        final border = (line.decoration! as BoxDecoration).border! as Border;
        expect(border.left.color, Theme.of(context).colorScheme.outlineVariant);
        expect(border.left.width, 1);

        final list = tester.getRect(find.byType(TaskDetailPaneScope));
        expect(list.left, railRight(tester));
        expect(list.right, divider.left);

        expect(
          tester.getRect(find.byType(FloatingActionButton)).right,
          lessThanOrEqualTo(pane.left),
        );

        final banner = tester.getRect(find.byType(OfflineBanner));
        expect(banner.left, railRight(tester));
        expect(banner.right, size.width);
        expect(pane.bottom, lessThanOrEqualTo(banner.top));

        if (variant == iOSOnly) {
          expect(
            banner.bottom,
            tester.getRect(find.byType(CupertinoTabBar)).top,
          );
        }
      }, variant: variant);
    }

    for (final size in [iPad11Landscape, iPad13Portrait]) {
      testWidgets('at ${sizeName(size)} the pane sits on the tab bar', (
        tester,
      ) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);
        await tapTaskRow(tester, 1);
        expect(
          _paneRect(tester).bottom,
          tester.getRect(find.byType(CupertinoTabBar)).top,
        );
      }, variant: iOSOnly);
    }

    for (final (size, variant) in [
      (androidTabletLandscape, _android),
      (iPad11Landscape, iOSOnly),
    ]) {
      testWidgets('at ${sizeName(size)} the board ends at the divider', (
        tester,
      ) async {
        useWindow(tester, size);
        await _pumpWithView(tester, kanbanViewId);
        await tapOutsidePane(tester, boardCardOf(4));
        expect(
          tester.getRect(find.byType(ProjectBoard)).right,
          moreOrLessEquals(listRightBesidePane(tester)),
        );
      }, variant: variant);

      testWidgets('at ${sizeName(size)} the timeline ends at the divider', (
        tester,
      ) async {
        useWindow(tester, size);
        await _pumpWithView(tester, ganttViewId);
        await tapOutsidePane(
          tester,
          find.descendant(
            of: timelineRowOf(3),
            matching: find.text('Write the report'),
          ),
        );
        expectPane(tester, taskId: 3);
        expect(
          tester.getRect(find.byType(TimelineChart)).right,
          moreOrLessEquals(listRightBesidePane(tester)),
        );
      }, variant: variant);
    }

    testWidgets('at 1366×1024 the list beside the pane keeps to 840 with '
        'equal margins', (tester) async {
      useWindow(tester, iPad13Landscape);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      final listRight = listRightBesidePane(tester);
      expect(listRight, 1366 - 1 - 480);
      final band = readableBand(tester, ReadableWidth.list, right: listRight);
      expect(band.left, 22.5);
      expect(band.right, 885 - 22.5);
      final boxes = find.descendant(
        of: find.byType(OverviewScreen),
        matching: readableContentBoxes,
      );
      expect(boxes, findsWidgets);
      final rects = [
        for (final box in boxes.evaluate())
          tester.getRect(find.byElementPredicate((element) => element == box)),
      ];
      for (final rect in rects) {
        expectInBand(rect, band);
      }
      expect(
        rects.map((rect) => rect.left).reduce(math.min),
        lessThanOrEqualTo(band.left + 16),
      );
      expect(
        rects.map((rect) => rect.right).reduce(math.max),
        greaterThanOrEqualTo(band.right - 16),
      );
    }, variant: iOSOnly);

    testWidgets("opening and closing the pane keep the list's offset and "
        "the tab's pages", (tester) async {
      useWindow(tester, androidTabletLandscape);
      final data = sweepData();
      data.tasks.all = [
        ...data.tasks.all,
        for (var id = 100; id < 130; id++)
          sampleTask(id: id, title: 'Filler $id'),
      ];
      await pumpSweepApp(tester, data: data);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();
      final row = taskRowOf(120);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      final tab = Navigator.of(tester.element(row));
      final pages = tab.widget.pages.length;
      final position = Scrollable.of(tester.element(row)).position;
      final offset = position.pixels;
      expect(offset, greaterThan(0));

      await tester.tap(row);
      await tester.pumpAndSettle();
      expectPane(tester, taskId: 120);
      expect(Scrollable.of(tester.element(row)).position, same(position));
      expect(position.pixels, offset);
      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(Scrollable.of(tester.element(row)).position, same(position));
      expect(position.pixels, offset);
      expect(Navigator.of(tester.element(row)), same(tab));
      expect(tab.widget.pages.length, pages);
      expect(
        routerOf(tester).routerDelegate.state.matchedLocation,
        AppRoutes.project(workProjectId),
      );
    });
  });

  group('focus and screen readers', () {
    testWidgets('open, a task inside and back put the focus in the pane; '
        'close returns it to the row it came from by Enter', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();

      await _enterOnRow(tester, 4);
      expectPane(tester, taskId: 4);
      expect(_focusRegion(), 'pane');

      await openRelatedInPane(tester);
      expect(paneTaskId(tester), 3);
      expect(_focusRegion(), 'pane');

      await tester.tap(inPane(find.byType(BackButtonIcon)));
      await tester.pumpAndSettle();
      expect(paneTaskId(tester), 4);
      expect(_focusRegion(), 'pane');

      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(_onRow(4), isTrue);
    });

    testWidgets('close returns the focus to the row of the task shown, not '
        'to the first row that opened the pane', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();

      await _enterOnRow(tester, 4);
      expectPane(tester, taskId: 4);
      await _enterOnRow(tester, 3);
      expectPane(tester, taskId: 3);
      expect(_focusRegion(), 'pane');

      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(_onRow(3), isTrue);
    });

    testWidgets('close leaves the focus in the list when the row that opened '
        'the pane has scrolled away', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final data = sweepData();
      data.tasks.all = [
        ...data.tasks.all,
        for (var id = 100; id < 140; id++)
          sampleTask(id: id, title: 'Filler $id'),
      ];
      await pumpSweepApp(tester, data: data);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();

      // The first row.
      await _enterOnRow(tester, 139);
      expectPane(tester, taskId: 139);
      final row = tester.element(taskRowOf(139));
      final list = Scrollable.of(row).position;
      list.jumpTo(list.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(row.mounted, isFalse, reason: 'the row has left the list');

      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(_focusRegion(), 'list');
    });

    testWidgets('the pane adds no node of its own around the task; its '
        'identifier is read alone, after the back arrow', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();
      await tapTaskRow(tester, 4);
      await openRelatedInPane(tester);
      expect(paneTaskId(tester), 3);

      final pane = _paneRect(tester);
      final nodes = semanticsInOrder(paneRegion(tester));
      for (final node in nodes) {
        final data = node.getSemanticsData();
        final focusable = data.flagsCollection.isFocused != Tristate.none;
        final large =
            node.rect.width >= pane.width - 1 &&
            node.rect.height >= pane.height / 2;
        expect(
          focusable && large && !data.hasAction(SemanticsAction.tap),
          isFalse,
          reason: '$node',
        );
      }

      final back = nodes.indexWhere(
        (node) =>
            node.getSemanticsData().tooltip ==
            en.taskDetailPaneBack('Plan the team day'),
      );
      final identifier = nodes.indexWhere(
        (node) => node.label.startsWith('WORK-'),
      );
      expect(back, isNot(-1));
      expect(identifier, greaterThan(back));
      expect(nodes[identifier].label, 'WORK-3');
      expect(nodes[identifier].childrenCount, 0);
      semantics.dispose();
    });

    testWidgets('beside the pane the list is a region of its own without the '
        "pane's nodes; without a pane there is none", (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      expect(_listRegion(tester).container, isFalse);
      expect(_listRegion(tester).explicitChildNodes, isFalse);

      await tapTaskRow(tester, 1);
      expect(_listRegion(tester).container, isTrue);
      expect(_listRegion(tester).explicitChildNodes, isTrue);
      final list = tester.getSemantics(find.byType(TaskDetailPaneScope));
      expect(list.rect.size, tester.getSize(find.byType(TaskDetailPaneScope)));
      final listNodes = semanticsInOrder(list);
      expect(
        listNodes.where((node) => node.label.contains('Call the plumber')),
        isNotEmpty,
      );
      final paneNodes = semanticsInOrder(paneRegion(tester)).toSet();
      expect(paneNodes, isNotEmpty);
      expect(listNodes.where(paneNodes.contains), isEmpty);
      expect(paneNodes.contains(list), isFalse);
      semantics.dispose();
    });

    for (final size in [androidPhone, defaultSurface]) {
      testWidgets('at ${sizeName(size)} the list is no region of its own, '
          'with the sheet open too', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);
        expect(_listRegion(tester).container, isFalse);
        expect(_listRegion(tester).explicitChildNodes, isFalse);
        await tapTaskRow(tester, 1);
        expectSheet(tester, taskId: 1);
        expect(_listRegion(tester).container, isFalse);
        expect(_listRegion(tester).explicitChildNodes, isFalse);
      });
    }

    testWidgets('opening, changing and closing the pane announce nothing', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();
      tester.takeAnnouncements();

      await tapTaskRow(tester, 4);
      await openRelatedInPane(tester);
      await tester.tap(inPane(find.byType(BackButtonIcon)));
      await tester.pumpAndSettle();
      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(tester.takeAnnouncements(), isEmpty);
      expect(announcerRegion(tester)?.label ?? '', isEmpty);
      semantics.dispose();
    });

    testWidgets('Tab goes from the rail through the list to the pane, then '
        'the banner', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester, data: _offlineData());
      await tapTaskRow(tester, 1);
      expect(_focusRegion(), 'pane');

      final regions = <String?>[_focusRegion()];
      for (var presses = 0; presses < 120; presses++) {
        await _tab(tester);
        final region = _focusRegion();
        if (region != regions.last) regions.add(region);
        if (regions.length > 5) break;
      }
      // From the pane round to it once more.
      expect(regions.take(5), ['pane', 'banner', 'rail', 'list', 'pane']);
    });

    testWidgets('a screen reader reads the list before the pane', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      final paneRegion = tester.getSemantics(
        find
            .descendant(
              of: find.byType(TaskDetailPane),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.container &&
                    widget.explicitChildNodes,
              ),
            )
            .first,
      );
      final nodes = _traversal(tester, paneRegion);
      final inPaneNodes = [
        for (final (index, node) in nodes.indexed)
          if (node.inRegion) index,
      ];
      expect(inPaneNodes, isNotEmpty);
      final listRows = [
        for (final (index, node) in nodes.indexed)
          if (!node.inRegion &&
              (node.label.contains('Write the report') ||
                  node.label.contains('Read the contract')))
            index,
      ];
      expect(listRows, isNotEmpty);
      expect(listRows.last, lessThan(inPaneNodes.first), reason: '$nodes');
      semantics.dispose();
    });
  });

  testWidgets("a row's Done snackbar spans the list and the pane, and goes "
      'after its time', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await tapTaskRow(tester, 1);
    final row = taskRowOf(3);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.byType(TaskDoneControl)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final snackBar = tester.getRect(find.byType(SnackBar));
    final pane = _paneRect(tester);
    expect(snackBar.left, lessThan(pane.left));
    expect(snackBar.right, greaterThan(pane.left));
    expect(
      find.descendant(
        of: find.byType(TaskDetailPane),
        matching: find.byType(SnackBar),
      ),
      findsNothing,
    );

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expectPane(tester, taskId: 1);
  });
}
