import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/application/list_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_management.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/application/task_write_access.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/related_tasks_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 26, 12);
  late SyncFakes data;

  Project project(
    int id,
    String title, {
    Permission? permission,
    int parent = 0,
    double position = 0,
    bool archived = false,
  }) => sampleProject(
    id: id,
    title: title,
    parent: parent,
    position: position,
    archived: archived,
    views: [sampleListView(id: id * 10, projectId: id)],
  ).copyWith(maxPermission: permission);

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      project(1, 'Shared with me', permission: Permission.read, position: 1),
      project(2, 'Inbox', permission: Permission.read, position: 2),
      project(3, 'Team work', permission: Permission.write, position: 3),
      project(4, 'Mine', permission: Permission.admin, position: 4),
      project(5, 'Old', permission: Permission.admin, archived: true),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Read me'),
      sampleTask(
        id: 2,
        title: 'Write me',
        projectId: 3,
        relatedTasks: {
          TaskRelationKind.subtask: [
            sampleTask(id: 10, title: 'Sub in shared'),
            sampleTask(id: 11, title: 'Sub in mine', projectId: 4),
          ],
        },
      ),
    ];
  });

  Future<void> pumpProject(WidgetTester tester, int projectId) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(projectId));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
  }

  bool shown(String label) => find.text(label).evaluate().isNotEmpty;

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: finder);

  Future<void> scrollSheetTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        300,
        scrollable: inSheet(find.byType(Scrollable)).first,
      );

  T sheetWidget<T extends Widget>(WidgetTester tester) =>
      tester.widget<T>(inSheet(find.byType(T)));

  TaskDoneControl subtaskControl(WidgetTester tester, String title) =>
      tester.widget<TaskDoneControl>(
        find.descendant(
          of: find.widgetWithText(RelationRow, title),
          matching: find.byType(TaskDoneControl),
        ),
      );

  final writeItems = [
    en.projectEdit,
    en.projectAddToFavourites,
    en.projectNewSubproject,
    en.projectArchive,
  ];
  final adminItems = [en.projectViews, en.projectDelete];

  group('a project the user may only read', () {
    testWidgets('offers Share, Follow and Duplicate, nothing it would '
        'refuse', (tester) async {
      await pumpProject(tester, 1);
      await openMenu(tester);

      expect(shown(en.shareMenuItem), isTrue);
      expect(shown(en.followProject), isTrue);
      expect(shown(en.projectDuplicate), isTrue);
      for (final item in [...writeItems, ...adminItems]) {
        expect(shown(item), isFalse, reason: item);
      }
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip(en.projectAddToFavourites),
        ),
        findsNothing,
      );
    });

    testWidgets('has no new task button and says it is read only', (
      tester,
    ) async {
      await pumpProject(tester, 1);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text(en.shareReadOnlyProjectNote), findsOneWidget);
    });

    testWidgets("rows' checkboxes are off and say so", (tester) async {
      await pumpProject(tester, 1);

      final control = tester.widget<TaskDoneControl>(
        find.descendant(
          of: find.widgetWithText(TaskRow, 'Read me'),
          matching: find.byType(TaskDoneControl),
        ),
      );
      expect(control.onChanged, isNull);
      expect(control.readOnly, isTrue);
      expect(find.byTooltip(en.shareTaskReadOnly), findsOneWidget);
      final star = tester.widget<FavouriteButton>(
        find.descendant(
          of: find.widgetWithText(TaskRow, 'Read me'),
          matching: find.byType(FavouriteButton),
        ),
      );
      expect(star.onChanged, isNull);
    });

    testWidgets('the task sheet offers no change to the task, only its '
        'link', (tester) async {
      await pumpProject(tester, 1);

      await tester.tap(find.text('Read me'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text(en.taskDetailMarkDone), findsNothing);
      expect(find.byTooltip(en.taskEdit), findsNothing);
      await tester.tap(inSheet(find.byTooltip(en.moreActions)));
      await tester.pumpAndSettle();
      expect(find.text(en.taskCopyLink), findsOneWidget);
      expect(find.text(en.taskShareLink), findsOneWidget);
      expect(find.text(en.taskDuplicate), findsNothing);
      expect(find.text(en.taskDelete), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // Comments follow the stored permission while the server's details
      // leave it open.
      await tester.scrollUntilVisible(
        find.text(en.commentsReadOnlyNote),
        300,
        scrollable: find
            .descendant(
              of: find.byType(TaskDetailSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(en.commentsReadOnlyNote), findsOneWidget);
    });

    testWidgets('the task sheet offers no favourite, relation or attachment '
        'either', (tester) async {
      await pumpProject(tester, 1);

      await tester.tap(find.text('Read me'));
      await tester.pumpAndSettle();

      expect(sheetWidget<FavouriteButton>(tester).onChanged, isNull);
      await scrollSheetTo(tester, inSheet(find.byType(RelatedTasksSection)));
      final related = sheetWidget<RelatedTasksSection>(tester);
      expect(related.onAdd, isNull);
      expect(related.onRemove, isNull);
      expect(inSheet(find.text(en.taskDetailAddRelation)), findsNothing);
      expect(sheetWidget<TaskAttachmentsSection>(tester).writable, isFalse);
    });

    testWidgets('the task sheet follows the stored permission over what an '
        'earlier read in this run said', (tester) async {
      await pumpProject(tester, 1);
      final container = containerOf(tester);
      container
          .read(taskWriteAccessProvider)
          .remember(
            container.read(activeAccountIdProvider)!,
            1,
            writable: true,
          );

      await tester.tap(find.text('Read me'));
      await tester.pumpAndSettle();

      expect(find.text(en.taskDetailMarkDone), findsNothing);
      expect(find.byTooltip(en.taskEdit), findsNothing);
      expect(sheetWidget<FavouriteButton>(tester).onChanged, isNull);
    });
  });

  group('a project the user may write', () {
    testWidgets('offers the changes but not what needs admin rights', (
      tester,
    ) async {
      await pumpProject(tester, 3);
      await openMenu(tester);

      for (final item in writeItems) {
        expect(shown(item), isTrue, reason: item);
      }
      for (final item in adminItems) {
        expect(shown(item), isFalse, reason: item);
      }
      expect(shown(en.shareMenuItem), isTrue);
    });

    testWidgets('keeps its new task button, rows and task sheet', (
      tester,
    ) async {
      await pumpProject(tester, 3);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text(en.shareReadOnlyProjectNote), findsNothing);
      expect(
        tester.widget<TaskDoneControl>(find.byType(TaskDoneControl)).onChanged,
        isNotNull,
      );
      await tester.tap(find.text('Write me'));
      await tester.pumpAndSettle();
      expect(find.text(en.taskDetailMarkDone), findsOneWidget);
      expect(sheetWidget<FavouriteButton>(tester).onChanged, isNotNull);
      await scrollSheetTo(tester, inSheet(find.byType(RelatedTasksSection)));
      expect(sheetWidget<RelatedTasksSection>(tester).onAdd, isNotNull);
    });

    testWidgets("a subtask's checkbox follows its own project", (tester) async {
      await pumpProject(tester, 3);
      await tester.tap(find.text('Write me'));
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, find.text('Sub in mine'));

      final shared = subtaskControl(tester, 'Sub in shared');
      expect(shared.onChanged, isNull);
      expect(shared.readOnly, isTrue);
      final mine = subtaskControl(tester, 'Sub in mine');
      expect(mine.onChanged, isNotNull);
      expect(mine.readOnly, isFalse);
    });
  });

  testWidgets('an admin sees every action', (tester) async {
    await pumpProject(tester, 4);
    await openMenu(tester);

    for (final item in [...writeItems, ...adminItems, en.shareMenuItem]) {
      expect(shown(item), isTrue, reason: item);
    }
  });

  testWidgets('an archived project offers no Share, as on the web', (
    tester,
  ) async {
    await pumpProject(tester, 5);
    await openMenu(tester);

    expect(shown(en.projectUnarchive), isTrue);
    expect(shown(en.shareMenuItem), isFalse);
  });

  testWidgets('a new task never goes to a project the user may only read', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(NewTaskSheet), findsOneWidget);
    // Not the read-only Inbox.
    await tester.tap(
      find.descendant(
        of: find.byType(NewTaskSheet),
        matching: find.text('Team work'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.taskEditProjectPickerTitle), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Mine'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Team work'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Inbox'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Shared with me'), findsNothing);
  });

  group('the rules', () {
    final projects = [
      project(1, 'Read', permission: Permission.read),
      project(2, 'Child', permission: Permission.write, parent: 1),
      project(3, 'Unknown'),
    ];

    test('new tasks and new or moved projects skip read-only projects', () {
      expect(writableProjects(projects).map((p) => p.id), [2, 3]);
      expect(defaultProjectFor(projects, currentProjectId: 1)?.id, isNot(1));
      expect(
        parentCandidates(projects).map((row) => row.node.project.id),
        unorderedEquals([2, 3]),
      );
    });

    test('lists and boards are fixed without write access', () {
      final view = sampleListView(id: 1, projectId: 1);
      expect(
        listIsReorderable(
          projectId: 1,
          view: view,
          sort: TaskListSort.manual,
          archived: false,
          writable: false,
        ),
        isFalse,
      );
      expect(
        listIsReorderable(
          projectId: 1,
          view: view,
          sort: TaskListSort.manual,
          archived: false,
        ),
        isTrue,
      );
      final board = sampleKanbanView(id: 2, projectId: 1);
      expect(boardIsReadOnly(board, archived: false, writable: false), isTrue);
      expect(boardIsReadOnly(board, archived: false), isFalse);
    });
  });
}
