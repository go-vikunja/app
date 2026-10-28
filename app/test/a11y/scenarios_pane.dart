import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/guest_app.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/task_detail_panes.dart';
import 'sweep_data.dart';
import 'sweep_harness.dart';

final Finder _paneDetail = find.descendant(
  of: find.byType(TaskDetailPane),
  matching: find.byType(TaskDetailSheet),
);

/// [route]'s screen at [location] with the task that [open] taps open in
/// the pane beside it (step 36c), on the tablet in landscape only, where
/// the pane shows, in both brightnesses.
SweepScenario _pane(
  String route,
  String variant, {
  required String location,
  required Future<void> Function(WidgetTester tester) open,
  SweepStep? setUp,
  ScreenFinder? expectScreen,
}) => SweepScenario.route(
  route,
  variant: variant,
  setUp: setUp ?? (tester, _) => pumpSweepApp(tester),
  navigate: (tester, _) async {
    goTo(tester, location);
    await tester.pumpAndSettle();
    await open(tester);
  },
  expectScreen: expectScreen ?? (_) => _paneDetail,
  surfaces: const {SweepSurface.tabletLandscape},
  tabletBrightnesses: const {Brightness.light, Brightness.dark},
);

/// A project's view with the task its row, card or bar opens.
SweepScenario _projectPane(
  String variant, {
  required int viewId,
  required Future<void> Function(WidgetTester tester) open,
  ScreenFinder? expectScreen,
}) => _pane(
  '${AppRoutes.projects}/:id',
  variant,
  location: AppRoutes.project(workProjectId),
  setUp: (tester, _) async {
    final data = sweepData();
    data.listPreferences.lastViews[workProjectId] = viewId;
    await pumpSweepApp(tester, data: data);
  },
  open: open,
  expectScreen: expectScreen,
);

SyncFakes _offlineData() {
  const unreachable = NetworkFailure(NetworkProblem.unreachable);
  return sweepData(
    status: SyncFailed(
      failure: unreachable,
      lastSyncedAt: sweepNow.subtract(const Duration(days: 3)),
    ),
  )..engine.onRefresh = () async => throw unreachable;
}

Future<void> _pumpGuest(WidgetTester tester, AppLocalizations _) async {
  final data = SyncFakes(now: sweepNow);
  data.projects.all = [guestProject(permission: Permission.write)];
  data.tasks.all = [
    for (final task in sweepData().tasks.all.take(4))
      task.copyWith(projectId: guestProjectId),
  ];
  await pumpGuestApp(
    tester,
    auth: AuthFakes(),
    data: data,
    permission: Permission.write,
  );
}

Future<void> _tapRow(WidgetTester tester, int taskId) =>
    tapTaskRow(tester, taskId);

/// The Overview's overdue task in the pane, with its error text beside the
/// selected row.
final SweepScenario _overviewPane = _pane(
  AppRoutes.overview,
  'pane',
  location: AppRoutes.overview,
  open: (tester) => _tapRow(tester, 1),
);

/// Task 4 of the list, then its related task inside the pane, which shows
/// the back arrow.
final SweepScenario _listPaneWithBack = _projectPane(
  'pane list',
  viewId: listViewId,
  open: (tester) async {
    await _tapRow(tester, 4);
    await openRelatedInPane(tester);
  },
  expectScreen: (_) => inPane(find.byType(BackButtonIcon)),
);

/// The task pane beside each kind of list: route scenarios in a `pane`
/// variant, swept on the tablet in landscape in light and dark.
final List<SweepScenario> paneRouteScenarios = [
  _overviewPane,
  _pane(
    AppRoutes.upcoming,
    'pane',
    location: AppRoutes.upcoming,
    open: (tester) => _tapRow(tester, 3),
  ),
  _listPaneWithBack,
  _projectPane(
    'pane table',
    viewId: tableViewId,
    open: (tester) => _tapRow(tester, 4),
  ),
  _projectPane(
    'pane kanban',
    viewId: kanbanViewId,
    open: (tester) => tapOutsidePane(tester, boardCardOf(4)),
  ),
  _projectPane(
    'pane gantt',
    viewId: ganttViewId,
    open: (tester) => tapOutsidePane(
      tester,
      find
          .descendant(
            of: timelineRowOf(3),
            matching: find.byWidgetPredicate(
              (widget) => widget is GestureDetector && widget.onTap != null,
            ),
          )
          .first,
    ),
  ),
  _pane(
    '${AppRoutes.projects}/:id',
    'pane favourites',
    location: AppRoutes.project(Project.favoritesId),
    open: (tester) => _tapRow(tester, 6),
  ),
  _pane(
    AppRoutes.overview,
    'pane guest',
    location: AppRoutes.overview,
    setUp: _pumpGuest,
    open: (tester) => _tapRow(tester, 1),
  ),
  _pane(
    AppRoutes.overview,
    'pane offline',
    location: AppRoutes.overview,
    setUp: (tester, _) => pumpSweepApp(tester, data: _offlineData()),
    open: (tester) => _tapRow(tester, 1),
  ),
];

/// The pane at its narrowest, 360 beside a list of about 350, at 200 %.
final List<SweepScenario> paneFoldableScenarios = [
  _overviewPane,
  _listPaneWithBack,
];
