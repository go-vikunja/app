import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/presentation/reorder_slot.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/announcer_region.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  final listView = sampleListView(id: 11, projectId: 1);
  final everything = sampleListView(
    id: 12,
    projectId: 1,
    title: 'Everything',
    position: 200,
    filter: '',
  );
  final urgent = sampleListView(
    id: 13,
    projectId: 1,
    title: 'Urgent',
    position: 300,
    filter: 'priority >= 4',
  );

  Project work({
    List<ProjectView>? views,
    bool archived = false,
    int parent = 0,
  }) => sampleProject(
    id: 1,
    title: 'Work',
    archived: archived,
    parent: parent,
    views: views ?? [listView, everything, urgent],
  );

  List<Task> tasks() => [
    sampleTask(id: 1, title: 'Alpha', subtaskIds: [2]),
    sampleTask(id: 2, title: 'Alpha child', parentIds: [1]),
    sampleTask(id: 3, title: 'Bravo'),
    sampleTask(id: 4, title: 'Charlie'),
    sampleTask(id: 5, title: 'Delta'),
    sampleTask(id: 9, title: 'Done nine', done: true, doneAt: now),
  ];

  const positions = <int, double>{1: 100, 2: 150, 3: 200, 4: 300, 5: 400};

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [work()];
    data.tasks.all = tasks();
    data.tasks.setSnapshot(
      'view:11',
      ListSnapshot(positions: positions, loadedAt: now),
    );
  });

  Future<void> pumpProject(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1600));
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
    await tester.pumpAndSettle();
  }

  List<(String, int)> rows(WidgetTester tester) => [
    for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
      (row.task.title, row.depth),
  ];

  Finder rowOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(TaskRow));

  /// Long-presses [title]'s row and moves it to [to] in steps, so the list
  /// follows the finger, then lets go.
  Future<void> dragRow(WidgetTester tester, String title, Offset to) async {
    final from = tester.getCenter(rowOf(title));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// The line between the rows [above] and [below].
  Offset between(WidgetTester tester, String above, String below) {
    final upper = tester.getRect(rowOf(above));
    final lower = tester.getRect(rowOf(below));
    return Offset(upper.center.dx, (upper.bottom + lower.top) / 2);
  }

  Offset aboveRow(WidgetTester tester, String title) {
    final rect = tester.getRect(rowOf(title));
    return Offset(rect.center.dx, rect.top + 4);
  }

  List<String> actionsOf(WidgetTester tester, String title) => [
    for (final id
        in tester
                .getSemantics(find.text(title))
                .getSemanticsData()
                .customSemanticsActionIds ??
            const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  void performAction(WidgetTester tester, String title, String label) {
    final node = tester.getSemantics(find.text(title));
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
    );
  }

  List<Object?> recordHaptics(WidgetTester tester) {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  group('dragging', () {
    testWidgets('a top-level row dropped between two others takes the '
        'position between them and brings its subtasks, with a haptic and '
        'an announcement', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpProject(tester);
      expect(rows(tester), [
        ('Alpha', 0),
        ('Alpha child', 1),
        ('Bravo', 0),
        ('Charlie', 0),
        ('Delta', 0),
      ]);

      await dragRow(tester, 'Alpha', between(tester, 'Charlie', 'Delta'));

      expect(data.tasks.positions, [(1, 11, 350)]);
      expect(rows(tester), [
        ('Bravo', 0),
        ('Charlie', 0),
        ('Alpha', 0),
        ('Alpha child', 1),
        ('Delta', 0),
      ]);
      // The lift's and the drop's.
      expect(
        haptics.where((kind) => kind == 'HapticFeedbackType.selectionClick'),
        hasLength(2),
      );
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedDown),
      ]);
    });

    testWidgets('the held rows hang above the finger, clear of the drop '
        'line', (tester) async {
      await pumpProject(tester);
      final aboveDelta = between(tester, 'Charlie', 'Delta');
      final onCharlie = tester.getCenter(rowOf('Charlie'));
      final gesture = await tester.startGesture(
        tester.getCenter(rowOf('Alpha')),
      );
      await tester.pump(const Duration(milliseconds: 600));

      for (final to in [aboveDelta, onCharlie]) {
        await gesture.moveTo(to);
        await tester.pump();
        // Measured inside the translation that lifts it.
        final lifted = tester.getRect(
          find
              .descendant(
                of: find.byType(LiftedRows),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(lifted.bottom, lessThan(to.dy));
        expect(lifted.overlaps(tester.getRect(find.byType(DropLine))), false);
      }

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a long press on the done control or the star lifts the row '
        'too', (tester) async {
      await pumpProject(tester);
      final doneControl = find.descendant(
        of: rowOf('Bravo'),
        matching: find.byTooltip(en.taskMarkDone),
      );

      final gesture = await tester.startGesture(tester.getCenter(doneControl));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LiftedRows), findsOne);
      await gesture.moveTo(aboveRow(tester, 'Alpha'));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['position 3 view 11 at 50.0']);
    });

    testWidgets('on top a row takes half the first position, at the end '
        '2^16 more than the last', (tester) async {
      await pumpProject(tester);

      await dragRow(tester, 'Delta', aboveRow(tester, 'Alpha'));
      expect(data.tasks.positions, [(5, 11, 50)]);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedUp),
      ]);

      final last = tester.getRect(rowOf('Charlie'));
      await dragRow(tester, 'Bravo', Offset(last.center.dx, last.bottom - 4));
      expect(data.tasks.positions.last, (3, 11, 300 + 65536));
    });

    testWidgets('while a row is held, a line shows where it would go, none '
        'where it would change nothing', (tester) async {
      await pumpProject(tester);
      // The held rows also hang under the finger.
      final aboveDelta = between(tester, 'Charlie', 'Delta');
      final deltaTop = tester.getRect(rowOf('Delta')).top;
      final whereItWas = between(tester, 'Alpha child', 'Bravo');
      final gesture = await tester.startGesture(
        tester.getCenter(rowOf('Alpha')),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await gesture.moveTo(aboveDelta);
      await tester.pump();
      expect(find.byType(DropLine), findsOne);
      expect(tester.getRect(find.byType(DropLine)).top, deltaTop);

      await gesture.moveTo(whereItWas);
      await tester.pump();
      expect(find.byType(DropLine), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(data.tasks.positions, isEmpty);
    });

    testWidgets('the list scrolls while a row is held near its end', (
      tester,
    ) async {
      data.tasks.all = [
        for (var id = 1; id <= 30; id++) sampleTask(id: id, title: 'Task $id'),
      ];
      data.tasks.setSnapshot(
        'view:11',
        ListSnapshot(
          positions: {for (var id = 1; id <= 30; id++) id: id * 100.0},
          loadedAt: now,
        ),
      );
      await pumpProject(tester);
      tester.view.physicalSize = const Size(400, 700) * 3;
      await tester.pumpAndSettle();
      final list = find
          .ancestor(of: rowOf('Task 1'), matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(list).position;
      expect(position.pixels, 0);

      final from = tester.getCenter(rowOf('Task 2'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(from.dx, tester.getRect(list).bottom - 8));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(position.pixels, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(data.tasks.positions.single.$1, 2);
    });

    testWidgets('a row dropped where it was changes nothing', (tester) async {
      await pumpProject(tester);

      await dragRow(tester, 'Bravo', between(tester, 'Alpha child', 'Bravo'));
      await dragRow(tester, 'Bravo', between(tester, 'Bravo', 'Charlie'));

      expect(data.tasks.positions, isEmpty);
    });

    testWidgets('a task without a downloaded position counts below the '
        'first placed one, as on the board', (tester) async {
      data.tasks.all = [...tasks(), sampleTask(id: 10, title: 'New')];
      await pumpProject(tester);
      expect(rows(tester).first, ('New', 0));

      await dragRow(tester, 'Delta', between(tester, 'New', 'Alpha'));

      expect(data.tasks.positions, [(5, 11, 75)]);
      expect(rows(tester).take(2), [('New', 0), ('Delta', 0)]);
    });

    testWidgets('dropped above tasks without a downloaded position, a row '
        'shows there: theirs are queued too, first', (tester) async {
      data.tasks.all = [
        ...tasks(),
        sampleTask(id: 10, title: 'New'),
        sampleTask(id: 11, title: 'Newer'),
      ];
      await pumpProject(tester);
      expect(rows(tester).take(3), [('Newer', 0), ('New', 0), ('Alpha', 0)]);

      await dragRow(tester, 'Delta', aboveRow(tester, 'Newer'));

      expect(data.tasks.positions, [
        (11, 11, 100 / 3),
        (10, 11, 200 / 3),
        (5, 11, 50 / 3),
      ]);
      expect(rows(tester).take(4), [
        ('Delta', 0),
        ('Newer', 0),
        ('New', 0),
        ('Alpha', 0),
      ]);
    });

    testWidgets('nested rows, the done part and the copy of a task just '
        'marked done stay where they are', (tester) async {
      data.listPreferences.views['view:11'] = const ViewPreferences(
        showDone: true,
      );
      await pumpProject(tester);
      expect(rows(tester).last, ('Done nine', 0));

      await dragRow(tester, 'Alpha child', aboveRow(tester, 'Delta'));
      await dragRow(tester, 'Done nine', aboveRow(tester, 'Alpha'));
      expect(data.tasks.positions, isEmpty);
      expect(actionsOf(tester, 'Alpha child'), isEmpty);
      expect(actionsOf(tester, 'Done nine'), isEmpty);

      await tester.tap(
        find.descendant(
          of: rowOf('Charlie'),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );
      await tester.pump();
      expect(rows(tester)[3], ('Charlie', 0));
      expect(actionsOf(tester, 'Charlie'), isEmpty);
      await dragRow(tester, 'Charlie', aboveRow(tester, 'Alpha'));
      expect(data.tasks.positions, isEmpty);
      // The rows around it still move past it.
      expect(
        actionsOf(tester, 'Bravo'),
        unorderedEquals([en.moveUp, en.moveDown]),
      );
    });

    testWidgets('a server-only filter view is put in order like the others', (
      tester,
    ) async {
      data.listPreferences.lastViews[1] = 13;
      data.tasks.setSnapshot(
        'view:13',
        ListSnapshot(positions: const {5: 10, 3: 20, 4: 30}, loadedAt: now),
      );
      await pumpProject(tester);
      expect(rows(tester), [('Delta', 0), ('Bravo', 0), ('Charlie', 0)]);

      await dragRow(tester, 'Charlie', aboveRow(tester, 'Bravo'));

      expect(data.tasks.positions, [(4, 13, 15)]);
    });

    testWidgets('two seconds after its own positions were sent the list '
        'downloads again', (tester) async {
      await pumpProject(tester);

      await dragRow(tester, 'Alpha', between(tester, 'Charlie', 'Delta'));
      expect(data.tasks.queuedPositions[11], {1: 350});
      await tester.pump(const Duration(seconds: 3));
      expect(data.tasks.projectListRefreshes, isEmpty);

      data.tasks.setQueuedPositions(11, const {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(data.tasks.projectListRefreshes, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(data.tasks.projectListRefreshes, [(1, 11)]);
    });

    testWidgets('a queued position shows at once; once discarded the row is '
        'back in its place', (tester) async {
      data.tasks.setQueuedPositions(11, const {5: 50});
      await pumpProject(tester);
      expect(rows(tester).first, ('Delta', 0));

      data.tasks.setQueuedPositions(11, const {});
      await tester.pumpAndSettle();
      expect(rows(tester).last, ('Delta', 0));
    });
  });

  group('only where the web allows it', () {
    testWidgets('not under another sort than manually', (tester) async {
      data.listPreferences.views['view:11'] = const ViewPreferences(
        sort: TaskListSort.titleDesc,
      );
      await pumpProject(tester);
      expect(rows(tester).first, ('Delta', 0));

      await dragRow(tester, 'Bravo', aboveRow(tester, 'Delta'));

      expect(data.tasks.positions, isEmpty);
      expect(actionsOf(tester, 'Bravo'), isEmpty);
    });

    testWidgets('not in an archived project', (tester) async {
      data.projects.all = [work(archived: true)];
      await pumpProject(tester);

      await dragRow(tester, 'Delta', aboveRow(tester, 'Alpha'));

      expect(data.tasks.positions, isEmpty);
      expect(actionsOf(tester, 'Bravo'), isEmpty);
    });

    testWidgets('not in a project archived with its parent, which adds and '
        'marks nothing either', (tester) async {
      data.projects.all = [
        sampleProject(id: 20, title: 'Old', archived: true),
        work(parent: 20),
      ];
      await pumpProject(tester);

      await dragRow(tester, 'Delta', aboveRow(tester, 'Alpha'));

      expect(data.tasks.positions, isEmpty);
      expect(actionsOf(tester, 'Bravo'), isEmpty);
      expect(find.byTooltip(en.newTask), findsNothing);
      await tester.tap(
        find.descendant(
          of: rowOf('Bravo'),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.tasks.writes, isEmpty);
    });

    testWidgets('not before the view was downloaded: its order is made up', (
      tester,
    ) async {
      data.tasks.setSnapshot('view:11', const ListSnapshot());
      await pumpProject(tester);
      expect(rows(tester).first, ('Delta', 0));

      await dragRow(tester, 'Alpha', aboveRow(tester, 'Delta'));

      expect(data.tasks.positions, isEmpty);
      expect(actionsOf(tester, 'Bravo'), isEmpty);
    });

    testWidgets('not in a project without a list view', (tester) async {
      data.projects.all = [work(views: const [])];
      await pumpProject(tester);

      await dragRow(tester, 'Delta', aboveRow(tester, 'Alpha'));

      expect(data.tasks.positions, isEmpty);
      expect(actionsOf(tester, 'Bravo'), isEmpty);
    });
  });

  group('screen readers', () {
    testWidgets('move a top-level row up or down among the top-level rows, '
        'announced', (tester) async {
      await pumpProject(tester);

      expect(actionsOf(tester, 'Alpha'), unorderedEquals([en.moveDown]));
      expect(
        actionsOf(tester, 'Bravo'),
        unorderedEquals([en.moveUp, en.moveDown]),
      );
      expect(actionsOf(tester, 'Delta'), unorderedEquals([en.moveUp]));

      performAction(tester, 'Charlie', en.moveUp);
      await tester.pumpAndSettle();
      expect(data.tasks.positions, [(4, 11, 150)]);
      expect(rows(tester)[2], ('Charlie', 0));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedUp),
      ]);

      performAction(tester, 'Alpha', en.moveDown);
      await tester.pumpAndSettle();
      expect(data.tasks.positions.last, (1, 11, 175));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedDown),
      ]);
    });

    testWidgets('without platform announcements, as on Android, a move is '
        'said by the live region', (tester) async {
      useLiveRegionAnnouncements(tester);
      await pumpProject(tester);

      performAction(tester, 'Charlie', en.moveUp);
      await tester.pumpAndSettle();

      expect(data.tasks.positions, [(4, 11, 150)]);
      expect(tester.takeAnnouncements(), isEmpty);
      final region = announcerRegion(tester)!;
      expect(region.label, en.movedUp);
      expect(region.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('are in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpProject(tester);

      expect(
        actionsOf(tester, 'Bravo'),
        unorderedEquals([de.moveUp, de.moveDown]),
      );
      performAction(tester, 'Bravo', de.moveDown);
      await tester.pumpAndSettle();
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(de.movedDown),
      ]);
    });
  });
}
