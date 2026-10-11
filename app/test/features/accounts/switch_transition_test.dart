import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import 'accounts_harness.dart';

// Both accounts have a task and a project with id 1, so a screen of Alice's
// that survived the switch would show Bob's.
void main() {
  late ThreeAccounts accounts;

  setUp(() => accounts = ThreeAccounts());

  Future<void> seedWithData({SyncStatus? bobStatus}) async {
    await accounts.seed(withCarol: false, bobStatus: bobStatus);
    accounts.aliceData.projects.all = [sampleProject(id: 1, title: 'Work')];
    accounts.aliceData.tasks.all = [sampleTask(id: 1, title: 'Alice task')];
    accounts.bobData.projects.all = [
      sampleProject(id: 1, title: 'Bob project'),
    ];
    accounts.bobData.tasks.all = [sampleTask(id: 1, title: 'Bob task')];
  }

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> switchToBob(WidgetTester tester) =>
      containerOf(tester)
          .read(accountSwitcherProvider)
          .switchTo(accounts.bob.id);

  /// Returns after the first frame that follows the switch.
  Future<void> switchToBobAndDrawAFrame(WidgetTester tester) async {
    await switchToBob(tester);
    // Delivers the registry change, which schedules the frame; a pump only
    // draws a frame that was scheduled before it started.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('closes an open edit page before it is built with the next '
      "account's data", (tester) async {
    await seedWithData();
    await accounts.pump(tester);
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.taskEdit(1)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditPage), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Alice task'), findsOneWidget);

    await switchToBobAndDrawAFrame(tester);

    expect(find.byType(TaskEditPage), findsNothing);
    expect(find.text('Bob task'), findsNothing);

    await tester.pumpAndSettle();
    expect(location(tester), AppRoutes.overview);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.text('Bob task'), findsOneWidget);
  });

  testWidgets('closes the detail sheet and a dialog over it at once', (
    tester,
  ) async {
    await seedWithData();
    await accounts.pump(tester);
    await tester.tap(find.text('Alice task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsOneWidget);
    expect(find.text(en.taskDeleteDialogTitle), findsOneWidget);

    await switchToBobAndDrawAFrame(tester);

    expect(find.byType(TaskDetailSheet), findsNothing);
    expect(find.text(en.taskDeleteDialogTitle), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Bob task'), findsOneWidget);
    // The dialog's answer counts as a cancel.
    expect(accounts.aliceData.tasks.writes, isEmpty);
    expect(accounts.bobData.tasks.writes, isEmpty);
  });

  testWidgets('resets a tab that showed a project to its first screen', (
    tester,
  ) async {
    await seedWithData();
    await accounts.pump(tester);
    await openTab(tester, en.tabProjects);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTasksScreen), findsOneWidget);

    await switchToBobAndDrawAFrame(tester);

    expect(find.byType(ProjectTasksScreen, skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(location(tester), AppRoutes.overview);

    await openTab(tester, en.tabProjects);
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(find.byType(ProjectTasksScreen), findsNothing);
    expect(find.text('Bob project'), findsOneWidget);
    expect(location(tester), AppRoutes.projects);
  });

  testWidgets('a switch between two synced accounts never shows the '
      'first-sync screen', (tester) async {
    await seedWithData();
    await accounts.pump(tester);

    await switchToBob(tester);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FirstSyncScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    }

    await tester.pumpAndSettle();
    expect(find.text('Bob task'), findsOneWidget);
  });

  testWidgets('a switch to a synced account whose engine reports late never '
      'shows the first-sync screen', (tester) async {
    await accounts.seed(withCarol: false);
    final bobData = accounts.data.accounts[accounts.bob.id] = AccountDataFakes(
      now: accounts.now,
      restored: false,
    );
    bobData.tasks.all = [sampleTask(id: 1, title: 'Bob task')];
    await accounts.pump(tester);

    unawaited(switchToBob(tester));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FirstSyncScreen), findsNothing);
    }
    bobData.engine.emit(SyncIdle(lastSyncedAt: accounts.now));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FirstSyncScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    }

    await tester.pumpAndSettle();
    expect(containerOf(tester).read(activeAccountIdProvider), accounts.bob.id);
    expect(find.text('Bob task'), findsOneWidget);
  });

  testWidgets("the next account's screens show none of the previous "
      "account's queued changes, sync problems or sync status while its own "
      'are loading', (tester) async {
    // Tall enough for the whole Account tab.
    usePhoneSurface(tester, logicalSize: const Size(400, 2000));
    await seedWithData();
    accounts.aliceData.tasks
      ..pendingChanges = 3
      ..pendingTaskIds = {1}
      ..syncProblems = [
        SyncProblem(
          operationId: 'alice-op',
          kind: OutboxOperationKind.updateTask,
          taskId: 1,
          taskTitle: 'Alice secret task',
          failure: _unreachable,
          failedAt: accounts.now,
        ),
      ];
    // The quiet sync at start fails.
    accounts.aliceData.engine
      ..emit(SyncFailed(failure: _unreachable, lastSyncedAt: accounts.now))
      ..onRefresh = () async => throw _unreachable;
    final bobOutbox = Completer<void>();
    accounts.bobData.tasks
      ..outboxLoaded = bobOutbox.future
      ..pendingChanges = 1;
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);
    expect(find.text('Alice secret task'), findsOneWidget);
    expect(find.text(en.accountPendingChanges(3)), findsOneWidget);
    expect(find.text(en.accountSyncFailed), findsOneWidget);

    await switchToBob(tester);
    await tester.pumpAndSettle();
    expect(find.text('Bob task'), findsOneWidget);
    expect(tester.widget<TaskRow>(find.byType(TaskRow)).pending, isFalse);

    await openTab(tester, en.tabAccount);
    expect(find.text('Alice secret task'), findsNothing);
    expect(find.text(en.accountPendingChanges(3)), findsNothing);
    expect(find.text(en.accountSyncFailed), findsNothing);

    bobOutbox.complete();
    await tester.pumpAndSettle();
    expect(find.text(en.accountPendingChanges(1)), findsOneWidget);
  });

  testWidgets('an account whose first sync has not completed goes to it', (
    tester,
  ) async {
    await seedWithData(bobStatus: const SyncNeverRun());
    accounts.bobData.engine.onEnsureInitialSync = () =>
        Completer<void>().future;
    await accounts.pump(tester);

    await switchToBob(tester);
    await pumpUntil(tester, find.byType(FirstSyncScreen));
    // The shell's route animates out.
    await pumpFrames(tester, 5);

    expect(location(tester), AppRoutes.firstSync);
    expect(find.byType(HomeShell), findsNothing);
    expect(accounts.bobData.engine.ensureInitialSyncCalls, 1);
  });

  testWidgets('a first sync that ends while the first-sync screen would '
      'still be animating in returns to a single shell', (tester) async {
    await seedWithData(bobStatus: const SyncNeverRun());
    accounts.bobData.engine.onEnsureInitialSync = () =>
        Future<void>.delayed(const Duration(milliseconds: 100));
    await accounts.pump(tester);

    await switchToBob(tester);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Bob task'), findsOneWidget);
  });
}

const _unreachable = NetworkFailure(NetworkProblem.unreachable);
