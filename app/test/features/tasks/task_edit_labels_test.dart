import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/features/tasks/application/color_palette.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';

import '../../helpers/fake_write_client.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/test_database.dart';
import 'edit_page_harness.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  final errand = sampleLabel(id: 1, title: 'Errand', hexColor: 'ffeb10');
  final finance = sampleLabel(id: 2, title: 'Finance', hexColor: '1973ff');
  final garden = sampleLabel(id: 3, title: 'Garden');
  final gardening = sampleLabel(id: 4, title: 'Gardening tools');
  late SyncFakes data;
  late FakeLabelRepository labels;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Shopping', labels: [errand]),
    ];
    labels = FakeLabelRepository(labels: [errand, finance, garden, gardening]);
  });

  Future<void> openPage(WidgetTester tester) =>
      openEditPageWith(tester, data: data, taskId: 1, now: now, labels: labels);

  Future<void> openPicker(WidgetTester tester, [AppLocalizations? l10n]) async {
    await tapVisible(tester, find.text((l10n ?? en).taskEditAddLabel));
  }

  Finder picker() => find.byType(LabelPicker);

  Finder inPicker(Finder finder) =>
      find.descendant(of: picker(), matching: finder);

  Finder searchField() => find.widgetWithText(TextField, en.labelPickerSearch);

  Finder row(String title) =>
      inPicker(find.widgetWithText(CheckboxListTile, title));

  bool ticked(WidgetTester tester, String title) =>
      tester.widget<CheckboxListTile>(row(title)).value ?? false;

  Finder createRow(String title) =>
      inPicker(find.widgetWithText(ListTile, en.labelPickerCreate(title)));

  group('section', () {
    testWidgets('shows the labels in their colours with a remove button '
        'each', (tester) async {
      await openPage(tester);

      final chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, 'Errand'),
      );
      expect(chip.backgroundColor, const Color(0xFFFFEB10));
      expect(chip.labelStyle?.color, const Color(0xFF000000));
      expect(find.byTooltip(en.taskEditRemoveLabel('Errand')), findsOneWidget);
      expect(
        tester.getSemantics(find.byTooltip(en.taskEditRemoveLabel('Errand'))),
        isSemantics(
          tooltip: en.taskEditRemoveLabel('Errand'),
          isButton: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('removing a label sends exactly its removal', (tester) async {
      await openPage(tester);

      await tester.tap(find.byTooltip(en.taskEditRemoveLabel('Errand')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Errand'), findsNothing);
      await saveEdits(tester);

      expect(data.tasks.updates, [
        (1, const TaskChanges(labels: IdSetChange(removed: {1}))),
      ]);
    });

    testWidgets('a removed label guards leaving like any other edit', (
      tester,
    ) async {
      await openPage(tester);

      await tester.tap(find.byTooltip(en.taskEditRemoveLabel('Errand')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(find.byType(TaskEditPage), findsOneWidget);
    });
  });

  group('picker', () {
    testWidgets('lists every label with the task ones ticked and the search '
        'field focused', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      expect(find.text(en.labelPickerTitle), findsOneWidget);
      expect(tester.widget<TextField>(searchField()).autofocus, isTrue);
      expect(ticked(tester, 'Errand'), isTrue);
      expect(ticked(tester, 'Finance'), isFalse);
      expect(row('Gardening tools'), findsOneWidget);
      expect(
        tester.getSemantics(row('Finance')),
        isSemantics(
          label: 'Finance',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('filters by substring, ignoring case', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.enterText(searchField(), 'GARD');
      await tester.pumpAndSettle();

      expect(row('Garden'), findsOneWidget);
      expect(row('Gardening tools'), findsOneWidget);
      expect(row('Errand'), findsNothing);
      expect(row('Finance'), findsNothing);
      expect(createRow('GARD'), findsOneWidget);

      await tester.enterText(searchField(), ' garden ');
      await tester.pumpAndSettle();
      expect(createRow('garden'), findsNothing);
      expect(inPicker(find.byIcon(Icons.add)), findsNothing);
    });

    testWidgets('ticks several, Done returns them, Save sends the delta', (
      tester,
    ) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.tap(row('Finance'));
      await tester.tap(row('Garden'));
      await tester.tap(row('Errand'));
      await tester.pumpAndSettle();
      expect(ticked(tester, 'Errand'), isFalse);
      await tapPickerDone(tester);

      expect(picker(), findsNothing);
      expect(find.widgetWithText(InputChip, 'Finance'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Garden'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Errand'), findsNothing);
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(
          labels: IdSetChange(added: {2, 3}, removed: {1}),
        ),
      );
    });

    testWidgets('dismissing keeps the previous selection', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.tap(row('Finance'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(picker(), findsNothing);
      expect(find.widgetWithText(InputChip, 'Finance'), findsNothing);
      expect(editSaveEnabled(tester), isFalse);
    });

    testWidgets('ticking a label back is no change', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.tap(row('Errand'));
      await tester.pumpAndSettle();
      await tester.tap(row('Errand'));
      await tester.pumpAndSettle();
      await tapPickerDone(tester);

      expect(editSaveEnabled(tester), isFalse);
    });

    testWidgets('the keyboard action creates the offered label, ticks the '
        'only match, or closes the keyboard', (tester) async {
      await openPage(tester);
      await openPicker(tester);
      expect(
        tester.widget<TextField>(searchField()).textInputAction,
        TextInputAction.done,
      );

      await tester.enterText(searchField(), 'Groceries');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(labels.created.single.title, 'Groceries');
      expect(ticked(tester, 'Groceries'), isTrue);

      await tester.enterText(searchField(), 'finance');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(ticked(tester, 'Finance'), isTrue);
      expect(labels.created, hasLength(1));
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await tester.enterText(searchField(), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets('is a Cupertino sheet on iOS', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      expect(
        ModalRoute.of(tester.element(picker())),
        isA<CupertinoSheetRoute<List<Label>>>(),
      );
      expect(inPicker(find.byType(CupertinoCheckbox)), findsNWidgets(4));
      expect(
        inPicker(find.widgetWithText(CupertinoButton, en.pickerDone)),
        findsOneWidget,
      );
      await tester.tap(row('Finance'));
      await tester.pumpAndSettle();
      await tapPickerDone(tester);
      expect(find.widgetWithText(InputChip, 'Finance'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('creating', () {
    testWidgets('creates the label in a web colour and ticks it', (
      tester,
    ) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.enterText(searchField(), '  Groceries ');
      await tester.pumpAndSettle();
      expect(createRow('Groceries'), findsOneWidget);
      await tester.tap(createRow('Groceries'));
      await tester.pumpAndSettle();

      final created = labels.created.single;
      expect(created.title, 'Groceries');
      expect(okabeItoColors, contains(created.hexColor));
      expect(createRow('Groceries'), findsNothing);
      expect(ticked(tester, 'Groceries'), isTrue);

      await tapPickerDone(tester);
      expect(find.widgetWithText(InputChip, 'Groceries'), findsOneWidget);
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(labels: IdSetChange(added: {500})),
      );
    });

    testWidgets('offline it creates the label on the device at once, '
        'without a request or a connection note, and ticks it', (tester) async {
      final db = testDatabase();
      await db.labelsDao.upsertAll([errand, finance, garden, gardening]);
      final write = FakeWriteClient(clock: () => now)
        ..beforeRequest = (_) =>
            throw const NetworkFailure(NetworkProblem.unreachable);
      final local = LocalLabelRepository(db, write, now: () => now);
      await openEditPageWith(
        tester,
        data: data,
        taskId: 1,
        now: now,
        labels: local,
      );
      await openPicker(tester);

      await tester.enterText(searchField(), 'Groceries');
      await tester.pumpAndSettle();
      await tester.tap(createRow('Groceries'));
      await tester.pumpAndSettle();

      expect(write.requests, isEmpty);
      expect(ticked(tester, 'Groceries'), isTrue);
      expect(createRow('Groceries'), findsNothing);
      expect(
        inPicker(find.textContaining(en.labelsNeedsConnection)),
        findsNothing,
      );
      expect(
        (await db.outboxDao.all()).single.kind,
        OutboxOperationKind.createLabel.name,
      );
      await tapPickerDone(tester);
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(labels: IdSetChange(added: {-1})),
      );
    });

    testWidgets('a label the device cannot store says so and ticks '
        'nothing', (tester) async {
      labels.createFailure = const UnexpectedResponse(null, message: 'disk');
      await openPage(tester);
      await openPicker(tester);

      await tester.enterText(searchField(), 'Groceries');
      await tester.pumpAndSettle();
      await tester.tap(createRow('Groceries'));
      await tester.pumpAndSettle();

      expect(inPicker(find.text(en.localChangeFailed)), findsOneWidget);
      expect(createRow('Groceries'), findsOneWidget);
      await tester.enterText(searchField(), 'Grocery');
      await tester.pumpAndSettle();
      expect(inPicker(find.text(en.localChangeFailed)), findsNothing);
      await tapPickerDone(tester);
      expect(editSaveEnabled(tester), isFalse);
    });

    testWidgets('a ticked label created here follows its server id when its '
        'create is answered while the picker is open', (tester) async {
      labels = FakeLabelRepository(
        labels: [
          errand,
          const Label(id: -1, title: 'Groceries'),
        ],
      );
      await openPage(tester);
      await openPicker(tester);
      await tester.tap(row('Groceries'));
      await tester.pumpAndSettle();

      labels.remap(-1, 900);
      await tester.pumpAndSettle();

      expect(row('Groceries'), findsOneWidget);
      expect(ticked(tester, 'Groceries'), isTrue);
      await tapPickerDone(tester);
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(labels: IdSetChange(added: {900})),
      );
    });

    testWidgets('a ticked label from findOrCreate that took a label the '
        'server had shows that label on Done, its title and colour', (
      tester,
    ) async {
      labels = FakeLabelRepository(
        labels: [
          errand,
          const Label(id: -1, title: 'groceries', hexColor: '000000'),
        ],
      );
      await openPage(tester);
      await openPicker(tester);
      await tester.tap(row('groceries'));
      await tester.pumpAndSettle();

      labels.remap(
        -1,
        900,
        taken: sampleLabel(id: 900, title: 'Groceries', hexColor: '1973ff'),
      );
      await tester.pumpAndSettle();
      await tapPickerDone(tester);

      expect(find.widgetWithText(InputChip, 'groceries'), findsNothing);
      final chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, 'Groceries'),
      );
      expect(chip.backgroundColor, const Color(0xFF1973FF));
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(labels: IdSetChange(added: {900})),
      );
    });

    testWidgets('opened before the create of a label the task carries was '
        'answered, following it to its server id is no change', (tester) async {
      const groceries = Label(id: -1, title: 'Groceries');
      data.tasks.all = [
        sampleTask(id: 1, title: 'Shopping', labels: [errand, groceries]),
      ];
      labels = FakeLabelRepository(labels: [errand, groceries]);
      await openPage(tester);
      labels.remap(-1, 900);
      await tester.pumpAndSettle();

      await openPicker(tester);
      expect(ticked(tester, 'Groceries'), isTrue);
      await tapPickerDone(tester);

      expect(editSaveEnabled(tester), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(find.byType(TaskEditPage), findsNothing);
    });

    testWidgets('refuses a title over 250 characters', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      final tooLong = 'x' * 251;
      await tester.enterText(searchField(), tooLong);
      await tester.pumpAndSettle();

      expect(
        inPicker(find.text(en.labelPickerTitleTooLong(250))),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(createRow(tooLong)).enabled, isFalse);
      await tester.tap(createRow(tooLong), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(labels.created, isEmpty);

      final longest = 'x' * 250;
      await tester.enterText(searchField(), longest);
      await tester.pumpAndSettle();
      expect(
        inPicker(find.text(en.labelPickerTitleTooLong(250))),
        findsNothing,
      );
      await tester.tap(createRow(longest));
      await tester.pumpAndSettle();
      expect(labels.created.single.title, longest);
    });
  });

  testWidgets('without any label it says how to create one', (tester) async {
    labels = FakeLabelRepository();
    data.tasks.all = [sampleTask(id: 1, title: 'Shopping')];
    await openPage(tester);
    await openPicker(tester);

    expect(inPicker(find.text(en.labelPickerEmpty)), findsOneWidget);
  });

  testWidgets('a label of the task this device has no row for still '
      'shows', (tester) async {
    labels = FakeLabelRepository(labels: [finance]);
    await openPage(tester);
    await openPicker(tester);

    expect(ticked(tester, 'Errand'), isTrue);
    expect(ticked(tester, 'Finance'), isFalse);
  });

  testWidgets('the picker meets the tap target and label guidelines', (
    tester,
  ) async {
    await openPage(tester);
    await openPicker(tester);
    await tester.enterText(searchField(), 'Gar');
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
