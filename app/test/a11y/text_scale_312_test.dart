import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/sync_fakes.dart';
import 'sweep_data.dart';
import 'sweep_harness.dart';

/// iOS's largest accessibility text size (AX5), as the engine maps it.
const double ax5 = 53 / 17;

/// The smallest current iPhone, and the 1st-generation SE that the
/// deployment target (iOS 15) still runs on.
const _surfaces = [Size(375, 667), Size(320, 568)];

/// The sweep's data with titles long enough to wrap at any size.
SyncFakes _longData() {
  final data = sweepData();
  data.projects.all = [
    for (final project in data.projects.all)
      copyProject(project, title: '${project.title} with a long title'),
  ];
  data.tasks.all = [
    for (final task in data.tasks.all)
      task.copyWith(
        title: '${task.title} with a title long enough to wrap onto lines',
      ),
  ];
  return data;
}

BuildContext _page(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

/// The six core screens of decision 4, each reached from the Overview.
final _screens = <(String, Future<void> Function(WidgetTester), Finder)>[
  ('Overview', (_) async {}, find.byType(OverviewScreen)),
  (
    'a project list',
    (tester) async => goTo(tester, AppRoutes.project(workProjectId)),
    find.byType(ProjectListBody),
  ),
  (
    'the task detail sheet',
    (tester) async => unawaited(
      showTaskDetail(_page(tester), task: _longData().tasks.all.first),
    ),
    find.byType(TaskDetailSheet),
  ),
  (
    'the edit page',
    (tester) async => pushTo(tester, AppRoutes.taskEdit(1)),
    find.byType(TaskEditPage),
  ),
  (
    'the new-task sheet',
    (tester) async =>
        unawaited(showNewTaskSheet(_page(tester), projectId: workProjectId)),
    find.byType(NewTaskSheet),
  ),
  (
    'the Account tab',
    (tester) async => goTo(tester, AppRoutes.account),
    find.byType(AccountTab),
  ),
];

/// Pages through every vertical list in front to its end; a layout
/// overflow on the way fails.
Future<void> _scrollEveryListToEnd(WidgetTester tester) async {
  final lists = [
    for (final element in find.byType(Scrollable).hitTestable().evaluate())
      (element as StatefulElement).state as ScrollableState,
  ];
  for (final list in lists) {
    if (!list.mounted) continue;
    final position = list.position;
    if (position.axis != Axis.vertical) continue;
    for (var page = 0; page < 80 && position.extentAfter > 0; page++) {
      position.jumpTo(
        math.min(
          position.maxScrollExtent,
          position.pixels + position.viewportDimension * 0.8,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(position.extentAfter, 0);
  }
}

void main() {
  for (final (name, open, screen) in _screens) {
    for (final size in _surfaces) {
      for (final locale in sweepLocales) {
        testWidgets(
          '$name at 3.12× on ${size.width.round()}×${size.height.round()} '
          '(${locale.languageCode})',
          (tester) async {
            usePhoneSurface(tester, logicalSize: size);
            useLocale(tester, locale);
            tester.platformDispatcher.textScaleFactorTestValue = ax5;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            expect(defaultTargetPlatform, TargetPlatform.iOS);

            await pumpSweepApp(tester, data: _longData());
            expect(tester.takeException(), isNull);
            await open(tester);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(screen, findsOneWidget);

            await _scrollEveryListToEnd(tester);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
          timeout: const Timeout(Duration(seconds: 30)),
        );
      }
    }
  }
}
