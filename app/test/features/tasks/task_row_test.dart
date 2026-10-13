import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  String taskList(List<bool> checked) => [
    '<ul data-type="taskList">',
    for (final item in checked) '<li data-checked="$item">x</li>',
    '</ul>',
  ].join();
  final checklist = taskList([true, false]);
  final allChecked = taskList([true, true]);
  final beta = sampleLabel(id: 2, title: 'Beta');
  final alpha = sampleLabel(id: 1, title: 'alpha');
  const people = [
    User(id: 1, username: 'anna', name: 'Anna'),
    User(id: 2, username: 'ben'),
    User(id: 3, username: 'cleo', name: 'Cleo'),
    User(id: 4, username: 'dan', name: 'Dan'),
  ];

  Task richTask({bool done = false}) => sampleTask(
    id: 7,
    title: 'Pay the bill',
    identifier: 'WORK-7',
    due: now.subtract(const Duration(days: 1)),
    done: done,
    doneAt: done ? now : null,
    priority: TaskPriority.medium,
    labels: [beta, alpha, beta],
    assignees: people,
    description: done ? allChecked : checklist,
    repeatAfter: const Duration(days: 7),
    percentDone: 0.4,
    hexColor: 'e8445a',
  );

  Future<void> pumpRow(
    WidgetTester tester,
    Task task, {
    int minimumPriority = 2,
    String? projectTitle,
    Color? projectColor,
    int depth = 0,
    String? parentTitle,
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
                  minimumPriority: minimumPriority,
                  projectTitle: projectTitle,
                  projectColor: projectColor,
                  depth: depth,
                  parentTitle: parentTitle,
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

  testWidgets("shows the web row's content", (tester) async {
    await pumpRow(
      tester,
      richTask(),
      projectTitle: 'Work',
      projectColor: const Color(0xFF1973FF),
      pending: true,
    );

    expect(find.text('WORK-7 · Work'), findsOneWidget);
    expect(find.byType(ColorDot), findsNWidgets(2));
    expect(find.text('1 day ago'), findsOneWidget);
    final context = tester.element(find.text('1 day ago'));
    expect(
      tester.widget<Text>(find.text('1 day ago')).style?.color,
      Theme.of(context).colorScheme.error,
    );
    expect(find.text(en.priorityMedium), findsOneWidget);
    expect(
      [
        for (final chip in tester.widgetList<LabelChip>(find.byType(LabelChip)))
          chip.label.title,
      ],
      ['alpha', 'Beta'],
    );
    expect(find.byType(InitialsAvatar), findsNWidgets(3));
    expect(find.text(en.taskMoreAssignees(1)), findsOneWidget);
    expect(find.byIcon(Icons.notes), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(find.text(en.taskChecklistProgress(1, 2)), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('40'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('a done task keeps its due date, uncoloured, and drops its '
      'priority', (tester) async {
    await pumpRow(tester, richTask(done: true));

    expect(
      tester.widget<Text>(find.text('Pay the bill')).style?.decoration,
      TextDecoration.lineThrough,
    );
    final context = tester.element(find.text('1 day ago'));
    expect(
      tester.widget<Text>(find.text('1 day ago')).style?.color,
      isNot(Theme.of(context).colorScheme.error),
    );
    expect(find.byType(PriorityChip), findsNothing);
    expect(find.text(en.taskChecklistAllDone(2)), findsOneWidget);
  });

  testWidgets('each element only shows when the web shows it', (tester) async {
    await pumpRow(
      tester,
      sampleTask(
        id: 1,
        title: 'Plain',
        description: '<p></p>',
        repeatMode: RepeatMode.fromCurrentDate,
        priority: TaskPriority.high,
      ),
      minimumPriority: 4,
    );

    expect(find.byType(PriorityChip), findsNothing);
    expect(find.byIcon(Icons.notes), findsNothing);
    expect(find.byIcon(Icons.repeat), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(ChecklistSummary), findsNothing);
    expect(find.byType(ColorDot), findsNothing);
    expect(find.byType(AssigneeAvatars), findsNothing);
    expect(find.text('#1'), findsOneWidget);

    await pumpRow(
      tester,
      sampleTask(
        id: 1,
        title: 'Monthly',
        repeatMode: RepeatMode.monthly,
        priority: TaskPriority.low,
      ),
      minimumPriority: 1,
    );
    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(find.text(en.priorityLow), findsOneWidget);
  });

  testWidgets('a task not yet sent shows no identifier', (tester) async {
    await pumpRow(tester, sampleTask(id: -3, title: 'New'));

    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('the texts are one semantics node that reads everything', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(tester, richTask(), projectTitle: 'Work', pending: true);

    final node = tester.getSemantics(find.text('Pay the bill'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.label.split('\n'), [
      'Pay the bill',
      'WORK-7 · Work',
      en.taskOverdueSemantics('1 day ago'),
      en.prioritySemantics(en.priorityMedium),
      en.labelSemantics('alpha'),
      en.labelSemantics('Beta'),
      en.taskAssigneesSemantics('Anna, ben, Cleo, Dan'),
      en.taskHasDescription,
      en.taskRepeats,
      en.taskChecklistProgress(1, 2),
      en.taskPercentDone(40),
      en.taskNotYetSynced,
    ]);
    expect(tester.getSemantics(find.text('1 day ago')), same(node));
    expect(tester.getSemantics(find.text(en.priorityMedium)), same(node));

    await pumpRow(tester, richTask(done: true));
    expect(
      tester.getSemantics(find.text('Pay the bill')).label,
      startsWith('Pay the bill\n${en.taskDoneSemantics}\n'),
    );

    await pumpRow(tester, richTask(), depth: 5, parentTitle: 'Plan the trip');
    expect(
      tester.getSemantics(find.text('Pay the bill')).label,
      startsWith(
        'Pay the bill\n${en.taskSubtaskOfSemantics('Plan the trip')}\n',
      ),
    );
    semantics.dispose();
  });

  testWidgets('a subtask is indented by its depth, at most four levels', (
    tester,
  ) async {
    double start() => tester.getTopLeft(find.byTooltip(en.taskMarkDone)).dx;
    await pumpRow(tester, sampleTask(id: 1, title: 'Row'));
    final flat = start();
    await pumpRow(tester, sampleTask(id: 1, title: 'Row'), depth: 2);
    expect(start() - flat, 44);
    await pumpRow(tester, sampleTask(id: 1, title: 'Row'), depth: 9);
    expect(start() - flat, 88);
  });

  testWidgets('fits at 200 % text on a narrow screen in dark mode', (
    tester,
  ) async {
    usePhoneSurface(tester, logicalSize: const Size(320, 640));
    useAccessibilityExtremes(tester);
    await pumpRow(tester, richTask(), projectTitle: 'Work', depth: 4);

    expect(
      Theme.of(tester.element(find.byType(TaskRow))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  test('labels are deduplicated by id, the last copy where the first was, '
      'and sorted by title', () {
    final renamed = sampleLabel(id: 2, title: 'Aardvark');
    expect(rowLabels([beta, alpha, renamed]).map((label) => label.title), [
      'Aardvark',
      'alpha',
    ]);
  });

  test("an editor's empty paragraph is no description", () {
    expect(hasDescription(sampleTask(id: 1, title: 'a')), isFalse);
    expect(
      hasDescription(sampleTask(id: 1, title: 'a', description: '<p></p>')),
      isFalse,
    );
    expect(
      hasDescription(sampleTask(id: 1, title: 'a', description: '<p>x</p>')),
      isTrue,
    );
  });
}
