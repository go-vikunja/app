import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../teams/organise_harness.dart';

void main() {
  late OrganiseHarness harness;

  setUp(() => harness = OrganiseHarness());

  group("the task sheet's label pills", () {
    final finance = ownLabel(1, 'Finance', hexColor: 'ffeb10');

    setUp(() {
      harness.data.projects.all = [sampleProject(id: 1, title: 'Work')];
      harness.data.tasks.all = [
        sampleTask(
          id: 1,
          title: 'Quarterly report',
          due: harness.now,
          labels: [finance],
        ),
      ];
      harness.labels = FakeLabelRepository(labels: [finance]);
    });

    testWidgets("open the label's tasks over the sheet, which going back "
        'brings back', (tester) async {
      await harness.pump(tester, size: const Size(360, 1800));
      await tester.tap(find.text('Quarterly report'));
      await tester.pumpAndSettle();

      final pill = find.bySemanticsLabel(en.labelsShowTasks('Finance'));
      expect(pill, findsOneWidget);
      await tester.tap(pill);
      await tester.pumpAndSettle();

      expect(find.byType(LabelTasksScreen), findsOneWidget);
      expect(currentLocation(tester), AppRoutes.labelTasks(1));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });

    testWidgets('keep a tap target of the minimum size', (tester) async {
      await harness.pump(tester, size: const Size(360, 1800));
      await tester.tap(find.text('Quarterly report'));
      await tester.pumpAndSettle();

      final pill = find.bySemanticsLabel(en.labelsShowTasks('Finance'));
      expect(
        tester.getSize(pill).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
    });
  });

  group("a label's description", () {
    late FakeEditorBridges bridges;

    setUp(() {
      bridges = FakeEditorBridges();
      harness.labels = FakeLabelRepository(
        labels: [ownLabel(1, 'Urgent', html: '<p>Old</p>')],
      );
    });

    Future<List<Object?>> openEditor(WidgetTester tester) async {
      await harness.pump(
        tester,
        location: AppRoutes.labelEdit(1),
        overrides: [bridges.override],
      );
      final popped = <Object?>[];
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push<Object>(AppRoutes.labelDescription(1))
            .then(popped.add),
      );
      await tester.pumpAndSettle();
      return popped;
    }

    Finder saveButton() => find.widgetWithText(TextButton, en.taskEditSave);

    testWidgets('is saved online with the label and the page closes', (
      tester,
    ) async {
      final popped = await openEditor(tester);
      expect(bridges.last.init!.html, '<p>Old</p>');

      bridges.last.edit('<p>New</p>');
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(harness.labels.updates, [
        (1, const LabelChanges(description: '<p>New</p>')),
      ]);
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(popped, [true]);
      expect(find.textContaining('New'), findsOneWidget);
    });

    testWidgets('is not compared with a change that synced meanwhile', (
      tester,
    ) async {
      await openEditor(tester);
      bridges.last.edit('<p>Mine</p>');
      await tester.pump();
      await harness.labels.update(
        1,
        const LabelChanges(description: '<p>From the web</p>'),
      );
      harness.labels.updates.clear();
      await tester.pumpAndSettle();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.text(en.descriptionEditorChangedTitle), findsNothing);
      expect(harness.labels.updates, [
        (1, const LabelChanges(description: '<p>Mine</p>')),
      ]);
    });

    testWidgets('a refusal stays in the editor and says why', (tester) async {
      harness.labels.changeFailure = const Forbidden();
      await openEditor(tester);
      bridges.last.edit('<p>New</p>');
      await tester.pump();

      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(find.text(en.labelsNotCreator), findsOneWidget);
    });

    testWidgets('suggests the people this device knows for a mention', (
      tester,
    ) async {
      harness.data.shared.users.everyone = const [];
      await openEditor(tester);
      // The device knows Kim from a search.
      harness.users.everyone = const [kim];
      await harness.users.search('kim');

      bridges.last.emit(const MentionQuery('ki'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(harness.users.searches, isEmpty);
      expect(find.text('Kim Lee'), findsOneWidget);
    });

    testWidgets('a label that is gone shows so', (tester) async {
      await openEditor(tester);
      await harness.labels.delete(1);
      await tester.pumpAndSettle();

      expect(find.text(en.labelsGoneTitle), findsWidgets);
    });

    test('a draft belongs to its label or team only', () async {
      final drafts = DescriptionDrafts(MemoryPreferencesStore());
      const draft = DescriptionDraft(html: '<p>Draft</p>', base: '');
      await drafts.save(
        draft,
        account: 'a',
        target: const LabelDescriptionTarget(1),
      );

      expect(
        await drafts.read(
          account: 'a',
          target: const LabelDescriptionTarget(1),
        ),
        isNotNull,
      );
      for (final other in const <DescriptionTarget>[
        LabelDescriptionTarget(2),
        TeamDescriptionTarget(teamId: 1, description: ''),
        ProjectDescriptionTarget(1),
        TaskDescriptionTarget(1),
      ]) {
        expect(await drafts.read(account: 'a', target: other), isNull);
      }
    });
  });
}
