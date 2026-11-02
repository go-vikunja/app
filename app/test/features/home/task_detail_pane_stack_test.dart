import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_table_body.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/project_breadcrumb.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../a11y/sweep_data.dart';
import '../../a11y/sweep_harness.dart' show routerOf;
import '../../helpers/auth_fakes.dart';
import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_detail_panes.dart';
import '../teams/organise_harness.dart' show alice;

String _location(WidgetTester tester) =>
    routerOf(tester).routerDelegate.state.matchedLocation;

int _rootPages(WidgetTester tester) =>
    routerOf(tester)
        .routerDelegate
        .navigatorKey
        .currentState!
        .widget
        .pages
        .length;

Task _task(int id) => sweepData().tasks.all.firstWhere((task) => task.id == id);

Future<void> _go(WidgetTester tester, String location) async {
  goTo(tester, location);
  await tester.pumpAndSettle();
}

final Finder _paneUnderPage = find.byType(TaskDetailPane, skipOffstage: false);

ScrollPosition _paneList(WidgetTester tester) => tester
    .state<ScrollableState>(inPane(find.byType(Scrollable)).first)
    .position;

Future<void> _scrollPaneTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: inPane(find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _deleteFromPane(WidgetTester tester) async {
  await tester.tap(paneMoreMenu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(en.taskDelete));
  await tester.pumpAndSettle();
  await tester.tap(find.text(en.taskDeleteDialogConfirm));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void _seedComments(SyncFakes data) => data.details
  ..me = alice
  ..detailsByTask[1] = const TaskDetails(
    commentCount: 2,
    maxPermission: Permission.write,
  )
  ..commentsByTask[1] = [
    sampleComment(id: 1),
    sampleComment(id: 2, author: alice, html: '<p>Asked for Friday.</p>'),
  ];

void main() {
  group('the stack', () {
    testWidgets('back returns to the task before at the offset it had; '
        'close closes', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);
      final related = inPane(find.byType(RelationRow));
      await _scrollPaneTo(tester, related);
      final offset = _paneList(tester).pixels;
      expect(offset, greaterThan(0));

      await tester.tap(related.first);
      await tester.pumpAndSettle();
      expect(paneTaskId(tester), 3);
      final back = inPane(
        find.byTooltip(en.taskDetailPaneBack('Plan the team day')),
      );
      expect(back, findsOneWidget);
      expect(inPane(find.byType(BackButtonIcon)), findsOneWidget);
      // Named by its tooltip alone, not "Back" first.
      final backNode = semanticsInOrder(paneRegion(tester))
          .map((node) => node.getSemanticsData())
          .singleWhere(
            (data) =>
                data.hasAction(SemanticsAction.tap) &&
                data.tooltip == en.taskDetailPaneBack('Plan the team day'),
          );
      expect(backNode.label, isEmpty);
      expect(_paneList(tester).pixels, 0);

      await tester.tap(back);
      await tester.pump();
      expect(_paneList(tester).pixels, offset);
      // Back towards the end of the task's local content, until its details
      // load and make room again.
      final known = _paneList(tester).maxScrollExtent;
      await tester.pumpAndSettle();
      expect(paneTaskId(tester), 4);
      expect(inPane(find.byType(BackButtonIcon)), findsNothing);
      expect(
        _paneList(tester).pixels,
        inInclusiveRange(math.min(offset, known) - 1, offset),
      );
      expect(related.hitTestable(), findsWidgets);

      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(_location(tester), AppRoutes.project(workProjectId));
      semantics.dispose();
    });

    testWidgets('an 11th push drops the oldest task', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 4);
      const pushed = [1, 2, 3, 5, 6, 7, 1, 2, 3, 5];
      for (final id in pushed) {
        tester.widget<TaskDetailSheet>(paneDetail).pane!.openOther(_task(id));
        await tester.pumpAndSettle();
        expect(paneTaskId(tester), id);
      }

      for (final id in pushed.reversed.skip(1)) {
        await tester.tap(inPane(find.byType(BackButtonIcon)));
        await tester.pumpAndSettle();
        expect(paneTaskId(tester), id);
      }
      expect(
        inPane(find.byType(BackButtonIcon)),
        findsNothing,
        reason: 'task 4 was dropped',
      );
      await _back(tester);
      expect(find.byType(TaskDetailPane), findsNothing);
    });

    testWidgets('deleting the second task shows the first again, and says '
        'so on the screen beside the pane', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);
      await openRelatedInPane(tester);
      final pages = _rootPages(tester);

      await _deleteFromPane(tester);
      expectPane(tester, taskId: 4);
      expect(find.text(en.taskDeleted), findsOneWidget);
      expect(inPane(find.text(en.taskDeleted)), findsNothing);
      expect(_rootPages(tester), pages);
      expect(_location(tester), AppRoutes.project(workProjectId));
    });

    testWidgets('a deleted task leaves the stack wherever it is in it', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);
      final host = tester.widget<TaskDetailSheet>(paneDetail).pane!;
      host.openOther(_task(3));
      await tester.pumpAndSettle();
      tester.widget<TaskDetailSheet>(paneDetail).pane!.openOther(_task(4));
      await tester.pumpAndSettle();
      expect(paneTaskId(tester), 4);

      await _deleteFromPane(tester);
      expectPane(tester, taskId: 3);
      expect(inPane(find.byType(BackButtonIcon)), findsNothing);
      await _back(tester);
      expect(find.byType(TaskDetailPane), findsNothing);
    });

    testWidgets("a task deleted in one tab's pane leaves the other tabs' "
        'panes', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      await openTab(tester, en.tabUpcoming);
      await tapTaskRow(tester, 2);
      tester.widget<TaskDetailSheet>(paneDetail).pane!.openOther(_task(1));
      await tester.pumpAndSettle();
      await openTab(tester, en.tabProjects);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 1);
      expectPane(tester, taskId: 1);

      await _deleteFromPane(tester);
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(find.text(en.taskDeleted), findsOneWidget);
      await openTab(tester, en.tabOverview);
      expect(find.byType(TaskDetailPane), findsNothing);
      await openTab(tester, en.tabUpcoming);
      expectPane(tester, taskId: 2);
      expect(inPane(find.byType(BackButtonIcon)), findsNothing);
    });

    testWidgets('close, delete and edit leave the pages and the shell where '
        'they were', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      final pages = _rootPages(tester);

      await tapTaskRow(tester, 1);
      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(_rootPages(tester), pages);
      expect(_location(tester), AppRoutes.overview);

      await tapTaskRow(tester, 1);
      await tester.tap(inPane(find.byTooltip(en.taskEdit)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(_rootPages(tester), pages + 1);
      expect(_paneUnderPage, findsOneWidget);
      await _back(tester);
      expect(_rootPages(tester), pages);
      expectPane(tester, taskId: 1);

      await _deleteFromPane(tester);
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(_rootPages(tester), pages);
      expect(_location(tester), AppRoutes.overview);
    });

    testWidgets('with a status bar the header lies below it, and stays in '
        'reach at the end of the list', (tester) async {
      useWindow(tester, androidTabletLandscape);
      tester.view.padding = FakeViewPadding(
        top: 24 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);
      await openRelatedInPane(tester);

      for (final control in [
        inPane(find.byType(BackButtonIcon)),
        inPane(find.byTooltip(en.taskEdit)),
        inPane(find.byTooltip(en.taskDetailClose)),
      ]) {
        expect(
          tester.getRect(control).top,
          greaterThanOrEqualTo(24),
          reason: '$control',
        );
      }

      final list = _paneList(tester);
      list.jumpTo(list.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(inPane(find.byType(BackButtonIcon)).hitTestable(), findsOneWidget);
      expect(
        inPane(find.byTooltip(en.taskDetailClose)).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(inPane(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailPane), findsNothing);
    });
  });

  group('pages over the shell keep the pane', () {
    testWidgets('the description editor', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester, overrides: [FakeEditorBridges().override]);
      await tapTaskRow(tester, 1);
      final edit = inPane(find.byTooltip(en.taskDetailEditDescription));
      await _scrollPaneTo(tester, edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(_paneUnderPage, findsOneWidget);

      await _back(tester);
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expectPane(tester, taskId: 1);
    });

    testWidgets('the comment editor', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final data = sweepData();
      _seedComments(data);
      await pumpSweepApp(
        tester,
        data: data,
        overrides: [FakeEditorBridges().override],
      );
      await tapTaskRow(tester, 1);
      final show = inPane(find.text(en.taskDetailShowComments));
      await _scrollPaneTo(tester, show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      final menu = inPane(find.byTooltip(en.commentOptions('Alice Example')));
      await _scrollPaneTo(tester, menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.commentEdit));
      await tester.pumpAndSettle();
      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(_paneUnderPage, findsOneWidget);

      await _back(tester);
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expectPane(tester, taskId: 1);
    });

    testWidgets("a label's tasks", (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      final label = inPane(find.text('Calls'));
      await _scrollPaneTo(tester, label);
      await tester.tap(label.first);
      await tester.pumpAndSettle();
      expect(find.byType(LabelTasksScreen), findsOneWidget);
      expect(_paneUnderPage, findsOneWidget);

      await _back(tester);
      expect(find.byType(LabelTasksScreen), findsNothing);
      expectPane(tester, taskId: 1);
    });
  });

  group('where the pane closes', () {
    testWidgets("an account switch closes every tab's pane in its frame", (
      tester,
    ) async {
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
      await tapTaskRow(tester, 1);
      await openTab(tester, en.tabProjects);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);
      expectPane(tester, taskId: 4);

      final container = containerOf(tester);
      await container.read(accountRegistryProvider).setActive(bob.id);
      for (
        var frames = 0;
        frames < 20 &&
            container.read(accountsProvider).value?.activeAccountId != bob.id;
        frames++
      ) {
        await tester.pump(Duration.zero);
      }
      expect(container.read(accountsProvider).value?.activeAccountId, bob.id);
      await tester.pump();
      expect(find.byType(TaskDetailPane, skipOffstage: false), findsNothing);
      for (final title in ['Call the plumber', 'Plan the team day']) {
        expect(find.text(title, skipOffstage: false), findsNothing);
      }

      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailPane), findsNothing);
      await openTab(tester, en.tabProjects);
      expect(find.byType(TaskDetailPane), findsNothing);
      await openTab(tester, en.tabOverview);
      expect(find.byType(TaskDetailPane), findsNothing);
    });

    testWidgets('each tab keeps its own pane; selecting the tab again closes '
        'it', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      await openTab(tester, en.tabProjects);
      expect(find.byType(TaskDetailPane), findsNothing);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);
      await openTab(tester, en.tabUpcoming);
      expect(find.byType(TaskDetailPane), findsNothing);

      await openTab(tester, en.tabOverview);
      expectPane(tester, taskId: 1);
      await openTab(tester, en.tabProjects);
      expectPane(tester, taskId: 4);
      expect(_location(tester), AppRoutes.project(workProjectId));
      await openTab(tester, en.tabAccount);
      expect(find.byType(TaskDetailPane), findsNothing);
      await openTab(tester, en.tabProjects);
      expectPane(tester, taskId: 4);

      await openTab(tester, en.tabProjects);
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(_location(tester), AppRoutes.projects);
      await openTab(tester, en.tabOverview);
      expectPane(tester, taskId: 1);
    });

    testWidgets('another view of the project keeps it; the project tree '
        'closes it', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);

      await tapOutsidePane(
        tester,
        find.descendant(
          of: find.byType(ProjectViewTabs),
          matching: find.text('Table'),
        ),
      );
      expect(find.byType(ProjectTableBody), findsOneWidget);
      expectPane(tester, taskId: 4);

      await _go(tester, AppRoutes.projects);
      expect(find.byType(TaskDetailPane), findsNothing);
    });

    testWidgets('another smart list closes it', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(Project.favoritesId));
      await tapTaskRow(tester, 1);
      expectPane(tester, taskId: 1);

      await _go(tester, AppRoutes.project(urgentFilterId));
      expect(find.byType(TaskDetailPane), findsNothing);
    });

    testWidgets("the breadcrumb to the pane's own project keeps it", (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);

      await tester.tap(_breadcrumb('Work'));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.project(workProjectId));
      expectPane(tester, taskId: 4);
    });

    testWidgets("the breadcrumb from the Overview's pane opens the project "
        "in its tab and leaves the Overview's pane", (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);

      await tester.tap(_breadcrumb('Work'));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.project(workProjectId));
      expect(find.byType(TaskDetailPane), findsNothing);

      await openTab(tester, en.tabOverview);
      expectPane(tester, taskId: 1);
    });

    testWidgets('the breadcrumb to another project closes the pane', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _go(tester, AppRoutes.project(gardenProjectId));
      await tapTaskRow(tester, 5);

      await tester.tap(_breadcrumb('Work'));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.project(workProjectId));
      expect(find.byType(TaskDetailPane), findsNothing);
    });
  });
}

Finder _breadcrumb(String title) => inPane(
  find.descendant(
    of: find.byType(ProjectBreadcrumb),
    matching: find.text(title),
  ),
);
