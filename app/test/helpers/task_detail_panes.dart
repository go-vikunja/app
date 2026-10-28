import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import 'large_screens.dart';
import 'pump_app.dart' show en;

const iOSOnly = TargetPlatformVariant({TargetPlatform.iOS});

/// The 13" iPad in landscape: wide enough for the pane, like its portrait.
const iPad13Landscape = Size(1366, 1024);

/// The iPad mini in portrait, below the pane's 840.
const iPadMiniPortrait = Size(744, 1133);

/// A foldable unfolded: the pane at its 360 minimum beside the test rail.
const androidFoldable = Size(841, 701);

Finder inPane(Finder matching) =>
    find.descendant(of: find.byType(TaskDetailPane), matching: matching);

final Finder paneDetail = inPane(find.byType(TaskDetailSheet));

/// The task the current tab's pane shows, as the tabs see it.
int? paneTaskId(WidgetTester tester) => tester
    .widget<TaskDetailPaneScope>(find.byType(TaskDetailPaneScope))
    .selectedTaskId;

/// The pane's menu of more actions, named after the task it shows.
final Finder paneMoreMenu = inPane(
  find.byWidgetPredicate(
    (widget) =>
        widget is PopupMenuButton &&
        (widget.tooltip ?? '').startsWith(en.taskDetailPaneMore('')),
  ),
);

/// The sheet of the platform: Material's bottom sheet, or the iOS sheet.
Finder platformSheet() => defaultTargetPlatform == TargetPlatform.iOS
    ? find.byType(ReadableSheetWidth)
    : find.byType(BottomSheet);

void expectPane(WidgetTester tester, {required int taskId}) {
  expect(find.byType(TaskDetailPane), findsOneWidget);
  expect(paneDetail, findsOneWidget);
  expect(tester.widget<TaskDetailSheet>(paneDetail).task.id, taskId);
  expect(find.byType(BottomSheet), findsNothing);
  expect(find.byType(ReadableSheetWidth), findsNothing);
}

void expectSheet(WidgetTester tester, {int? taskId}) {
  expect(find.byType(TaskDetailPane), findsNothing);
  final sheet = find.byType(TaskDetailSheet);
  expect(sheet, findsOneWidget);
  expect(platformSheet(), findsOneWidget);
  if (taskId != null) {
    expect(tester.widget<TaskDetailSheet>(sheet).task.id, taskId);
  }
}

Finder taskRowOf(int taskId) => find.byWidgetPredicate(
  (widget) => widget is TaskRow && widget.task.id == taskId,
);

Finder boardCardOf(int taskId) => find.byWidgetPredicate(
  (widget) => widget is BoardCard && widget.task.id == taskId,
);

Finder timelineRowOf(int taskId) => find.byWidgetPredicate(
  (widget) => widget is TimelineRow && widget.row.task.id == taskId,
);

/// Taps the first of [target] that is not inside the pane, scrolled into
/// view first.
Future<void> tapOutsidePane(WidgetTester tester, Finder target) async {
  final outside = find
      .byElementPredicate(
        (element) =>
            target.evaluate().contains(element) &&
            element.findAncestorWidgetOfExactType<TaskDetailPane>() == null,
      )
      .first;
  await tester.ensureVisible(outside);
  await tester.pumpAndSettle();
  await tester.tap(outside);
  await tester.pumpAndSettle();
}

Future<void> tapTaskRow(WidgetTester tester, int taskId) =>
    tapOutsidePane(tester, taskRowOf(taskId));

/// The related task of the pane's task, scrolled to in the pane's list.
Future<void> openRelatedInPane(WidgetTester tester) async {
  final related = inPane(find.byType(RelationRow));
  await tester.scrollUntilVisible(
    related,
    200,
    scrollable: inPane(find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(related.first);
  await tester.pumpAndSettle();
}

/// The pane's left edge less the divider: where the list beside it ends.
double listRightBesidePane(WidgetTester tester) =>
    tester.getRect(find.byType(TaskDetailPane)).left - 1;

/// The pane's width at [window] beside the rail the test pumps.
double expectedPaneWidth(WidgetTester tester, Size window) =>
    ((window.width - railRight(tester)) * 0.4).clamp(360, 480).toDouble();

/// The pane's own region for screen readers.
SemanticsNode paneRegion(WidgetTester tester) => tester.getSemantics(
  inPane(
    find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.container && widget.explicitChildNodes,
    ),
  ).first,
);

/// [root] and the nodes below it that a screen reader reaches on their
/// own, in its order.
List<SemanticsNode> semanticsInOrder(SemanticsNode root) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (node.isMergedIntoParent) return;
    nodes.add(node);
    node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .forEach(visit);
  }

  visit(root);
  return nodes;
}

/// The selected state of every semantics node whose label names one of
/// [titles]: rows, cards and timeline rows of those tasks.
List<({String label, Tristate selected})> selectedStatesOf(
  WidgetTester tester,
  Iterable<String> titles,
) {
  final found = <({String label, Tristate selected})>[];
  bool visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (titles.any(data.label.contains)) {
      found.add((label: data.label, selected: data.flagsCollection.isSelected));
    }
    node.visitChildren(visit);
    return true;
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return found;
}
