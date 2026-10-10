import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  final work = sampleProject(id: 1, title: 'Work', identifier: 'WORK');
  final home = sampleProject(id: 2, title: 'Home');
  final light = sampleLabel(id: 1, title: 'Sunny', hexColor: 'ffeb10');
  final dark = sampleLabel(id: 2, title: 'Night', hexColor: '1a1a1a');

  List<Task> openTasks() => [
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

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [work, home];
    data.tasks.all = [
      ...openTasks(),
      sampleTask(id: 6, title: 'Already done', done: true),
    ];
  });

  Future<void> pumpOverview(WidgetTester tester) async {
    // Tall enough for every section, which the list builds lazily.
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, now: now);
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
    expect(find.text('Already done'), findsNothing);
    expect(find.text('WORK-1 · Work'), findsOneWidget);
    expect(find.text('#2 · Home'), findsOneWidget);
    expect(find.text('1 day ago'), findsOneWidget);
    expect(find.text('in 6 hours'), findsOneWidget);
    expect(find.text('in 3 days'), findsOneWidget);
    expect(find.text('in 20 days'), findsOneWidget);
    // Synced just now: no quiet sync at start.
    expect(data.engine.refreshCalls, 0);
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
    data.tasks.all = [sampleTask(id: 6, title: 'Already done', done: true)];
    await pumpOverview(tester);

    expect(find.text(en.overviewEmptyTitle), findsOneWidget);
    expect(find.text(en.overviewEmptyBody), findsOneWidget);
  });

  testWidgets('a change in the local data shows without a refresh', (
    tester,
  ) async {
    await pumpOverview(tester);

    data.tasks.all = [sampleTask(id: 7, title: 'Just synced')];
    await tester.pumpAndSettle();

    expect(find.byType(TaskRow), findsOneWidget);
    expect(find.text('Just synced'), findsOneWidget);
  });

  testWidgets('a refresh the server fails keeps the rows and shows a notice', (
    tester,
  ) async {
    await pumpOverview(tester);
    data.engine.onRefresh = () async => throw const ServerFailure(502);

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(find.byType(TaskRow), findsNWidgets(5));
    expect(find.text(en.dataFailureRefreshTitle), findsOneWidget);
    expect(find.textContaining(en.dataFailureStaleNote), findsOneWidget);
    expect(data.engine.refreshCalls, 1);

    data.engine.onRefresh = () async =>
        data.tasks.all = openTasks().sublist(0, 2);
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(find.byType(TaskRow), findsNWidgets(2));
    expect(data.engine.refreshCalls, 2);
  });

  testWidgets('offline, a refresh shows the quiet notice over the saved data', (
    tester,
  ) async {
    await pumpOverview(tester);
    data.engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(find.byType(TaskRow), findsNWidgets(5));
    expect(find.byType(OfflineNotice), findsOneWidget);
    expect(find.text(en.offlineNotice), findsOneWidget);
    expect(find.byType(DataFailureCard), findsNothing);

    // Back online, the next sync clears it.
    data.engine.onRefresh = null;
    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineNotice), findsNothing);
  });

  testWidgets('the quiet sync at start failing offline shows the notice too', (
    tester,
  ) async {
    data = SyncFakes(
      now: now,
      status: SyncIdle(lastSyncedAt: now.subtract(const Duration(hours: 2))),
    );
    data.projects.all = [work, home];
    data.tasks.all = openTasks();
    data.engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.timeout);

    await pumpOverview(tester);

    expect(data.engine.refreshCalls, 1);
    expect(find.byType(TaskRow), findsNWidgets(5));
    expect(find.byType(OfflineNotice), findsOneWidget);
    expect(find.byType(DataFailureCard), findsNothing);
  });

  testWidgets('a quiet sync at start that fails on the server shows nothing', (
    tester,
  ) async {
    data = SyncFakes(
      now: now,
      status: SyncIdle(lastSyncedAt: now.subtract(const Duration(hours: 2))),
    );
    data.tasks.all = openTasks();
    data.engine.onRefresh = () async => throw const ServerFailure(500);

    await pumpOverview(tester);

    expect(data.engine.refreshCalls, 1);
    expect(find.byType(OfflineNotice), findsNothing);
    expect(find.byType(DataFailureCard), findsNothing);
    expect(find.byType(TaskRow), findsNWidgets(5));
  });

  testWidgets('the app bar button refreshes without a drag', (tester) async {
    await pumpOverview(tester);
    data.engine.onRefresh = () async =>
        data.tasks.all = openTasks().sublist(0, 1);

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(data.engine.refreshCalls, 1);
    expect(find.byType(TaskRow), findsOneWidget);
  });

  testWidgets('the refresh button waits for a running sync', (tester) async {
    await pumpOverview(tester);
    final run = Completer<void>();
    data.engine.onRefresh = () => run.future;

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pump();

    final refreshButton = find.widgetWithIcon(IconButton, Icons.refresh);
    expect(tester.widget<IconButton>(refreshButton).onPressed, isNull);

    run.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(refreshButton).onPressed, isNotNull);
  });

  group('"now" moves on', () {
    late DateTime current;

    void lifecycle(WidgetTester tester, List<AppLifecycleState> states) =>
        states.forEach(tester.binding.handleAppLifecycleStateChanged);

    Future<void> pumpLateEvening(WidgetTester tester) async {
      current = DateTime(2026, 10, 10, 22);
      data = SyncFakes(now: current);
      data.tasks.all = [
        sampleTask(id: 1, title: 'Late task', due: DateTime(2026, 10, 10, 23)),
      ];
      await pumpSignedInApp(
        tester,
        sync: data,
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
    await pumpOverview(tester);
    data.engine.onRefresh = () async =>
        throw const SessionEnded(SessionEndReason.expired, code: 16003);

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(
      find.text(en.dataFailureSessionEnded('tasks.example.org')),
      findsOneWidget,
    );
  });

  testWidgets('German sections, relative dates and the offline notice', (
    tester,
  ) async {
    useLocale(tester, const Locale('de'));
    await pumpOverview(tester);

    expect(sectionTitles(tester).first, de.sectionOverdue);
    expect(find.text('vor 1 Tag'), findsOneWidget);
    expect(find.text('in 3 Tagen'), findsOneWidget);

    data.engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    await tester.tap(find.byTooltip(de.refresh));
    await tester.pumpAndSettle();
    expect(find.text(de.offlineNotice), findsOneWidget);
  });
}
