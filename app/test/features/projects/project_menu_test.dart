import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/duplicate_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/new_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_edit_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_views_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', position: 1),
      sampleProject(id: 3, title: 'Reports', parent: 1),
      sampleProject(id: 4, title: 'Q1', parent: 3),
      sampleProject(id: 2, title: 'Home', position: 2),
      sampleProject(id: 5, title: 'Old', archived: true, position: 3),
      sampleProject(id: 6, title: 'Old child', parent: 5, archived: true),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Plan'),
      sampleTask(id: 2, title: 'Shipped', done: true),
      sampleTask(id: 3, title: 'Numbers', projectId: 3),
      sampleTask(id: 4, title: 'Slides', projectId: 4),
      sampleTask(id: 5, title: 'Groceries', projectId: 2),
    ];
  });

  Future<void> pumpProject(WidgetTester tester, int projectId) async {
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

  Future<void> choose(WidgetTester tester, String item) async {
    await openMenu(tester);
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  /// The labels in [labels] that the open menu shows, top to bottom.
  List<String> shownInOrder(WidgetTester tester, List<String> labels) {
    final shown = [
      for (final label in labels)
        if (find.text(label).evaluate().isNotEmpty) label,
    ];
    return shown..sort(
      (a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy),
    );
  }

  PopupMenuItem<Object?> itemWith(WidgetTester tester, String label) =>
      tester.widget<PopupMenuItem<Object?>>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        ),
      );

  final allItems = [
    en.refresh,
    en.projectEdit,
    en.projectViews,
    en.projectDuplicate,
    en.projectArchive,
    en.projectUnarchive,
    en.followProject,
    en.projectNewSubproject,
    en.projectAddToFavourites,
    en.projectRemoveFromFavourites,
    en.projectDelete,
  ];

  group('the menu', () {
    testWidgets("offers the web's actions in groups, after Refresh", (
      tester,
    ) async {
      await pumpProject(tester, 1);
      await openMenu(tester);

      expect(shownInOrder(tester, allItems), [
        en.refresh,
        en.projectEdit,
        en.projectViews,
        en.projectAddToFavourites,
        en.followProject,
        en.projectNewSubproject,
        en.projectDuplicate,
        en.projectArchive,
        en.projectDelete,
      ]);
      final dividers = [
        for (final divider in find.byType(PopupMenuDivider).evaluate())
          tester.getTopLeft(find.byWidget(divider.widget)).dy,
      ];
      double top(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(dividers, hasLength(3));
      expect(
        dividers[0],
        inExclusiveRange(top(en.refresh), top(en.projectEdit)),
      );
      expect(
        dividers[1],
        inExclusiveRange(top(en.followProject), top(en.projectNewSubproject)),
      );
      expect(
        dividers[2],
        inExclusiveRange(top(en.projectDuplicate), top(en.projectArchive)),
      );
    });

    testWidgets('of an archived project only unarchives it, and follows', (
      tester,
    ) async {
      await pumpProject(tester, 6);
      await openMenu(tester);

      expect(shownInOrder(tester, allItems), [
        en.refresh,
        en.projectUnarchive,
        en.followProject,
      ]);
    });

    testWidgets('of the default project cannot archive it, says why and '
        'offers no Delete', (tester) async {
      data.shared.settings = const UserSettings(defaultProjectId: 1);
      await pumpProject(tester, 1);
      await openMenu(tester);

      expect(itemWith(tester, en.projectArchive).enabled, isFalse);
      expect(find.text(en.projectArchiveDefaultHint), findsOneWidget);
      expect(find.text(en.projectDelete), findsNothing);
      await tester.tap(find.text(en.projectArchive), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(data.projects.calls, isEmpty);
    });

    testWidgets('Edit and Views open their pages', (tester) async {
      await pumpProject(tester, 1);

      await choose(tester, en.projectEdit);
      expect(find.byType(ProjectEditPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await choose(tester, en.projectViews);
      expect(find.byType(ProjectViewsPage), findsOneWidget);
    });
  });

  testWidgets('Add to favourites stars it, and the menu then removes it', (
    tester,
  ) async {
    await pumpProject(tester, 1);

    await choose(tester, en.projectAddToFavourites);
    expect(data.projects.updates, [
      (1, const ProjectChanges(isFavorite: true)),
    ]);
    expect(find.text(en.projectFavourited), findsOneWidget);

    await choose(tester, en.projectRemoveFromFavourites);
    expect(data.projects.updates.last, (
      1,
      const ProjectChanges(isFavorite: false),
    ));
    expect(find.text(en.projectUnfavourited), findsOneWidget);
  });

  testWidgets('the star in the app bar does what the menu does', (
    tester,
  ) async {
    await pumpProject(tester, 1);
    // The task rows' stars share the English tooltips.
    final starButton = find.descendant(
      of: find.byType(AppBar),
      matching: find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.isSelected != null,
      ),
    );
    IconButton star() => tester.widget<IconButton>(starButton);
    expect(star().isSelected, isFalse);
    expect(star().tooltip, en.projectAddToFavourites);

    await tester.tap(starButton);
    await tester.pumpAndSettle();
    expect(data.projects.updates, [
      (1, const ProjectChanges(isFavorite: true)),
    ]);
    expect(find.text(en.projectFavourited), findsOneWidget);
    expect(star().isSelected, isTrue);
    expect(star().tooltip, en.projectRemoveFromFavourites);

    await tester.tap(starButton);
    await tester.pumpAndSettle();
    expect(data.projects.updates.last, (
      1,
      const ProjectChanges(isFavorite: false),
    ));
    expect(star().isSelected, isFalse);
  });

  testWidgets('an archived project shows no star to change', (tester) async {
    await pumpProject(tester, 5);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip(en.projectAddToFavourites),
      ),
      findsNothing,
    );
  });

  testWidgets('a change refused for a stored title over the limit asks to '
      'shorten it', (tester) async {
    data.projects.all = [
      ...data.projects.all,
      sampleProject(id: 7, title: '${'a' * 245} - duplicate', position: 4),
    ];
    data.projects.failures['updateProject'] = const ValidationFailed(
      code: 2002,
    );
    await pumpProject(tester, 7);

    await choose(tester, en.projectAddToFavourites);

    expect(find.text(en.projectTitleTooLongToChange), findsOneWidget);
  });

  testWidgets('offline a change says it needs a connection', (tester) async {
    data.projects.failure = const NetworkFailure(NetworkProblem.unreachable);
    await pumpProject(tester, 1);

    await choose(tester, en.projectAddToFavourites);

    expect(find.text(en.projectChangeNeedsConnection), findsOneWidget);
    await openMenu(tester);
    expect(find.text(en.projectAddToFavourites), findsOneWidget);
  });

  testWidgets('while a change is on its way the menu waits', (tester) async {
    final answer = Completer<void>();
    data.projects.beforeCall = (_) => answer.future;
    await pumpProject(tester, 1);

    await openMenu(tester);
    await tester.tap(find.text(en.projectAddToFavourites));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byTooltip(en.moreActions), findsNothing);
    expect(find.bySemanticsLabel(en.projectSaving), findsOneWidget);
    answer.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip(en.moreActions), findsOneWidget);
  });

  group('archive', () {
    testWidgets('asks first, then archives the project and its subprojects', (
      tester,
    ) async {
      await pumpProject(tester, 1);

      await choose(tester, en.projectArchive);
      expect(find.text(en.projectArchiveTitle), findsOneWidget);
      expect(find.text(en.projectArchiveBody), findsOneWidget);
      await tester.tap(find.text(en.projectArchive).last);
      await tester.pumpAndSettle();

      expect(data.projects.updates, [
        (1, const ProjectChanges(isArchived: true)),
      ]);
      expect(
        [
          for (final id in [1, 3, 4]) data.projects.find(id)!.isArchived,
        ],
        [true, true, true],
      );
      expect(find.text(en.projectArchivedDone), findsOneWidget);
      expect(find.text(en.projectArchivedNote), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await openMenu(tester);
      expect(shownInOrder(tester, allItems), [
        en.refresh,
        en.projectUnarchive,
        en.followProject,
      ]);
    });

    testWidgets('cancelled changes nothing', (tester) async {
      await pumpProject(tester, 1);

      await choose(tester, en.projectArchive);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(data.projects.calls, isEmpty);
    });

    testWidgets('under an archived parent Unarchive is disabled and says to '
        'unarchive the parent first, without asking', (tester) async {
      await pumpProject(tester, 6);
      await openMenu(tester);

      expect(itemWith(tester, en.projectUnarchive).enabled, isFalse);
      expect(find.text(en.projectUnarchiveParentFirst), findsOneWidget);
      await tester.tap(find.text(en.projectUnarchive), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(en.projectUnarchiveTitle), findsNothing);
      expect(data.projects.calls, isEmpty);
    });

    testWidgets('names the default project when it is below and archived '
        'along', (tester) async {
      data.shared.settings = const UserSettings(defaultProjectId: 4);
      await pumpProject(tester, 1);

      await choose(tester, en.projectArchive);

      expect(
        find.text(
          '${en.projectArchiveBody}\n\n${en.projectIncludesDefault('Q1')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('unarchiving the parent brings back the project with its '
        'subprojects', (tester) async {
      await pumpProject(tester, 5);

      await choose(tester, en.projectUnarchive);
      await tester.tap(find.text(en.projectUnarchive).last);
      await tester.pumpAndSettle();

      expect(data.projects.find(5)!.isArchived, isFalse);
      expect(data.projects.find(6)!.isArchived, isFalse);
      expect(find.text(en.projectUnarchivedDone), findsOneWidget);
      expect(find.text(en.projectArchivedNote), findsNothing);
    });
  });

  group('delete', () {
    testWidgets('names the project, counts every task and subproject below '
        'it, then leaves for the Projects tab', (tester) async {
      await pumpProject(tester, 1);

      await choose(tester, en.projectDelete);
      expect(find.text(en.projectDeleteTitle('Work')), findsOneWidget);
      expect(
        find.text(
          '${en.projectDeleteTasksAndSubprojects(4, 2)}\n\n'
          '${en.projectDeleteCannotBeUndone}',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(en.projectDelete).last);
      await tester.pumpAndSettle();

      expect(data.projects.deletes, [1]);
      expect(find.byType(ProjectTasksScreen), findsNothing);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(find.text(en.projectDeleted), findsOneWidget);
      expect(find.text('Work'), findsNothing);
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('names the default project when it is below and deleted '
        'along', (tester) async {
      data.shared.settings = const UserSettings(defaultProjectId: 4);
      await pumpProject(tester, 1);

      await choose(tester, en.projectDelete);

      expect(
        find.text(
          '${en.projectDeleteTasksAndSubprojects(4, 2)}\n\n'
          "${en.projectIncludesDefault('Q1')}\n\n"
          '${en.projectDeleteCannotBeUndone}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('of subprojects without tasks says so in words', (
      tester,
    ) async {
      data.tasks.all = [];
      await pumpProject(tester, 1);

      await choose(tester, en.projectDelete);

      expect(
        find.text(
          'This deletes no tasks and 2 subprojects, for everyone.\n\n'
          '${en.projectDeleteCannotBeUndone}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('of a project without subprojects counts its tasks', (
      tester,
    ) async {
      await pumpProject(tester, 2);

      await choose(tester, en.projectDelete);

      expect(
        find.text(
          '${en.projectDeleteTasks(1)}\n\n${en.projectDeleteCannotBeUndone}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancelled deletes nothing', (tester) async {
      await pumpProject(tester, 2);

      await choose(tester, en.projectDelete);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(data.projects.calls, isEmpty);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    testWidgets('refused, it says why and the project stays', (tester) async {
      data.projects.failures['deleteProject'] = const Forbidden();
      await pumpProject(tester, 2);

      await choose(tester, en.projectDelete);
      await tester.tap(find.text(en.projectDelete).last);
      await tester.pumpAndSettle();

      expect(find.text(en.projectDeleteAdminOnly), findsOneWidget);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
    });
  });

  testWidgets('a project deleted elsewhere while open says it is gone', (
    tester,
  ) async {
    await pumpProject(tester, 2);

    data.projects.all = [
      for (final project in data.projects.all)
        if (project.id != 2) project,
    ];
    await tester.pumpAndSettle();

    expect(find.text(en.projectGoneTitle), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('New subproject creates one under this project and opens it', (
    tester,
  ) async {
    await pumpProject(tester, 1);

    await choose(tester, en.projectNewSubproject);
    expect(find.byType(NewProjectSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NewProjectSheet),
        matching: find.text('Work'),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(NewProjectSheet),
        matching: find.byType(TextField),
      ),
      'Launch',
    );
    await tester.pump();
    await tester.tap(find.text(en.projectCreate));
    await tester.pumpAndSettle();

    expect(data.projects.creates.single.parentProjectId, 1);
    expect(find.widgetWithText(AppBar, 'Launch'), findsOneWidget);
  });

  group('duplicate', () {
    testWidgets("asks for the parent, the source's by default, and copies the "
        'shares unless told not to, then opens the copy', (tester) async {
      await pumpProject(tester, 3);

      await choose(tester, en.projectDuplicate);
      expect(find.byType(DuplicateProjectSheet), findsOneWidget);
      expect(find.text(en.projectDuplicateBody), findsOneWidget);
      expect(find.text(en.projectDuplicateSharesHint), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DuplicateProjectSheet),
          matching: find.text('Work'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(en.projectDuplicate));
      await tester.pumpAndSettle();

      expect(data.projects.duplicates, [
        (projectId: 3, parentProjectId: 1, copyShares: true),
      ]);
      expect(
        find.widgetWithText(AppBar, 'Reports - duplicate'),
        findsOneWidget,
      );
      expect(find.text(en.projectDuplicated), findsOneWidget);
      expect(find.text('Numbers'), findsOneWidget);
    });

    testWidgets('to the top level without the shares', (tester) async {
      await pumpProject(tester, 3);

      await choose(tester, en.projectDuplicate);
      await tester.tap(find.text(en.projectParentLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.projectParentTopLevel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.projectDuplicateShares));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.projectDuplicate));
      await tester.pumpAndSettle();

      expect(data.projects.duplicates, [
        (projectId: 3, parentProjectId: 0, copyShares: false),
      ]);
    });

    testWidgets('while it runs the sheet shows progress; a refusal stays in '
        'it with the reason', (tester) async {
      final answer = Completer<void>();
      data.projects.beforeCall = (_) => answer.future;
      data.projects.failures['duplicateProject'] = const DomainError(
        412,
        code: 3008,
      );
      await pumpProject(tester, 3);

      await choose(tester, en.projectDuplicate);
      await tester.tap(find.text(en.projectDuplicate));
      await tester.pump();
      expect(find.text(en.projectDuplicating), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DuplicateProjectSheet),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );

      answer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DuplicateProjectSheet), findsOneWidget);
      expect(find.text(en.projectParentArchived), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
    });
  });

  group('duplicate dragged shut while it runs', () {
    testWidgets('still opens the copy', (tester) async {
      final answer = Completer<void>();
      data.projects.beforeCall = (_) => answer.future;
      await pumpProject(tester, 3);

      await choose(tester, en.projectDuplicate);
      await tester.tap(find.text(en.projectDuplicate));
      await tester.pump();
      await tester.fling(
        find.text(en.projectDuplicateTitle),
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(DuplicateProjectSheet), findsNothing);

      answer.complete();
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, 'Reports - duplicate'),
        findsOneWidget,
      );
      expect(find.text(en.projectDuplicated), findsOneWidget);
    });

    testWidgets('says why when the server refuses', (tester) async {
      final answer = Completer<void>();
      data.projects.beforeCall = (_) => answer.future;
      data.projects.failures['duplicateProject'] = const DomainError(
        412,
        code: 3008,
      );
      await pumpProject(tester, 3);

      await choose(tester, en.projectDuplicate);
      await tester.tap(find.text(en.projectDuplicate));
      await tester.pump();
      await tester.fling(
        find.text(en.projectDuplicateTitle),
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();

      answer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DuplicateProjectSheet), findsNothing);
      expect(find.text(en.projectParentArchived), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
    });
  });

  testWidgets('on iOS the questions are Cupertino alerts and the sheets '
      'Cupertino sheets', (tester) async {
    await pumpProject(tester, 2);

    await choose(tester, en.projectDelete);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final confirm = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, en.projectDelete),
    );
    expect(confirm.isDestructiveAction, isTrue);
    await tester.tap(find.text(en.cancel));
    await tester.pumpAndSettle();

    await choose(tester, en.projectDuplicate);
    expect(
      find.widgetWithText(CupertinoButton, en.projectDuplicate),
      findsOneWidget,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
