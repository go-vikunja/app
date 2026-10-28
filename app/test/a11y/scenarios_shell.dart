import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/overview/application/overview_tasks_provider.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_table_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_chart.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/upcoming/application/upcoming_providers.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

import '../helpers/sample_data.dart';
import '../helpers/sync_fakes.dart';
import 'sweep_data.dart';
import 'sweep_harness.dart';

const _tabs = <(String, Type)>[
  (AppRoutes.overview, OverviewScreen),
  (AppRoutes.upcoming, UpcomingScreen),
  (AppRoutes.projects, ProjectsScreen),
  (AppRoutes.account, AccountTab),
];

SweepScenario _projectView(
  String variant, {
  required int viewId,
  required Type body,
}) => SweepScenario.route(
  '${AppRoutes.projects}/:id',
  variant: variant,
  setUp: (tester, _) async {
    final data = sweepData();
    data.listPreferences.lastViews[workProjectId] = viewId;
    await pumpSweepApp(tester, data: data);
  },
  navigate: (tester, _) async => goTo(tester, AppRoutes.project(workProjectId)),
  expectScreen: (_) => find.byType(body),
);

SweepScenario _smartList(String variant, int pseudoProjectId) =>
    SweepScenario.route(
      '${AppRoutes.projects}/:id',
      variant: variant,
      setUp: (tester, _) => pumpSweepApp(tester),
      navigate: (tester, _) async =>
          goTo(tester, AppRoutes.project(pseudoProjectId)),
      expectScreen: (_) => find.byWidgetPredicate(
        (widget) =>
            widget is SmartListScreen &&
            widget.pseudoProjectId == pseudoProjectId,
      ),
    );

/// The four tabs and a project's list in every view.
final List<SweepScenario> shellRouteScenarios = [
  for (final (route, screen) in _tabs)
    SweepScenario.route(
      route,
      setUp: (tester, _) => pumpSweepApp(tester),
      navigate: (tester, _) async => goTo(tester, route),
      expectScreen: (_) => find.byType(screen),
    ),
  _projectView('list', viewId: listViewId, body: ProjectListBody),
  _projectView('kanban', viewId: kanbanViewId, body: ProjectBoard),
  _projectView('table', viewId: tableViewId, body: ProjectTableBody),
  _projectView('gantt', viewId: ganttViewId, body: TimelineChart),
  _smartList('favourites', Project.favoritesId),
  _smartList('saved filter', urgentFilterId),
];

/// The tab screens and a project list when empty, failing, offline and on
/// the frame before their data arrives.
final List<SweepScenario> shellStateScenarios = [
  for (final (route, screen) in [
    ..._tabs,
    ('${AppRoutes.projects}/:id', ProjectTasksScreen),
  ]) ...[
    _state(route, screen, 'empty', data: _emptyData),
    _state(
      route,
      screen,
      'offline',
      data: _offlineData,
      expect: (l10n) => find.bySemanticsLabel(l10n.offlineNotice),
    ),
    _failing(route, screen),
    _loading(route, screen),
  ],
];

/// The last sync, and every retry, could not reach the server.
SyncFakes _offlineData() {
  const unreachable = NetworkFailure(NetworkProblem.unreachable);
  return sweepData(
    status: SyncFailed(
      failure: unreachable,
      lastSyncedAt: sweepNow.subtract(const Duration(days: 3)),
    ),
  )..engine.onRefresh = () async => throw unreachable;
}

SyncFakes _emptyData() => SyncFakes(now: sweepNow)
  ..projects.all = [
    sampleProject(
      id: workProjectId,
      title: 'Work',
      views: defaultViews(workProjectId, firstViewId: listViewId),
    ),
  ];

String _location(String route) =>
    route.contains(':id') ? AppRoutes.project(workProjectId) : route;

SweepScenario _state(
  String route,
  Type screen,
  String state, {
  required SyncFakes Function() data,
  ScreenFinder? expect,
}) => SweepScenario(
  kind: SweepKind.state,
  name: '$route $state',
  route: route,
  setUp: (tester, _) => pumpSweepApp(tester, data: data()),
  navigate: (tester, _) async => goTo(tester, _location(route)),
  expectScreen: expect ?? (_) => find.byType(screen),
);

/// A refresh the server refused: the failure card above the saved data,
/// or in place of a project's list that never loaded; the Account tab
/// shows the failed sync instead.
SweepScenario _failing(String route, Type screen) => SweepScenario(
  kind: SweepKind.state,
  name: '$route failure',
  route: route,
  setUp: (tester, _) async {
    final data = sweepData(
      status: route == AppRoutes.account
          ? SyncFailed(
              failure: const ServerFailure(502),
              lastSyncedAt: sweepNow.subtract(const Duration(days: 3)),
            )
          : null,
    );
    data.engine.onRefresh = () async => throw const ServerFailure(502);
    data.tasks.projectListErrors[listViewId] = const ServerFailure(502);
    await pumpSweepApp(tester, data: data);
  },
  navigate: (tester, l10n) async {
    goTo(tester, _location(route));
    await tester.pumpAndSettle();
    if (route == AppRoutes.account) {
      // Below the profile and the server's message, out of the lazy list.
      await tester.scrollUntilVisible(
        find.text(l10n.accountSyncFailed),
        200,
        scrollable: find
            .descendant(
              of: find.byType(screen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      return;
    }
    if (route.contains(':id')) return;
    unawaited(
      tester
          .state<RefreshIndicatorState>(
            find
                .descendant(
                  of: find.byType(screen),
                  matching: find.byType(RefreshIndicator),
                )
                .first,
          )
          .show(),
    );
  },
  expectScreen: (l10n) => route == AppRoutes.account
      ? find.text(l10n.accountSyncFailed)
      : find.byType(DataFailureCard),
);

/// The first frame before the data arrives; for the Account tab, a sync
/// in progress.
SweepScenario _loading(String route, Type screen) => SweepScenario(
  kind: SweepKind.state,
  name: '$route loading',
  route: route,
  settle: false,
  setUp: (tester, _) async {
    final data = sweepData(
      status: route == AppRoutes.account
          ? const SyncRunning(
              phase: SyncPhase.tasks,
              done: 12,
              total: 40,
              initial: false,
            )
          : null,
    );
    data.tasks.holdsProjectList = (_) => true;
    await pumpSweepApp(
      tester,
      data: data,
      overrides: [
        if (route == AppRoutes.overview)
          overviewTasksProvider.overrideWith((ref) => const Stream.empty()),
        if (route == AppRoutes.upcoming)
          activeOpenTasksProvider.overrideWith((ref) => const Stream.empty()),
        if (route == AppRoutes.projects)
          projectsProvider.overrideWith((ref) => const Stream.empty()),
      ],
      settle: false,
    );
  },
  navigate: (tester, _) async => goTo(tester, _location(route)),
  expectScreen: (_) => route == AppRoutes.account
      ? find.byType(screen)
      : find.descendant(
          of: find.byType(screen),
          matching: find.byType(LoadingPlaceholder),
        ),
);
