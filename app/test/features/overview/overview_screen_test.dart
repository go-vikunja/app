import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/fake_read_client.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late FakeReadClient client;
  final work = sampleProject(id: 1, title: 'Work', identifier: 'WORK');
  final home = sampleProject(id: 2, title: 'Home');
  final light = sampleLabel(id: 1, title: 'Sunny', hexColor: 'ffeb10');
  final dark = sampleLabel(id: 2, title: 'Night', hexColor: '1a1a1a');

  setUp(() {
    client = FakeReadClient();
    client.projects.all = [work, home];
    client.tasks.openTasks = [
      sampleTask(
        id: 1,
        title: 'Pay the bill',
        due: now.subtract(const Duration(days: 1)),
        identifier: 'WORK-1',
        priority: TaskPriority.urgent,
        labels: [light, dark],
      ),
      sampleTask(
        id: 2,
        title: 'Call mum',
        projectId: 2,
        due: now.add(const Duration(hours: 6)),
        favorite: true,
      ),
      sampleTask(
        id: 3,
        title: 'Write report',
        due: now.add(const Duration(days: 3)),
        identifier: 'WORK-3',
        priority: TaskPriority.high,
      ),
      sampleTask(
        id: 4,
        title: 'Plan trip',
        due: now.add(const Duration(days: 20)),
      ),
      sampleTask(id: 5, title: 'Someday', priority: TaskPriority.medium),
    ];
  });

  Future<void> pumpOverview(WidgetTester tester) async {
    // Tall enough for every section, which the list builds lazily.
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, readClient: client, now: now);
  }

  List<String> sectionTitles(WidgetTester tester) => [
    for (final header in tester.widgetList<ListSectionHeader>(
      find.byType(ListSectionHeader),
    ))
      header.title,
  ];

  testWidgets('groups the open tasks by due date with project and due', (
    tester,
  ) async {
    await pumpOverview(tester);

    expect(sectionTitles(tester), [
      en.sectionOverdue,
      en.sectionToday,
      en.sectionNextSevenDays,
      en.sectionLater,
      en.sectionNoDueDate,
    ]);
    expect(find.byType(TaskRow), findsNWidgets(5));
    expect(find.text('WORK-1 · Work'), findsOneWidget);
    expect(find.text('#2 · Home'), findsOneWidget);
    expect(find.text('1 day ago'), findsOneWidget);
    expect(find.text('in 6 hours'), findsOneWidget);
    expect(find.text('in 3 days'), findsOneWidget);
    expect(find.text('in 20 days'), findsOneWidget);
    expect(client.tasks.listQueries.single.filter, 'done = false');
    expect(client.tasks.listQueries.single.sort, TaskQuery.dueDateSort);
  });

  testWidgets('overdue due dates use the error colour', (tester) async {
    await pumpOverview(tester);

    final overdue = tester.widget<Text>(find.text('1 day ago'));
    final context = tester.element(find.text('1 day ago'));
    expect(overdue.style?.color, Theme.of(context).colorScheme.error);
    final upcoming = tester.widget<Text>(find.text('in 3 days'));
    expect(upcoming.style?.color, isNot(Theme.of(context).colorScheme.error));
  });

  testWidgets('shows priority chips for high and up, labels in their colour', (
    tester,
  ) async {
    await pumpOverview(tester);

    expect(find.byType(PriorityChip), findsNWidgets(2));
    expect(find.text(en.priorityUrgent), findsOneWidget);
    expect(find.text(en.priorityHigh), findsOneWidget);
    expect(find.text(en.priorityMedium), findsNothing);
    expect(find.byType(LabelChip), findsNWidgets(2));
    final sunny = tester.widget<Text>(find.text('Sunny'));
    expect(sunny.style?.color, const Color(0xFF000000));
    final night = tester.widget<Text>(find.text('Night'));
    expect(night.style?.color, const Color(0xFFFFFFFF));
    final star = tester.widget<Icon>(find.byIcon(Icons.star));
    expect(star.semanticLabel, en.favouriteLabel);
  });

  testWidgets('a row is one semantics node with status, due and labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpOverview(tester);

    final node = tester.getSemantics(find.text('Pay the bill'));
    expect(node.label, contains(en.taskNotDone));
    expect(node.label, contains('Pay the bill'));
    expect(node.label, contains(en.taskOverdueSemantics('1 day ago')));
    expect(node.label, contains(en.prioritySemantics(en.priorityUrgent)));
    expect(node.label, contains(en.labelSemantics('Sunny')));
    expect(
      tester.getSemantics(find.text('Write report')).label,
      contains(en.taskDueSemantics('in 3 days')),
    );
    semantics.dispose();
  });

  testWidgets('tapping a row opens the detail sheet', (tester) async {
    await pumpOverview(tester);

    await tester.tap(find.text('Write report'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsOneWidget);
    expect(
      find.text(en.taskDetailIdentifierInProject('WORK-3', 'Work')),
      findsOneWidget,
    );
  });

  testWidgets('without open tasks says all done', (tester) async {
    client.tasks.openTasks = [];
    await pumpOverview(tester);

    expect(find.text(en.overviewEmptyTitle), findsOneWidget);
    expect(find.text(en.overviewEmptyBody), findsOneWidget);
  });

  testWidgets('a failed first load is explained and can be retried', (
    tester,
  ) async {
    client.tasks.onList = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    await pumpOverview(tester);

    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(find.text(en.dataFailureLoadTitle), findsOneWidget);
    expect(
      find.text(en.failureUnreachableExplanation('tasks.example.org')),
      findsOneWidget,
    );
    expect(find.byType(TaskRow), findsNothing);

    client.tasks.onList = null;
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(find.byType(TaskRow), findsNWidgets(5));
  });

  testWidgets('a failed refresh keeps the rows and shows a notice', (
    tester,
  ) async {
    await pumpOverview(tester);
    client.tasks.onList = (_) async => throw const ServerFailure(502);

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(find.byType(TaskRow), findsNWidgets(5));
    expect(find.text(en.dataFailureRefreshTitle), findsOneWidget);
    expect(find.textContaining(en.dataFailureStaleNote), findsOneWidget);
    expect(client.tasks.listQueries, hasLength(2));

    client.tasks.onList = null;
    client.tasks.openTasks = client.tasks.openTasks.sublist(0, 2);
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(find.byType(TaskRow), findsNWidgets(2));
    expect(client.projects.listAllCalls, 3);
  });

  testWidgets('the app bar button refreshes without a drag', (tester) async {
    await pumpOverview(tester);
    client.tasks.openTasks = client.tasks.openTasks.sublist(0, 1);

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(client.tasks.listQueries, hasLength(2));
    expect(find.byType(TaskRow), findsOneWidget);
  });

  group('"now" moves on', () {
    late DateTime current;

    void lifecycle(WidgetTester tester, List<AppLifecycleState> states) =>
        states.forEach(tester.binding.handleAppLifecycleStateChanged);

    Future<void> pumpLateEvening(WidgetTester tester) async {
      current = DateTime(2026, 10, 10, 22);
      client.tasks.openTasks = [
        sampleTask(id: 1, title: 'Late task', due: DateTime(2026, 10, 10, 23)),
      ];
      await pumpSignedInApp(
        tester,
        readClient: client,
        overrides: [clockProvider.overrideWithValue(() => current)],
      );
      expect(sectionTitles(tester), [en.sectionToday]);
      expect(find.text('in 1 hour'), findsOneWidget);
    }

    testWidgets('coming back to the app re-evaluates sections and labels', (
      tester,
    ) async {
      await pumpLateEvening(tester);
      current = DateTime(2026, 10, 11, 8);

      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pumpAndSettle();

      expect(sectionTitles(tester), [en.sectionOverdue]);
      expect(find.text('9 hours ago'), findsOneWidget);
    });

    testWidgets('every minute while in front, never in the background', (
      tester,
    ) async {
      await pumpLateEvening(tester);
      current = DateTime(2026, 10, 11, 8);

      await tester.pump(const Duration(minutes: 1));

      expect(sectionTitles(tester), [en.sectionOverdue]);
      expect(find.text('9 hours ago'), findsOneWidget);

      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      current = DateTime(2026, 10, 11, 10);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('9 hours ago'), findsOneWidget);

      lifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pumpAndSettle();
      expect(find.text('11 hours ago'), findsOneWidget);
    });
  });

  testWidgets('a session the server ended points to the account tab', (
    tester,
  ) async {
    client.tasks.onList = (_) async =>
        throw const SessionEnded(SessionEndReason.expired, code: 16003);
    await pumpOverview(tester);

    expect(
      find.text(en.dataFailureSessionEnded('tasks.example.org')),
      findsOneWidget,
    );
  });

  testWidgets('German sections and relative dates', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpOverview(tester);

    expect(sectionTitles(tester).first, de.sectionOverdue);
    expect(find.text('vor 1 Tag'), findsOneWidget);
    expect(find.text('in 3 Tagen'), findsOneWidget);
  });
}
