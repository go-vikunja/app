import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';

import '../../helpers/fake_read_client.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late FakeReadClient client;

  setUp(() {
    client = FakeReadClient();
    client.projects.all = [sampleProject(id: 1, title: 'Work')];
    client.tasks.perPage = 10;
    client.tasks.projectTasks = {
      1: [
        for (var i = 1; i <= 25; i++) sampleTask(id: i, title: 'Open $i'),
        for (var i = 26; i <= 27; i++)
          sampleTask(id: i, title: 'Done $i', done: true),
      ],
    };
  });

  // The item's text sits under an IgnorePointer; the item itself takes taps.
  Future<void> toggleShowDone(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpProject(WidgetTester tester, {int id = 1}) async {
    await pumpSignedInApp(tester, readClient: client, now: now);
    containerOf(tester).read(appRouterProvider).go(AppRoutes.project(id));
    await tester.pumpAndSettle();
  }

  /// The list builds rows lazily, so the loaded count comes from the data.
  int loaded(WidgetTester tester, {bool showDone = false}) =>
      containerOf(tester)
          .read(projectTasksProvider(1, showDone: showDone))
          .value!
          .items
          .length;

  testWidgets('shows the first page with the project title, then loads more '
      'while scrolling', (tester) async {
    await pumpProject(tester);

    expect(find.widgetWithText(AppBar, 'Work'), findsOneWidget);
    expect(loaded(tester), 10);
    expect(find.text('Open 1'), findsOneWidget);
    expect(find.text('Done 26'), findsNothing);
    final (projectId, query) = client.tasks.projectQueries.single;
    expect(projectId, 1);
    expect(query.filter, 'done = false');
    expect(query.sort, TaskQuery.defaultSort);
    expect(query.page, 1);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(loaded(tester), 20);
    expect(client.tasks.projectQueries.last.$2.page, 2);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(loaded(tester), 25);
    await tester.scrollUntilVisible(find.text('Open 25'), 300);
    expect(find.text(en.projectTasksLoadMore), findsNothing);
    expect(client.tasks.projectQueries, hasLength(3));
  });

  testWidgets('the load-more button appends a page without scrolling', (
    tester,
  ) async {
    // Everything fits, so only the button can ask for more.
    usePhoneSurface(tester, logicalSize: const Size(400, 3000));
    await pumpProject(tester);

    await tester.tap(find.text(en.projectTasksLoadMore));
    await tester.pumpAndSettle();
    expect(loaded(tester), 20);

    await tester.tap(find.text(en.projectTasksLoadMore));
    await tester.pumpAndSettle();
    expect(loaded(tester), 25);
    expect(find.text(en.projectTasksLoadMore), findsNothing);
    expect(find.text('Open 25'), findsOneWidget);
  });

  testWidgets('show done re-queries without the done filter', (tester) async {
    await pumpProject(tester);

    await toggleShowDone(tester);

    expect(client.tasks.projectQueries.last.$2.filter, isNull);
    await tester.scrollUntilVisible(find.text('Done 26'), 300);
    await tester.pumpAndSettle();
    expect(loaded(tester, showDone: true), 27);
    final doneTitle = tester.widget<Text>(find.text('Done 26'));
    expect(doneTitle.style?.decoration, TextDecoration.lineThrough);
    final doneIcons = tester.widgetList<Icon>(find.byIcon(Icons.check_circle));
    expect(doneIcons.map((icon) => icon.semanticLabel), [
      en.taskDone,
      en.taskDone,
    ]);

    await toggleShowDone(tester);
    expect(find.text('Done 26'), findsNothing);
  });

  testWidgets('a failed load more keeps the rows and shows a notice', (
    tester,
  ) async {
    await pumpProject(tester);
    client.tasks.onListInProject = (_, _) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(loaded(tester), 10);
    expect(find.text('Open 10'), findsOneWidget);
    expect(find.text(en.dataFailureRefreshTitle), findsOneWidget);
    expect(find.text(en.projectTasksLoadMore), findsNothing);

    client.tasks.onListInProject = null;
    await tester.ensureVisible(find.text(en.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();
    expect(find.byType(DataFailureCard), findsNothing);
    expect(loaded(tester), 20);
  });

  testWidgets('a failed first load is explained and can be retried', (
    tester,
  ) async {
    client.tasks.onListInProject = (_, _) async =>
        throw const Forbidden(code: 3004);
    await pumpProject(tester);

    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(
      find.text(en.dataFailureForbidden('tasks.example.org')),
      findsOneWidget,
    );

    client.tasks.onListInProject = null;
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();
    expect(loaded(tester), 10);
  });

  testWidgets('empty states differ with and without done tasks', (
    tester,
  ) async {
    client.tasks.projectTasks = {
      1: [sampleTask(id: 1, title: 'Done', done: true)],
    };
    await pumpProject(tester);
    expect(find.text(en.projectTasksEmptyTitle), findsOneWidget);

    await toggleShowDone(tester);
    expect(find.text('Done'), findsOneWidget);

    client.tasks.projectTasks = {1: []};
    await pullToRefresh(tester, find.byType(CustomScrollView));
    expect(find.text(en.projectTasksEmptyAllTitle), findsOneWidget);
  });

  testWidgets('the app bar button refreshes without a drag', (tester) async {
    await pumpProject(tester);
    client.tasks.projectTasks = {
      1: [sampleTask(id: 1, title: 'Only one')],
    };

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(client.tasks.projectQueries, hasLength(2));
    expect(client.tasks.projectQueries.last.$2.page, 1);
    expect(loaded(tester), 1);
    expect(find.text('Only one'), findsOneWidget);
  });

  testWidgets('a project missing from the list still shows its tasks', (
    tester,
  ) async {
    client.tasks.projectTasks[42] = [
      sampleTask(id: 1, title: 'Lonely', projectId: 42),
    ];
    await pumpProject(tester, id: 42);

    expect(find.widgetWithText(AppBar, en.projectUnknownTitle), findsOneWidget);
    expect(find.text('Lonely'), findsOneWidget);
  });
}
