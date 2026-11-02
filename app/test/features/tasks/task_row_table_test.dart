import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/avatar_stack.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const kim = User(id: 5, username: 'kim', name: 'Kim');
  const anna = User(id: 1, username: 'anna', name: 'Anna');

  Task fullTask({
    bool done = false,
    TaskPriority priority = TaskPriority.unset,
    double percentDone = 0.29,
  }) => sampleTask(
    id: 7,
    title: 'Pay the bill',
    identifier: 'WORK-7',
    due: now.subtract(const Duration(days: 1)),
    start: now.subtract(const Duration(days: 3)),
    end: now.add(const Duration(days: 2)),
    done: done,
    doneAt: done ? now.subtract(const Duration(hours: 2)) : null,
    created: now.subtract(const Duration(days: 5)),
    updated: now.subtract(const Duration(days: 4)),
    createdBy: kim,
    priority: priority,
    percentDone: percentDone,
    labels: [sampleLabel(id: 1, title: 'Bills')],
    assignees: const [anna],
    commentCount: 3,
    isUnread: true,
    description:
        '<ul data-type="taskList"><li data-checked="false">x</li></ul>',
    repeatAfter: const Duration(days: 7),
  );

  Future<void> pumpRow(
    WidgetTester tester,
    Task task, {
    required Set<TableColumn> columns,
    String? projectTitle,
    String? projectHexColor,
    bool pending = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeAccountIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                TaskRow(
                  task: task,
                  now: now,
                  minimumPriority: 2,
                  columns: columns,
                  projectTitle: projectTitle,
                  projectHexColor: projectHexColor,
                  pending: pending,
                  onTap: () {},
                  onDoneChanged: (_) {},
                  onFavoriteChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? colorOf(WidgetTester tester, Finder text) =>
      tester.widget<Text>(text).style?.color;

  testWidgets("the web's default columns without its number: done, title, "
      'labels, assignees and the due date, in a neutral tone', (tester) async {
    await pumpRow(
      tester,
      fullTask(done: true),
      columns: TableColumn.defaults,
      projectTitle: 'Work',
    );

    expect(find.textContaining('WORK-7'), findsNothing);
    expect(find.byType(DoneBadge), findsOneWidget);
    expect(find.text('Pay the bill'), findsOneWidget);
    expect(find.widgetWithText(LabelPill, 'Bills'), findsOneWidget);
    expect(find.byType(AvatarStack), findsOneWidget);
    expect(find.widgetWithText(TableDateItem, '1 day ago'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);

    expect(find.text('Work'), findsNothing);
    expect(find.byType(TablePriorityLabel), findsNothing);
    expect(find.byType(PriorityFlag), findsNothing);
    expect(find.byType(CommentCount), findsNothing);
    expect(find.byType(PercentDoneItem), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.notes), findsNothing);
    expect(find.byIcon(Icons.repeat), findsNothing);
    expect(find.byType(CreatedByItem), findsNothing);
    // The checkbox and the star stay as in every row.
    expect(find.byTooltip(en.taskMarkNotDone), findsOneWidget);
    expect(find.byTooltip(en.taskAddFavourite), findsOneWidget);
  });

  testWidgets('an open overdue task in the default columns: no done badge '
      'and its due date not in the error colour', (tester) async {
    await pumpRow(tester, fullTask(), columns: TableColumn.defaults);

    expect(find.byType(DoneBadge), findsNothing);
    final due = find.text('1 day ago');
    final context = tester.element(due);
    expect(
      colorOf(tester, due),
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('every column shows its value, each date after its own icon', (
    tester,
  ) async {
    await pumpRow(
      tester,
      fullTask(done: true),
      columns: TableColumn.values.toSet(),
      projectTitle: 'Work',
      projectHexColor: '1973ff',
      pending: true,
    );

    expect(find.textContaining('WORK-7'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byType(ProjectIcon),
              matching: find.byType(Icon),
            ),
          )
          .color,
      const Color(0xFF1973FF),
    );
    expect(find.text(en.priorityUnset), findsOneWidget);
    expect(find.byType(CommentCount), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
    String? dateAfter(IconData icon) => tester
        .widget<TableDateItem>(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(TableDateItem),
          ),
        )
        .text;
    expect(dateAfter(Icons.calendar_today_outlined), '1 day ago');
    expect(dateAfter(Icons.play_arrow_outlined), '3 days ago');
    expect(dateAfter(Icons.stop_outlined), 'in 2 days');
    expect(dateAfter(Icons.task_alt), '2 hours ago');
    expect(dateAfter(Icons.add_circle_outline), '5 days ago');
    expect(dateAfter(Icons.update), '4 days ago');
    // 0.29 is 28.999999999999996 % on the web.
    expect(find.text(en.projectTableCellPercent(29)), findsOneWidget);
    expect(find.text('Kim'), findsOneWidget);
    expect(find.byType(UserAvatar), findsNWidgets(2));
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('unset dates are left out, not shown as a dash', (tester) async {
    await pumpRow(
      tester,
      sampleTask(id: 3, title: 'Bare'),
      columns: TableColumn.values.toSet(),
    );

    expect(find.byType(TableDateItem), findsNothing);
    expect(find.text('-'), findsNothing);
    expect(find.text('–'), findsNothing);
    expect(find.byType(CreatedByItem), findsNothing);
    expect(find.byType(CommentCount), findsNothing);
    expect(find.byType(AvatarStack), findsNothing);
    // Priority and progress are values, 0 too.
    expect(find.text(en.priorityUnset), findsOneWidget);
    expect(find.text(en.projectTableCellPercent(0)), findsOneWidget);
  });

  testWidgets('the priority column follows the web table: every priority, '
      "a done task's too, in the web's three colours", (tester) async {
    const priority = {TableColumn.title, TableColumn.priority};
    Future<(Color?, IconData?)> look(TaskPriority value, String text) async {
      await pumpRow(
        tester,
        fullTask(priority: value, done: true),
        columns: priority,
      );
      final label = find.text(text);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(TablePriorityLabel),
          matching: find.byType(Icon),
        ),
      );
      return (colorOf(tester, label), icon.icon);
    }

    final colors = AppTheme.light().colorScheme;
    expect(await look(TaskPriority.unset, en.priorityUnset), (
      colors.primary,
      Icons.priority_high,
    ));
    expect(await look(TaskPriority.low, en.priorityLow), (
      colors.primary,
      Icons.priority_high,
    ));
    expect(await look(TaskPriority.medium, en.priorityMedium), (
      colors.tertiary,
      Icons.priority_high,
    ));
    for (final (value, text) in [
      (TaskPriority.high, en.priorityHigh),
      (TaskPriority.urgent, en.priorityUrgent),
      (TaskPriority.doNow, en.priorityDoNow),
    ]) {
      expect(await look(value, text), (colors.error, Icons.error_outline));
    }
  });

  testWidgets('progress is a whole percent, rounded', (tester) async {
    const progress = {TableColumn.title, TableColumn.percentDone};
    for (final (value, shown) in [
      (0.004, 0),
      (0.005, 1),
      (0.666, 67),
      (1.0, 100),
    ]) {
      await pumpRow(tester, fullTask(percentDone: value), columns: progress);
      expect(find.text(en.projectTableCellPercent(shown)), findsOneWidget);
    }
  });

  testWidgets('an open task has no done-at, as the server clears it', (
    tester,
  ) async {
    await pumpRow(
      tester,
      sampleTask(id: 3, title: 'Reopened', doneAt: now),
      columns: const {TableColumn.title, TableColumn.doneAt},
    );

    expect(find.byType(TableDateItem), findsNothing);
  });

  testWidgets('the row is one semantics node naming every shown field', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(
      tester,
      fullTask(done: true, priority: TaskPriority.high),
      columns: TableColumn.values.toSet(),
      projectTitle: 'Work',
    );

    final node = tester.getSemantics(find.text('Pay the bill'));
    expect(node.label.split('\n'), [
      'Pay the bill',
      en.taskDoneSemantics,
      'Work',
      en.prioritySemantics(en.priorityHigh),
      en.labelSemantics('Bills'),
      en.taskAssigneesSemantics('Anna'),
      en.taskCommentCountUnread(3),
      en.taskDueSemantics('1 day ago'),
      en.projectTableStartsSemantics('3 days ago'),
      en.projectTableEndsSemantics('in 2 days'),
      en.taskPercentDone(29),
      en.taskDetailDoneWhen('2 hours ago'),
      en.taskDetailCreated('5 days ago'),
      en.taskDetailUpdated('4 days ago'),
      en.projectTableCreatedBySemantics('Kim'),
    ]);
    expect(tester.getSemantics(find.text('Kim')), same(node));

    await pumpRow(tester, fullTask(), columns: const {TableColumn.title});
    expect(
      tester.getSemantics(find.text('Pay the bill')).label,
      'Pay the bill',
    );
    semantics.dispose();
  });

  testWidgets('every column fits at 200 % text on a narrow screen in dark '
      'mode', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(320, 640));
    useAccessibilityExtremes(tester);
    await pumpRow(
      tester,
      fullTask(done: true, priority: TaskPriority.doNow),
      columns: TableColumn.values.toSet(),
      projectTitle: 'A project with a rather long title',
      projectHexColor: '1973ff',
    );

    expect(tester.takeException(), isNull);
  });
}
