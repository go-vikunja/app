import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';

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
      for (var i = 1; i <= 25; i++) sampleTask(id: i, title: 'Open $i'),
      for (var i = 26; i <= 27; i++)
        sampleTask(id: i, title: 'Done $i', done: true),
      sampleTask(id: 30, title: 'Elsewhere', projectId: 2),
    ];
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
    await pumpSignedInApp(tester, sync: data, now: now);
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

  testWidgets('shows every open task of the project, newest first, under '
      'its title', (tester) async {
    await pumpProject(tester);

    expect(find.widgetWithText(AppBar, 'Work'), findsOneWidget);
    expect(loaded(tester), 25);
    expect(find.text('Open 25'), findsOneWidget);
    expect(find.text('Done 26'), findsNothing);
    expect(find.text('Elsewhere'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Open 25')).dy,
      lessThan(tester.getTopLeft(find.text('Open 24')).dy),
    );

    await tester.scrollUntilVisible(find.text('Open 1'), 300);
    expect(find.text(en.projectTasksLoadMore), findsNothing);
  });

  testWidgets('show done includes the done tasks, struck through', (
    tester,
  ) async {
    await pumpProject(tester);

    await toggleShowDone(tester);

    // Newest first: both done tasks lead the list.
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

  testWidgets('a list the repository reports as incomplete can load more', (
    tester,
  ) async {
    // Everything fits, so only the button can ask for more.
    usePhoneSurface(tester, logicalSize: const Size(400, 3000));
    data.tasks.all = [sampleTask(id: 1, title: 'Open 1')];
    data.tasks.hasMore = true;
    data.tasks.onLoadMore = () async {
      data.tasks.hasMore = false;
      data.tasks.all = [...data.tasks.all, sampleTask(id: 2, title: 'Open 2')];
    };
    await pumpProject(tester);
    expect(find.text(en.projectTasksLoadMore), findsOneWidget);

    await tester.tap(find.text(en.projectTasksLoadMore));
    await tester.pumpAndSettle();

    expect(data.tasks.loadMoreCalls, 1);
    expect(find.text('Open 2'), findsOneWidget);
    expect(find.text(en.projectTasksLoadMore), findsNothing);
  });

  testWidgets('a refresh the server fails keeps the rows and shows a notice', (
    tester,
  ) async {
    await pumpProject(tester);
    data.engine.onRefresh = () async => throw const Forbidden(code: 3004);

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(loaded(tester), 25);
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(
      find.text(en.dataFailureForbidden('tasks.example.org')),
      findsOneWidget,
    );

    data.engine.onRefresh = null;
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();
    expect(find.byType(DataFailureCard), findsNothing);
    expect(data.engine.refreshCalls, 2);
  });

  testWidgets('offline, the saved tasks stay with the quiet notice', (
    tester,
  ) async {
    await pumpProject(tester);
    data.engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(loaded(tester), 25);
    expect(find.byType(OfflineNotice), findsOneWidget);
    expect(find.byType(DataFailureCard), findsNothing);
  });

  testWidgets('empty states differ with and without done tasks', (
    tester,
  ) async {
    data.tasks.all = [sampleTask(id: 1, title: 'Done', done: true)];
    await pumpProject(tester);
    expect(find.text(en.projectTasksEmptyTitle), findsOneWidget);

    await toggleShowDone(tester);
    expect(find.text('Done'), findsOneWidget);

    data.engine.onRefresh = () async => data.tasks.all = [];
    await pullToRefresh(tester, find.byType(CustomScrollView));
    expect(find.text(en.projectTasksEmptyAllTitle), findsOneWidget);
  });

  testWidgets('the app bar button refreshes without a drag', (tester) async {
    await pumpProject(tester);
    data.engine.onRefresh = () async =>
        data.tasks.all = [sampleTask(id: 1, title: 'Only one')];

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(data.engine.refreshCalls, 1);
    expect(loaded(tester), 1);
    expect(find.text('Only one'), findsOneWidget);
  });

  testWidgets('a project missing from the list still shows its tasks', (
    tester,
  ) async {
    data.tasks.all = [sampleTask(id: 1, title: 'Lonely', projectId: 42)];
    await pumpProject(tester, id: 42);

    expect(find.widgetWithText(AppBar, en.projectUnknownTitle), findsOneWidget);
    expect(find.text('Lonely'), findsOneWidget);
  });
}
