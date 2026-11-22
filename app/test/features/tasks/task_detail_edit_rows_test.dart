import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(
        id: 2,
        title: 'Shared',
      ).copyWith(maxPermission: Permission.read),
    ];
    Task planned(int id, String title, int projectId) => sampleTask(
      id: id,
      title: title,
      projectId: projectId,
      start: DateTime(2026, 10, 11, 8),
      end: DateTime(2026, 10, 14, 17),
      percentDone: 0.4,
      repeatAfter: const Duration(days: 7),
      assignees: const [User(id: 2, username: 'sam', name: 'Sam')],
    );
    data.tasks.all = [planned(1, 'Plan', 1), planned(2, 'Read only', 2)];
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  Finder inSheet(Finder matching) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: matching);

  Future<void> openDetail(WidgetTester tester, int id) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1800));
    await pumpSignedInApp(tester, sync: data, now: now);
    final context = routerOf(tester)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: data.tasks.find(id)!));
    await tester.pumpAndSettle();
  }

  final rows = [
    (
      en.taskDetailStartDate,
      en.taskDetailChangeStartDate,
      TaskEditField.startDate,
    ),
    (en.taskDetailEndDate, en.taskDetailChangeEndDate, TaskEditField.endDate),
    (
      en.taskDetailProgress,
      en.taskDetailChangeProgress,
      TaskEditField.progress,
    ),
    (en.taskDetailRepeat, en.taskDetailChangeRepeat, TaskEditField.repeat),
    (
      en.taskDetailAssignees,
      en.taskDetailChangeAssignees,
      TaskEditField.assignees,
    ),
  ];

  testWidgets('the start and end date, progress, repeat and assignee rows '
      'are buttons that say what they change', (tester) async {
    final semantics = tester.ensureSemantics();
    await openDetail(tester, 1);

    for (final (name, hint, _) in rows) {
      expect(
        tester.getSemantics(inSheet(find.text(name))),
        isSemantics(isButton: true, hasTapAction: true, onTapHint: hint),
        reason: name,
      );
    }
    semantics.dispose();
  });

  for (final (name, _, field) in rows) {
    testWidgets('a tap on the $name row opens the edit page at it, and Back '
        'returns to the sheet', (tester) async {
      await openDetail(tester, 1);

      await tester.ensureVisible(inSheet(find.text(name)));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text(name)));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(
        routerOf(tester).state.uri.toString(),
        AppRoutes.taskEdit(1, field: field),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditPage), findsNothing);
      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });
  }

  testWidgets('in a project the user may only read, the rows stay text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openDetail(tester, 2);

    for (final (name, _, _) in rows) {
      expect(
        tester.getSemantics(inSheet(find.text(name))),
        isSemantics(isButton: false, hasTapAction: false),
        reason: name,
      );
    }
    await tester.tap(inSheet(find.text(en.taskDetailProgress)));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditPage), findsNothing);
    semantics.dispose();
  });
}
