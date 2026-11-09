import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../teams/organise_harness.dart';

void main() {
  late OrganiseHarness harness;

  const linkShare = User(id: -5, username: 'link-share-5', name: 'Link Share');
  const tallPhone = Size(400, 1600);

  DateTime ago(Duration duration) => harness.now.subtract(duration).toUtc();

  TrashedTask trashed(
    int id,
    String title, {
    required Duration deleted,
    int projectId = 1,
    User? by = alice,
    bool canDeletePermanently = true,
  }) => TrashedTask(
    task: sampleTask(id: id, title: title, projectId: projectId),
    deletedAt: ago(deleted),
    deletedBy: by,
    canDeletePermanently: canDeletePermanently,
  );

  setUp(() {
    harness = OrganiseHarness();
    harness.data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 2, title: 'Garden'),
    ];
    harness.data.trash
      ..trashedTasks = [
        trashed(41, 'Call the plumber', deleted: const Duration(days: 3)),
        trashed(
          42,
          'Buy seeds',
          projectId: 2,
          deleted: const Duration(days: 29),
          by: kim,
          canDeletePermanently: false,
        ),
        trashed(
          43,
          '  ',
          projectId: 99,
          deleted: const Duration(days: 30),
          by: linkShare,
        ),
        trashed(
          44,
          'Water the roses',
          deleted: const Duration(hours: 5),
          by: null,
        ),
      ]
      ..trashedProjects = [
        TrashedProject(
          project: sampleProject(id: 70, title: 'Archive', hexColor: 'e8445a'),
          deletedAt: ago(const Duration(days: 2)),
          deletedBy: alice,
          subprojects: const [
            TrashedSubproject(
              id: 71,
              title: 'Garden',
              parentProjectId: 70,
              depth: 1,
            ),
            TrashedSubproject(
              id: 72,
              title: 'Tools',
              parentProjectId: 70,
              depth: 1,
            ),
          ],
        ),
      ];
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = tallPhone,
    ServerConnection? connection,
  }) => harness.pump(
    tester,
    location: AppRoutes.trash,
    connection: connection ?? fullServer280(),
    size: size,
  );

  Finder rowOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ListTile));

  Finder inRow(String title, String text) =>
      find.descendant(of: rowOf(title), matching: find.text(text));

  String when(Duration deleted) =>
      formatRelativeTime(en, ago(deleted), now: harness.now);

  Future<void> openProjects(WidgetTester tester, [String? label]) async {
    final tab = find.widgetWithText(Tab, label ?? en.trashProjectsTab);
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  Future<void> tapInDialog(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  IconButton iconButton(WidgetTester tester, String tooltip) =>
      tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );

  Finder emptyBin() => find.widgetWithText(TextButton, en.trashEmpty);

  int reads(String call) =>
      harness.data.trash.calls.where((made) => made == call).length;

  group('the task rows', () {
    testWidgets('show the title, the project this device has, who deleted '
        'it when and the days left', (tester) async {
      await pumpPage(tester);

      expect(find.byType(TrashPage), findsOneWidget);
      expect(harness.data.trash.calls, ['tasks', 'projects']);
      expect(inRow('Call the plumber', 'Work'), findsOneWidget);
      expect(
        inRow(
          'Call the plumber',
          en.trashDeletedByYou(when(const Duration(days: 3))),
        ),
        findsOneWidget,
      );
      expect(
        inRow('Call the plumber', en.trashDeletedForGoodIn(27)),
        findsOneWidget,
      );
      expect(inRow('Buy seeds', 'Garden'), findsOneWidget);
      expect(
        inRow(
          'Buy seeds',
          en.trashDeletedBy(when(const Duration(days: 29)), 'Kim Lee'),
        ),
        findsOneWidget,
      );
      expect(inRow('Buy seeds', en.trashDeletedForGoodIn(1)), findsOneWidget);
      expect(
        inRow('–', en.trashDeletedByLinkShare(when(const Duration(days: 30)))),
        findsOneWidget,
      );
      expect(inRow('–', en.trashDeletedForGoodIn(0)), findsOneWidget);
      expect(
        find.descendant(of: rowOf('–'), matching: find.byType(Text)),
        findsNWidgets(3),
        reason: 'no project line for a project this device does not have',
      );
      expect(
        inRow(
          'Water the roses',
          en.trashDeletedWhen(when(const Duration(hours: 5))),
        ),
        findsOneWidget,
      );
      expect(en.trashDeletedForGoodIn(0), 'Deleted forever today');
      expect(en.trashDeletedForGoodIn(1), 'Deleted forever in 1 day');
      expect(en.trashDeletedForGoodIn(27), 'Deleted forever in 27 days');
    });

    testWidgets('screen readers hear the date of the deletion', (tester) async {
      await pumpPage(tester);

      final shown = en.trashDeletedByYou(when(const Duration(days: 3)));
      final label = tester
          .getSemantics(find.text(shown))
          .getSemanticsData()
          .label;
      expect(label, isNot(shown));
      expect(label, startsWith('Deleted '));
      expect(label, endsWith(' by you'));
      expect(label, contains('${ago(const Duration(days: 3)).year}'));
    });

    testWidgets('offer Delete forever only to the admins of the project', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(
        find.byTooltip(en.trashRestoreItem('Call the plumber')),
        findsOneWidget,
      );
      expect(
        find.byTooltip(en.trashDeleteForeverItem('Call the plumber')),
        findsOneWidget,
      );
      expect(find.byTooltip(en.trashRestoreItem('Buy seeds')), findsOneWidget);
      expect(
        find.byTooltip(en.trashDeleteForeverItem('Buy seeds')),
        findsNothing,
      );
    });
  });

  testWidgets('the list starts right below the tabs under a status bar', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 600);
    addTearDown(tester.view.resetPadding);
    await pumpPage(tester);

    final tabsBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final note = tester.getTopLeft(find.text(en.trashRetentionNote)).dy;
    expect(note - tabsBottom, lessThan(40));
  });

  testWidgets('a project row shows its subprojects, who deleted it when and '
      'the days left, with Restore and Delete forever', (tester) async {
    await pumpPage(tester);
    await openProjects(tester);

    expect(
      inRow('Archive', en.trashSubprojects(2, 'Garden, Tools')),
      findsOneWidget,
    );
    expect(
      inRow('Archive', en.trashDeletedByYou(when(const Duration(days: 2)))),
      findsOneWidget,
    );
    expect(inRow('Archive', en.trashDeletedForGoodIn(28)), findsOneWidget);
    expect(find.byTooltip(en.trashRestoreItem('Archive')), findsOneWidget);
    expect(
      find.byTooltip(en.trashDeleteForeverItem('Archive')),
      findsOneWidget,
    );
  });

  group('restoring', () {
    testWidgets('a task brings it back and says so', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byTooltip(en.trashRestoreItem('Call the plumber')));
      await tester.pumpAndSettle();

      expect(harness.data.tasks.writes, ['restore 41']);
      expect(harness.data.tasks.all.map((task) => task.id), contains(41));
      expect(rowOf('Call the plumber'), findsNothing);
      expect(rowOf('Buy seeds'), findsOneWidget);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.taskRestored),
      ]);
      expect(find.byType(SnackBar), findsNothing);
      expect(reads('tasks'), 1);
    });

    testWidgets('a task that fails says why and stays', (tester) async {
      harness.data.tasks.restoreFailure = const Forbidden();
      await pumpPage(tester);

      await tester.tap(find.byTooltip(en.trashRestoreItem('Call the plumber')));
      await tester.pumpAndSettle();

      expect(find.text(en.trashRestoreTaskForbidden), findsOneWidget);
      expect(rowOf('Call the plumber'), findsOneWidget);
      expect(reads('tasks'), 1);
    });

    testWidgets('a task no longer in the bin says so and reads the bin '
        'again', (tester) async {
      harness.data.tasks.restoreFailure = const NotFound(code: 4002);
      await pumpPage(tester);

      await tester.tap(find.byTooltip(en.trashRestoreItem('Call the plumber')));
      await tester.pumpAndSettle();

      expect(find.text(en.trashTaskGone), findsOneWidget);
      expect(reads('tasks'), 2);
      expect(reads('projects'), 1);
    });

    testWidgets('a task on a server without the bin says so and reads '
        'nothing again', (tester) async {
      harness.data.tasks.restoreFailure = const NotFound();
      await pumpPage(tester);

      await tester.tap(find.byTooltip(en.trashRestoreItem('Call the plumber')));
      await tester.pumpAndSettle();

      expect(find.text(en.trashUnavailable), findsOneWidget);
      expect(rowOf('Call the plumber'), findsOneWidget);
      expect(reads('tasks'), 1);
    });

    testWidgets('a project brings it back, says so and reads the tasks '
        'again', (tester) async {
      await pumpPage(tester);
      await openProjects(tester);

      await tester.tap(find.byTooltip(en.trashRestoreItem('Archive')));
      await tester.pumpAndSettle();

      expect(harness.data.projects.restores, [70]);
      expect(harness.data.projects.all.map((project) => project.id), [
        1,
        2,
        70,
        71,
        72,
      ]);
      expect(rowOf('Archive'), findsNothing);
      expect(find.text(en.trashProjectsEmptyTitle), findsOneWidget);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.projectRestored),
      ]);
      expect(reads('tasks'), 2);
      expect(reads('projects'), 1);
    });

    testWidgets('a project that fails says why', (tester) async {
      harness.data.projects.failures['restoreProject'] = const Forbidden();
      await pumpPage(tester);
      await openProjects(tester);

      await tester.tap(find.byTooltip(en.trashRestoreItem('Archive')));
      await tester.pumpAndSettle();

      expect(find.text(en.trashRestoreProjectAdminOnly), findsOneWidget);
      expect(rowOf('Archive'), findsOneWidget);
      expect(reads('tasks'), 1);
    });
  });

  group('deleting forever', () {
    testWidgets('a task asks first; cancelled, nothing happens', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(
        find.byTooltip(en.trashDeleteForeverItem('Call the plumber')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(en.trashDeleteForeverTitle('Call the plumber')),
        findsOneWidget,
      );
      expect(find.text(en.trashDeleteTaskForeverBody), findsOneWidget);
      await tapInDialog(tester, en.cancel);

      expect(harness.data.trash.calls, ['tasks', 'projects']);
      expect(rowOf('Call the plumber'), findsOneWidget);
    });

    testWidgets('a task, confirmed, is deleted and its row goes', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(
        find.byTooltip(en.trashDeleteForeverItem('Call the plumber')),
      );
      await tester.pumpAndSettle();
      await tapInDialog(tester, en.trashDeleteForever);

      expect(harness.data.trash.calls, [
        'tasks',
        'projects',
        'deleteTaskForever 41',
      ]);
      expect(rowOf('Call the plumber'), findsNothing);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.trashTaskDeletedForever),
      ]);
    });

    testWidgets('a task someone restored meanwhile says so and reads the bin '
        'again', (tester) async {
      harness.data.trash.failures['deleteTaskForever'] = const NotFound(
        code: 4002,
      );
      await pumpPage(tester);

      await tester.tap(
        find.byTooltip(en.trashDeleteForeverItem('Call the plumber')),
      );
      await tester.pumpAndSettle();
      await tapInDialog(tester, en.trashDeleteForever);

      expect(find.text(en.trashTaskGone), findsOneWidget);
      expect(reads('tasks'), 2);
    });

    testWidgets('a project asks first, then is deleted', (tester) async {
      await pumpPage(tester);
      await openProjects(tester);

      await tester.tap(find.byTooltip(en.trashDeleteForeverItem('Archive')));
      await tester.pumpAndSettle();
      expect(find.text(en.trashDeleteForeverTitle('Archive')), findsOneWidget);
      expect(find.text(en.trashDeleteProjectForeverBody), findsOneWidget);
      await tapInDialog(tester, en.cancel);
      expect(harness.data.trash.calls, ['tasks', 'projects']);

      await tester.tap(find.byTooltip(en.trashDeleteForeverItem('Archive')));
      await tester.pumpAndSettle();
      await tapInDialog(tester, en.trashDeleteForever);

      expect(harness.data.trash.calls.last, 'deleteProjectForever 70');
      expect(rowOf('Archive'), findsNothing);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.trashProjectDeletedForever),
      ]);
    });
  });

  group('Empty bin', () {
    String bodyOf(List<String> paragraphs) => paragraphs.join('\n\n');

    testWidgets('says so when there is nothing the user may delete, and '
        'reads the tasks again', (tester) async {
      harness.data.trash.taskCountAnswer = const TrashCount(
        total: 0,
        byOthers: 0,
      );
      await pumpPage(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text(en.trashEmptyNothing), findsOneWidget);
      expect(harness.data.trash.calls, [
        'tasks',
        'projects',
        'taskCount',
        'tasks',
      ]);
    });

    testWidgets('with nothing to delete beside rows the user may delete, the '
        'list was out of date: reads it again and says nothing', (
      tester,
    ) async {
      harness.data.trash.trashedTasks = [
        trashed(41, 'Call the plumber', deleted: const Duration(days: 3)),
      ];
      await pumpPage(tester);
      harness.data.trash.trashedTasks = [];

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text(en.trashEmptyNothing), findsNothing);
      expect(harness.data.trash.calls, [
        'tasks',
        'projects',
        'taskCount',
        'tasks',
      ]);
      expect(rowOf('Call the plumber'), findsNothing);
      expect(
        find.widgetWithText(EmptyState, en.trashTasksEmptyTitle),
        findsOneWidget,
      );
    });

    testWidgets('with no project to delete, reads the projects again and '
        'says nothing', (tester) async {
      await pumpPage(tester);
      harness.data.trash.trashedProjects = [];
      await openProjects(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text(en.trashEmptyNothing), findsNothing);
      expect(harness.data.trash.calls, [
        'tasks',
        'projects',
        'projectCount',
        'projects',
      ]);
      expect(rowOf('Archive'), findsNothing);
      expect(
        find.widgetWithText(EmptyState, en.trashProjectsEmptyTitle),
        findsOneWidget,
      );
    });

    testWidgets('asks with how many go, those of others and those that '
        'stay, then empties and reads the tasks again', (tester) async {
      harness.data.trash.taskCountAnswer = const TrashCount(
        total: 3,
        byOthers: 1,
      );
      await pumpPage(tester);
      expect(find.text(en.trashRetentionNote), findsOneWidget);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();
      expect(find.text(en.trashEmptyTasksTitle), findsOneWidget);
      expect(
        find.text(
          bodyOf([
            en.trashEmptyTasks(3),
            en.trashEmptyByOthers(1),
            en.trashEmptyKeepsOthers,
            en.trashCannotBeUndone,
          ]),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.trashEmpty),
        ),
        findsNothing,
      );
      await tapInDialog(tester, en.trashDeleteForever);

      expect(harness.data.trash.calls, [
        'tasks',
        'projects',
        'taskCount',
        'emptyTasks',
        'tasks',
      ]);
      expect(rowOf('Call the plumber'), findsNothing);
      expect(rowOf('Buy seeds'), findsOneWidget);
      expect(emptyBin(), findsOneWidget);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.trashEmptied),
      ]);
    });

    testWidgets('cancelled, deletes nothing', (tester) async {
      harness.data.trash.trashedTasks = [
        for (final item in harness.data.trash.trashedTasks)
          if (item.canDeletePermanently) item,
      ];
      await pumpPage(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();
      expect(
        find.text(bodyOf([en.trashEmptyTasks(3), en.trashCannotBeUndone])),
        findsOneWidget,
        reason: 'all that are listed go, none of them by others',
      );
      await tapInDialog(tester, en.cancel);

      expect(harness.data.trash.calls, ['tasks', 'projects', 'taskCount']);
      expect(rowOf('Call the plumber'), findsOneWidget);
    });

    testWidgets('says that tasks stay by the rows the user may not delete, '
        'not by the count', (tester) async {
      harness.data.trash.trashedTasks = [
        for (final item in harness.data.trash.trashedTasks)
          if (item.canDeletePermanently) item,
      ];
      harness.data.trash.taskCountAnswer = const TrashCount(
        total: 2,
        byOthers: 0,
      );
      await pumpPage(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();
      expect(
        find.text(bodyOf([en.trashEmptyTasks(2), en.trashCannotBeUndone])),
        findsOneWidget,
        reason: 'every listed task may be deleted; one went meanwhile',
      );
      await tapInDialog(tester, en.cancel);

      harness.data.trash
        ..trashedTasks = [
          ...harness.data.trash.trashedTasks,
          trashed(
            42,
            'Buy seeds',
            projectId: 2,
            deleted: const Duration(days: 29),
            by: kim,
            canDeletePermanently: false,
          ),
        ]
        ..taskCountAnswer = const TrashCount(total: 6, byOthers: 0);
      await tester.tap(find.byTooltip(en.refresh));
      await tester.pumpAndSettle();
      await tester.tap(emptyBin());
      await tester.pumpAndSettle();
      expect(
        find.text(
          bodyOf([
            en.trashEmptyTasks(6),
            en.trashEmptyKeepsOthers,
            en.trashCannotBeUndone,
          ]),
        ),
        findsOneWidget,
        reason: 'more were deleted meanwhile, but "Buy seeds" stays',
      );
    });

    testWidgets('the projects asks, then empties them', (tester) async {
      harness.data.trash.projectCountAnswer = const TrashCount(
        total: 1,
        byOthers: 1,
      );
      await pumpPage(tester);
      await openProjects(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();
      expect(find.text(en.trashEmptyProjectsTitle), findsOneWidget);
      expect(
        find.text(
          bodyOf([
            en.trashEmptyProjects(1),
            en.trashEmptyByOthers(1),
            en.trashCannotBeUndone,
          ]),
        ),
        findsOneWidget,
      );
      await tapInDialog(tester, en.trashDeleteForever);

      expect(harness.data.trash.calls, [
        'tasks',
        'projects',
        'projectCount',
        'emptyProjects',
        'projects',
      ]);
      expect(find.text(en.trashProjectsEmptyTitle), findsOneWidget);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.trashEmptied),
      ]);
    });

    testWidgets('on a server without the bin says so', (tester) async {
      harness.data.trash.failures['taskCount'] = const NotFound();
      await pumpPage(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text(en.trashUnavailable), findsOneWidget);
      expect(reads('tasks'), 1);
    });

    testWidgets('a count that fails says why and reads nothing again', (
      tester,
    ) async {
      harness.data.trash.failures['taskCount'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpPage(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text(en.trashNeedsConnection), findsOneWidget);
      expect(reads('tasks'), 1);
    });

    testWidgets('an empty that fails says why, keeps the list and reads it '
        'again', (tester) async {
      harness.data.trash.failures['emptyTasks'] = const ServerFailure(500);
      await pumpPage(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();
      await tapInDialog(tester, en.trashDeleteForever);

      expect(
        find.text(
          trashFailureText(en, const ServerFailure(500), TrashAction.empty),
        ),
        findsOneWidget,
      );
      expect(rowOf('Call the plumber'), findsOneWidget);
      expect(reads('tasks'), 2);
    });

    testWidgets('an empty whose answer was lost reads the tasks again, which '
        'shows what the server deleted', (tester) async {
      const timeout = NetworkFailure(NetworkProblem.timeout);
      harness.data.trash
        ..failures['emptyTasks'] = timeout
        ..beforeCall = (call) async {
          if (call == 'emptyTasks') {
            harness.data.trash.trashedTasks = [
              for (final item in harness.data.trash.trashedTasks)
                if (!item.canDeletePermanently) item,
            ];
          }
        };
      await pumpPage(tester);

      await tester.tap(emptyBin());
      await tester.pumpAndSettle();
      await tapInDialog(tester, en.trashDeleteForever);

      expect(
        find.text(trashFailureText(en, timeout, TrashAction.empty)),
        findsOneWidget,
      );
      expect(reads('tasks'), 2);
      expect(rowOf('Call the plumber'), findsNothing);
      expect(rowOf('Buy seeds'), findsOneWidget);
    });
  });

  testWidgets('one action at a time: the others are off while one is on its '
      'way, which shows in its row', (tester) async {
    final restore = Completer<void>();
    harness.data.tasks.beforeRestore = (_) => restore.future;
    await pumpPage(tester);

    await tester.tap(find.byTooltip(en.trashRestoreItem('Call the plumber')));
    await tester.pump();

    final working = find.byWidgetPredicate(
      (widget) =>
          widget is CircularProgressIndicator &&
          widget.semanticsLabel == en.trashWorking,
    );
    expect(
      find.descendant(of: rowOf('Call the plumber'), matching: working),
      findsOneWidget,
    );
    expect(
      find.byTooltip(en.trashRestoreItem('Call the plumber')),
      findsNothing,
    );
    expect(
      iconButton(tester, en.trashRestoreItem('Buy seeds')).onPressed,
      null,
    );
    expect(
      iconButton(tester, en.trashDeleteForeverItem('–')).onPressed,
      isNull,
    );
    expect(tester.widget<TextButton>(emptyBin()).onPressed, isNull);
    await tester.tap(find.byTooltip(en.trashRestoreItem('Buy seeds')));
    await tester.pump();
    expect(harness.data.tasks.writes, ['restore 41']);

    restore.complete();
    await tester.pumpAndSettle();
    expect(working, findsNothing);
    expect(
      iconButton(tester, en.trashRestoreItem('Buy seeds')).onPressed,
      isNotNull,
    );
    expect(tester.widget<TextButton>(emptyBin()).onPressed, isNotNull);
  });

  testWidgets('a read still on its way when a restore finishes does not '
      'bring the row back', (tester) async {
    await pumpPage(tester);
    final before = harness.data.trash.trashedTasks;
    final held = Completer<void>();
    harness.data.trash.beforeCall = (call) async {
      if (call == 'tasks' && reads('tasks') == 2) await held.future;
    };

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pump();
    await tester.tap(find.byTooltip(en.trashRestoreItem('Call the plumber')));
    await tester.pumpAndSettle();
    expect(rowOf('Call the plumber'), findsNothing);

    harness.data.trash.trashedTasks = before;
    held.complete();
    await tester.pumpAndSettle();

    expect(rowOf('Call the plumber'), findsNothing);
    expect(rowOf('Buy seeds'), findsOneWidget);
    expect(reads('tasks'), 3);
  });

  group('states', () {
    testWidgets('loading says so', (tester) async {
      final read = Completer<void>();
      harness.data.trash.beforeCall = (call) async {
        if (call == 'tasks') await read.future;
      };
      await harness.pump(tester, connection: fullServer280(), size: tallPhone);

      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.trash),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.widgetWithText(LoadingPlaceholder, en.trashLoading),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip(en.refresh),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );

      read.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoadingPlaceholder), findsNothing);
      expect(rowOf('Call the plumber'), findsOneWidget);
    });

    testWidgets('a first read that fails offers to try again', (tester) async {
      harness.data.trash.failures['tasks'] = const ServerFailure(502);
      await pumpPage(tester);

      expect(
        tester.widget<DataFailureCard>(find.byType(DataFailureCard)).stale,
        isFalse,
      );
      harness.data.trash.failures.remove('tasks');
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(find.byType(DataFailureCard), findsNothing);
      expect(rowOf('Call the plumber'), findsOneWidget);
    });

    testWidgets('a server without the bin says so on both tabs, not that '
        'something is gone', (tester) async {
      harness.data.trash.failures
        ..['tasks'] = const NotFound()
        ..['projects'] = const NotFound();
      await pumpPage(tester, connection: fullServer270());

      expect(find.text(en.dataFailureLoadTitle), findsOneWidget);
      expect(find.text(en.trashUnavailable), findsOneWidget);
      expect(find.byType(DataFailureCard), findsNothing);
      await openProjects(tester);
      expect(find.text(en.trashUnavailable), findsOneWidget);
      expect(find.byType(DataFailureCard), findsNothing);
    });

    testWidgets('a bare 404 on a server with the bin keeps the retry', (
      tester,
    ) async {
      harness.data.trash.failures['tasks'] = const NotFound();
      await pumpPage(tester);

      expect(find.text(en.trashUnavailable), findsNothing);
      expect(find.byType(DataFailureCard), findsOneWidget);
      harness.data.trash.failures.remove('tasks');
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(rowOf('Call the plumber'), findsOneWidget);
    });

    testWidgets('a read that fails over a list keeps it under a notice', (
      tester,
    ) async {
      await pumpPage(tester);
      harness.data.trash.failures['tasks'] = const ServerFailure(502);

      await tester.tap(find.byTooltip(en.refresh));
      await tester.pumpAndSettle();

      expect(
        tester.widget<DataFailureCard>(find.byType(DataFailureCard)).stale,
        isTrue,
      );
      expect(rowOf('Call the plumber'), findsOneWidget);
    });

    testWidgets('offline it says so, and reads again once the server is '
        'reached', (tester) async {
      harness.data.trash.failures['tasks'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpPage(tester);
      harness.goOffline();
      await tester.pumpAndSettle();

      expect(find.byType(OfflineNotice), findsOneWidget);
      expect(find.byType(DataFailureCard), findsNothing);

      harness.data.trash.failures.remove('tasks');
      harness.data.engine.emit(SyncIdle(lastSyncedAt: harness.now));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineNotice), findsNothing);
      expect(rowOf('Call the plumber'), findsOneWidget);
      expect(reads('projects'), 1);
    });

    testWidgets('an empty bin says so on each tab', (tester) async {
      harness.data.trash
        ..trashedTasks = []
        ..trashedProjects = [];
      await pumpPage(tester);

      expect(
        find.widgetWithText(EmptyState, en.trashTasksEmptyTitle),
        findsOneWidget,
      );
      expect(find.text(en.trashTasksEmptyBody), findsOneWidget);
      expect(emptyBin(), findsNothing);
      await openProjects(tester);
      expect(
        find.widgetWithText(EmptyState, en.trashProjectsEmptyTitle),
        findsOneWidget,
      );
      expect(find.text(en.trashProjectsEmptyBody), findsOneWidget);
      expect(emptyBin(), findsNothing);
    });
  });

  group('reading again', () {
    testWidgets('the refresh button reads both tabs', (tester) async {
      await pumpPage(tester);
      harness.data.trash.trashedTasks = [
        trashed(45, 'Fix the fence', deleted: const Duration(minutes: 5)),
      ];

      await tester.tap(find.byTooltip(en.refresh));
      await tester.pumpAndSettle();

      expect(harness.data.trash.calls, [
        'tasks',
        'projects',
        'tasks',
        'projects',
      ]);
      expect(rowOf('Fix the fence'), findsOneWidget);
      expect(rowOf('Call the plumber'), findsNothing);
    });

    testWidgets('pulling down on either tab reads both', (tester) async {
      await pumpPage(tester);
      Finder list() => find.descendant(
        of: find.byType(TrashPage),
        matching: find.byType(CustomScrollView),
      );

      await pullToRefresh(tester, list());
      expect(reads('tasks'), 2);
      expect(reads('projects'), 2);

      await openProjects(tester);
      await pullToRefresh(tester, list());
      expect(reads('tasks'), 3);
      expect(reads('projects'), 3);
    });
  });

  testWidgets('German, at 200 % text on a small phone', (tester) async {
    final de = lookupAppLocalizations(const Locale('de'));
    useLocale(tester, const Locale('de'));
    useAccessibilityExtremes(tester);
    await pumpPage(tester, size: const Size(320, 640));

    expect(find.text(de.trashTitle), findsOneWidget);
    expect(find.text(de.trashTasksTab), findsOneWidget);
    expect(find.text(de.trashProjectsTab), findsOneWidget);
    expect(find.text(de.trashRetentionNote), findsOneWidget);
    expect(
      find.text(
        de.trashDeletedByYou(
          formatRelativeTime(
            de,
            ago(const Duration(days: 3)),
            now: harness.now,
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(de.trashDeletedForGoodIn(27)), findsOneWidget);
    expect(
      find.byTooltip(de.trashRestoreItem('Call the plumber')),
      findsOneWidget,
    );

    await openProjects(tester, de.trashProjectsTab);
    expect(find.text(de.trashSubprojects(2, 'Garden, Tools')), findsOneWidget);
    expect(find.text(de.trashEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 200 % text on a small phone the buttons go below the '
      'lines, and the titles keep the width of the row', (tester) async {
    final de = lookupAppLocalizations(const Locale('de'));
    useLocale(tester, const Locale('de'));
    useAccessibilityExtremes(tester);
    await pumpPage(tester, size: const Size(320, 640));

    Future<void> expectBelow(String title, String restore, String last) async {
      final button = find.byTooltip(restore, skipOffstage: false);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.text(title)).width,
        greaterThanOrEqualTo(200),
        reason: 'the title of "$title" keeps the width of the row',
      );
      expect(
        tester.getTopLeft(button).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text(last)).dy),
        reason: 'the buttons of "$title" are below its lines',
      );
    }

    await expectBelow(
      'Call the plumber',
      de.trashRestoreItem('Call the plumber'),
      de.trashDeletedForGoodIn(27),
    );
    await tester.drag(
      find.descendant(
        of: find.byType(TrashPage),
        matching: find.byType(CustomScrollView),
      ),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    await openProjects(tester, de.trashProjectsTab);
    await expectBelow(
      'Archive',
      de.trashRestoreItem('Archive'),
      de.trashDeletedForGoodIn(28),
    );
    expect(tester.takeException(), isNull);
  });
}
