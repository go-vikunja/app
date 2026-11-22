import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Pay the rent',
        due: DateTime(2026, 10, 8, 9),
      ).copyWith(priority: TaskPriority.urgent),
    ];
  });

  Finder inSheet(Finder matching) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: matching);

  testWidgets("the sheet draws urgent as the task's row does, and keeps the "
      'error red for the overdue due date', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1800));
    await pumpSignedInApp(tester, sync: data, now: now);
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: data.tasks.find(1)!));
    await tester.pumpAndSettle();

    final name = inSheet(find.text(en.priorityUrgent));
    final colors = Theme.of(tester.element(name)).colorScheme;
    final flag = tester.widget<Icon>(inSheet(find.byIcon(Icons.flag)));
    expect(
      tester.widget<Text>(name).style?.color,
      urgentPriorityColor(tester.element(name), text: true),
    );
    expect(flag.color, urgentPriorityColor(tester.element(name)));
    expect(flag.color, isNot(colors.error));
    expect(
      [
        for (final text in tester.widgetList<Text>(inSheet(find.byType(Text))))
          if (text.style?.color == colors.error) text.data,
      ],
      isNotEmpty,
      reason: 'the overdue due date',
    );
  });
}
