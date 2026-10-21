import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/route_report.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  late FakeEditorBridges bridges;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      copyProject(
        sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
        description: '<p>About <strong>work</strong></p>',
      ),
      sampleProject(id: 2, title: 'Old', identifier: 'OLD', archived: true),
      sampleProject(id: 3, title: 'Below old', identifier: 'BELOW', parent: 2),
    ];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Quarterly report',
        description: '<p>Numbers &amp; charts</p>',
      ),
      sampleTask(id: 2, title: 'Bare task'),
      sampleTask(
        id: 3,
        title: 'Archived task',
        projectId: 3,
        description: '<p>Kept</p>',
      ),
      sampleTask(id: 4, title: 'Bare archived task', projectId: 3),
    ];
    bridges = FakeEditorBridges();
  });

  Future<void> pumpApp(WidgetTester tester, {Size? size}) async {
    usePhoneSurface(tester, logicalSize: size ?? const Size(360, 1800));
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      overrides: [bridges.override],
    );
  }

  Future<void> openSheet(WidgetTester tester, String title) async {
    await pumpApp(tester);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: finder);

  Finder editorSave() => find.descendant(
    of: find.byType(DescriptionEditorPage),
    matching: find.widgetWithText(TextButton, en.taskEditSave),
  );

  Future<void> saveEdit(WidgetTester tester, String html) async {
    bridges.last.edit(html);
    await tester.pump();
    await tester.tap(editorSave());
    await tester.pumpAndSettle();
  }

  group('detail sheet', () {
    testWidgets('the Edit button beside the heading opens the editor over '
        'the sheet, which shows the saved description', (tester) async {
      await openSheet(tester, 'Quarterly report');
      expect(inSheet(find.text(en.taskDetailAddDescription)), findsNothing);

      await tester.tap(inSheet(find.byTooltip(en.taskDetailEditDescription)));
      await tester.pumpAndSettle();
      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(bridges.last.init!.html, '<p>Numbers &amp; charts</p>');

      await saveEdit(tester, '<p>Numbers, charts and a summary</p>');

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(
        inSheet(find.text('Numbers, charts and a summary')),
        findsOneWidget,
      );
      expect(inSheet(find.text(en.descriptionEditorSaved)), findsOneWidget);
      expect(data.tasks.descriptionUpdates, [
        (
          1,
          '<p>Numbers, charts and a summary</p>',
          '<p>Numbers &amp; charts</p>',
        ),
      ]);
    });

    testWidgets('back from the editor the details are read again, so an '
        'image inserted there is listed', (tester) async {
      await openSheet(tester, 'Quarterly report');
      await tester.tap(inSheet(find.byTooltip(en.taskDetailEditDescription)));
      await tester.pumpAndSettle();
      final reads = data.details.calls.length;
      data.details.detailsByTask[1] = TaskDetails(
        attachments: [sampleAttachment(id: 500, name: 'IMG_1.png')],
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(data.details.calls, hasLength(reads + 1));
      expect(inSheet(find.text('IMG_1.png')), findsOneWidget);
    });

    testWidgets('saved after the app was opened again during the editor, '
        'the sheet still says so and reads the details again', (tester) async {
      await openSheet(tester, 'Quarterly report');
      await tester.tap(inSheet(find.byTooltip(en.taskDetailEditDescription)));
      await tester.pumpAndSettle();
      final reads = data.details.calls.length;

      await reportRouteFromPlatform(tester);
      await saveEdit(tester, '<p>Numbers, charts and a summary</p>');

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(inSheet(find.text(en.descriptionEditorSaved)), findsOneWidget);
      expect(data.details.calls, hasLength(reads + 1));
    });

    testWidgets('a task without a description offers "Add description"', (
      tester,
    ) async {
      await openSheet(tester, 'Bare task');
      expect(inSheet(find.text(en.taskDetailNoDescription)), findsNothing);
      expect(
        inSheet(find.byTooltip(en.taskDetailEditDescription)),
        findsNothing,
      );

      await tester.tap(inSheet(find.text(en.taskDetailAddDescription)));
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(bridges.last.init!.html, '');
    });

    testWidgets('closing the editor unchanged says nothing', (tester) async {
      await openSheet(tester, 'Quarterly report');
      await tester.tap(inSheet(find.byTooltip(en.taskDetailEditDescription)));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text(en.descriptionEditorSaved), findsNothing);
      expect(data.tasks.descriptionUpdates, isEmpty);
    });

    testWidgets('a task the sheet shows only from the server, with no row on '
        'this device, offers no editing and no ticking', (tester) async {
      data.tasks.all = [
        ...data.tasks.all,
        sampleTask(
          id: 5,
          title: 'Checklist',
          description: [
            '<ul data-type="taskList"><li data-checked="false" ',
            'data-type="taskItem"><label><input type="checkbox"><span>',
            '</span></label><div><p>Milk</p></div></li></ul>',
          ].join(),
        ),
      ];
      await openSheet(tester, 'Checklist');
      expect(
        inSheet(find.byTooltip(en.taskDetailEditDescription)),
        findsOneWidget,
      );

      data.tasks.all = [
        for (final task in data.tasks.all)
          if (task.id != 5) task,
      ];
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Milk')), findsOneWidget);
      expect(
        inSheet(find.byTooltip(en.taskDetailEditDescription)),
        findsNothing,
      );
      await tester.tap(inSheet(find.byIcon(Icons.check_box_outline_blank)));
      await tester.pumpAndSettle();
      expect(data.tasks.checklistToggles, isEmpty);
    });

    testWidgets('a task below an archived project offers no editing', (
      tester,
    ) async {
      await openSheet(tester, 'Archived task');
      expect(inSheet(find.text('Kept')), findsOneWidget);
      expect(
        inSheet(find.byTooltip(en.taskDetailEditDescription)),
        findsNothing,
      );

      await tester.tap(find.byTooltip(en.taskDetailClose));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bare archived task'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.taskDetailNoDescription)), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailAddDescription)), findsNothing);
    });
  });

  group('task edit page', () {
    Future<void> openEditPage(WidgetTester tester, int taskId) async {
      await pumpApp(tester, size: const Size(360, 2200));
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.taskEdit(taskId)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the Description row shows the text and opens the editor, '
        'which saves on its own', (tester) async {
      await openEditPage(tester, 1);
      expect(find.text(en.taskDetailDescription), findsOneWidget);
      expect(find.text('Numbers & charts'), findsOneWidget);

      await tester.tap(find.text(en.taskDetailDescription));
      await tester.pumpAndSettle();
      expect(bridges.last.init!.html, '<p>Numbers &amp; charts</p>');
      await saveEdit(tester, '<p>Only numbers</p>');

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(find.text('Only numbers'), findsOneWidget);
      expect(find.text(en.descriptionEditorSaved), findsOneWidget);
      expect(data.tasks.descriptionUpdates, hasLength(1));
      expect(data.tasks.updates, isEmpty);
    });

    testWidgets('saved after the app was opened again during the editor, '
        'the page still says so', (tester) async {
      await openEditPage(tester, 1);
      await tester.tap(find.text(en.taskDetailDescription));
      await tester.pumpAndSettle();

      await reportRouteFromPlatform(tester);
      await saveEdit(tester, '<p>Only numbers</p>');

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(find.text(en.descriptionEditorSaved), findsOneWidget);
    });

    testWidgets('without a description the row says so', (tester) async {
      await openEditPage(tester, 2);

      expect(
        find.widgetWithText(ListTile, en.taskDetailNoDescription),
        findsOneWidget,
      );
    });

    testWidgets('below an archived project the row cannot be opened', (
      tester,
    ) async {
      await openEditPage(tester, 3);

      final row = tester.widget<ListTile>(
        find.widgetWithText(ListTile, en.taskDetailDescription),
      );
      expect(row.enabled, isFalse);
    });
  });

  group('project edit page', () {
    testWidgets('the Description row opens the editor for the project', (
      tester,
    ) async {
      await pumpApp(tester);
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.projectEdit(1)),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.projectEditDescription), findsOneWidget);
      expect(find.text('About work'), findsOneWidget);

      await tester.tap(find.text(en.projectEditDescription));
      await tester.pumpAndSettle();
      expect(bridges.last.init!.html, '<p>About <strong>work</strong></p>');
      await saveEdit(tester, '<p>About everything</p>');

      expect(data.projects.updates, [
        (1, const ProjectChanges(description: '<p>About everything</p>')),
      ]);
      expect(find.text('About everything'), findsOneWidget);
      expect(find.text(en.descriptionEditorSaved), findsOneWidget);
    });

    testWidgets('saved after the app was opened again during the editor, '
        'the page still says so', (tester) async {
      await pumpApp(tester);
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.projectEdit(1)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.projectEditDescription));
      await tester.pumpAndSettle();

      await reportRouteFromPlatform(tester);
      await saveEdit(tester, '<p>About everything</p>');

      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(find.text(en.descriptionEditorSaved), findsOneWidget);
    });
  });
}
