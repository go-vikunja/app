import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/assignee_picker.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import 'edit_page_harness.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const alice = User(id: 7, username: 'alice', name: 'Alice Example');
  const bob = User(id: 8, username: 'bob');
  const carol = User(id: 9, username: 'carol', name: 'Carol Writer');
  const dave = User(id: 10, username: 'dave', name: 'Dave Known');
  late SyncFakes data;
  late FakeUserRepository users;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 2, title: 'Personal'),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Shopping', assignees: const [carol]),
    ];
    users = FakeUserRepository(
      projectUsers: {
        1: const [alice, bob, carol],
        2: const [alice],
      },
      known: const [carol, dave],
    );
  });

  Future<void> openPage(WidgetTester tester) =>
      openEditPageWith(tester, data: data, taskId: 1, now: now, users: users);

  Future<void> openPicker(WidgetTester tester, [AppLocalizations? l10n]) async {
    await tapVisible(tester, find.text((l10n ?? en).taskEditAssign));
  }

  Finder picker() => find.byType(AssigneePicker);

  Finder inPicker(Finder finder) =>
      find.descendant(of: picker(), matching: finder);

  Finder searchField() =>
      find.widgetWithText(TextField, en.assigneePickerSearch);

  Finder rows() => inPicker(find.byType(CheckboxListTile));

  Finder row(String name) =>
      inPicker(find.widgetWithText(CheckboxListTile, name));

  List<String> rowNames(WidgetTester tester) => [
    for (final tile in tester.widgetList<CheckboxListTile>(rows()))
      (tile.title! as Text).data!,
  ];

  bool ticked(WidgetTester tester, String name) =>
      tester.widget<CheckboxListTile>(row(name)).value ?? false;

  group('section', () {
    testWidgets('shows initials and the display name with an unassign '
        'button each', (tester) async {
      data.tasks.all = [
        sampleTask(id: 1, title: 'Shopping', assignees: const [carol, bob]),
      ];
      await openPage(tester);

      final chip = find.widgetWithText(InputChip, 'Carol Writer');
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text('CW')),
        findsOneWidget,
      );
      expect(find.widgetWithText(InputChip, 'bob'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.byTooltip(en.taskEditUnassign('Carol Writer')),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
    });

    testWidgets('unassigning sends exactly the removal and guards leaving', (
      tester,
    ) async {
      await openPage(tester);

      await tester.tap(find.byTooltip(en.taskEditUnassign('Carol Writer')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();
      await saveEdits(tester);

      expect(data.tasks.updates, [
        (1, const TaskChanges(assignees: IdSetChange(removed: {9}))),
      ]);
    });
  });

  group('picker', () {
    testWidgets("searches the draft's project at once, assignees first", (
      tester,
    ) async {
      await openPage(tester);
      await openPicker(tester);

      expect(users.searches, [(1, '')]);
      expect(rowNames(tester), ['Carol Writer', 'Alice Example', 'bob']);
      expect(ticked(tester, 'Carol Writer'), isTrue);
      expect(inPicker(find.text('@alice')), findsOneWidget);
      expect(inPicker(find.text(en.assigneePickerOffline)), findsNothing);
    });

    testWidgets('ticks and unticks, Done returns them, Save sends the '
        'delta', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.tap(row('Alice Example'));
      await tester.tap(row('Carol Writer'));
      await tester.pumpAndSettle();
      // An assignee unticked stays listed.
      expect(rowNames(tester).first, 'Carol Writer');
      await tapPickerDone(tester);

      expect(find.widgetWithText(InputChip, 'Alice Example'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Carol Writer'), findsNothing);
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(
          assignees: IdSetChange(added: {7}, removed: {9}),
        ),
      );
    });

    testWidgets('waits for a 300 ms pause in typing, then asks once', (
      tester,
    ) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.enterText(searchField(), 'a');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(searchField(), 'al');
      await tester.pump(const Duration(milliseconds: 299));
      expect(users.searches, [(1, '')]);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(users.searches, [(1, ''), (1, 'al')]);
      expect(rowNames(tester), ['Carol Writer', 'Alice Example']);
    });

    testWidgets('a slower answer to an earlier query does not replace the '
        'latest', (tester) async {
      final slowA = Completer<void>();
      users.beforeAnswer = (query) =>
          query == 'b' ? slowA.future : Future.value();
      await openPage(tester);
      await openPicker(tester);

      await tester.enterText(searchField(), 'b');
      await tester.pump(AssigneePicker.debounce);
      await tester.enterText(searchField(), 'al');
      await tester.pump(AssigneePicker.debounce);
      await tester.pump();
      expect(rowNames(tester), ['Carol Writer', 'Alice Example']);

      slowA.complete();
      await tester.pumpAndSettle();
      expect(users.searches.map((s) => s.$2), ['', 'b', 'al']);
      expect(rowNames(tester), ['Carol Writer', 'Alice Example']);
    });

    testWidgets('shows progress while the server searches', (tester) async {
      final answer = Completer<void>();
      users.beforeAnswer = (_) => answer.future;
      await openPage(tester);
      await tester.ensureVisible(find.text(en.taskEditAssign));
      await tester.tap(find.text(en.taskEditAssign));
      await pumpFrames(tester, 5);

      expect(inPicker(find.byType(LinearProgressIndicator)), findsOneWidget);
      expect(find.bySemanticsLabel(en.assigneePickerSearching), findsOneWidget);

      answer.complete();
      await tester.pumpAndSettle();
      expect(inPicker(find.byType(LinearProgressIndicator)), findsNothing);
    });

    testWidgets('lists the known people at once while the server is slow, '
        'filtered while typing', (tester) async {
      final answer = Completer<void>();
      users.beforeAnswer = (_) => answer.future;
      await openPage(tester);
      await tester.ensureVisible(find.text(en.taskEditAssign));
      await tester.tap(find.text(en.taskEditAssign));
      await pumpFrames(tester, 5);

      expect(rowNames(tester), ['Carol Writer', 'Dave Known']);
      expect(inPicker(find.byType(LinearProgressIndicator)), findsOneWidget);
      expect(inPicker(find.text(en.assigneePickerOffline)), findsNothing);

      await tester.enterText(searchField(), 'dav');
      await tester.pump();
      expect(rowNames(tester), ['Carol Writer', 'Dave Known']);
      await tester.enterText(searchField(), 'zz');
      await tester.pump();
      expect(rowNames(tester), ['Carol Writer']);

      await tester.enterText(searchField(), 'al');
      await tester.pump(AssigneePicker.debounce);
      answer.complete();
      await tester.pumpAndSettle();
      expect(users.searches.map((s) => s.$2), ['', 'al']);
      expect(rowNames(tester), ['Carol Writer', 'Alice Example']);
    });

    testWidgets('offline it shows the known people with a notice and '
        'filters them while typing', (tester) async {
      users.searchFailure = const NetworkFailure(NetworkProblem.unreachable);
      await openPage(tester);
      await openPicker(tester);

      expect(inPicker(find.text(en.assigneePickerOffline)), findsOneWidget);
      expect(rowNames(tester), ['Carol Writer', 'Dave Known']);

      await tester.enterText(searchField(), 'dav');
      await tester.pump();
      expect(rowNames(tester), ['Carol Writer', 'Dave Known']);
      await tester.enterText(searchField(), 'nobody');
      await tester.pump();
      expect(rowNames(tester), ['Carol Writer']);

      await tester.tap(row('Carol Writer'));
      await tester.pumpAndSettle();
      await tapPickerDone(tester);
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(assignees: IdSetChange(removed: {9})),
      );
    });

    testWidgets('the search answers again once the connection is back', (
      tester,
    ) async {
      users.searchFailure = const NetworkFailure(NetworkProblem.timeout);
      await openPage(tester);
      await openPicker(tester);
      expect(inPicker(find.text(en.assigneePickerOffline)), findsOneWidget);

      users.searchFailure = null;
      await tester.enterText(searchField(), 'bo');
      await tester.pump(AssigneePicker.debounce);
      await tester.pumpAndSettle();

      expect(inPicker(find.text(en.assigneePickerOffline)), findsNothing);
      expect(rowNames(tester), ['Carol Writer', 'bob']);
    });

    testWidgets("another failure shows the server's message instead", (
      tester,
    ) async {
      users.searchFailure = const DomainError(
        400,
        code: 9999,
        message: 'Something odd',
      );
      await openPage(tester);
      await openPicker(tester);

      expect(
        inPicker(find.text(en.assigneePickerFallback('Something odd'))),
        findsOneWidget,
      );
      expect(rowNames(tester), ['Carol Writer', 'Dave Known']);
    });

    testWidgets('a route-absent 404 keeps its message', (tester) async {
      users.searchFailure = const NotFound(message: 'Not Found');
      await openPage(tester);
      await openPicker(tester);

      expect(
        inPicker(find.text(en.assigneePickerFallback('Not Found'))),
        findsOneWidget,
      );
    });

    for (final l10n in [en, de]) {
      for (final (name, failure, reason) in [
        (
          'no access',
          const Forbidden(message: 'Forbidden') as VikunjaFailure,
          l10n.assigneePickerNoAccess,
        ),
        (
          'a project gone',
          const NotFound(code: 3001, message: 'The project does not exist.'),
          l10n.assigneePickerNoAccess,
        ),
        (
          'a server error',
          const ServerFailure(500, message: 'Internal Server Error'),
          l10n.assigneePickerSearchFailed,
        ),
      ]) {
        testWidgets('${l10n.localeName}: $name in our own words', (
          tester,
        ) async {
          useLocale(tester, Locale(l10n.localeName));
          users.searchFailure = failure;
          await openPage(tester);
          await openPicker(tester, l10n);

          expect(
            inPicker(find.text(l10n.assigneePickerFallback(reason))),
            findsOneWidget,
          );
          expect(rowNames(tester), ['Carol Writer', 'Dave Known']);
        });
      }
    }

    testWidgets('someone ticked stays listed when the query hides them', (
      tester,
    ) async {
      await openPage(tester);
      await openPicker(tester);

      await tester.tap(row('bob'));
      await tester.enterText(searchField(), 'alice');
      await tester.pump(AssigneePicker.debounce);
      await tester.pumpAndSettle();

      expect(rowNames(tester), ['Carol Writer', 'bob', 'Alice Example']);
      expect(ticked(tester, 'bob'), isTrue);
    });

    testWidgets('searches the project the draft moved to and keeps the '
        'assignees', (tester) async {
      await openPage(tester);
      await tester.tap(find.widgetWithText(ListTile, en.taskEditProject));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'Carol Writer'), findsOneWidget);
      await openPicker(tester);
      expect(users.searches, [(2, '')]);
      expect(rowNames(tester), ['Carol Writer', 'Alice Example']);
    });

    testWidgets('nobody found says so', (tester) async {
      data.tasks.all = [sampleTask(id: 1, title: 'Shopping')];
      await openPage(tester);
      await openPicker(tester);

      await tester.enterText(searchField(), 'zzz');
      await tester.pump(AssigneePicker.debounce);
      await tester.pumpAndSettle();

      expect(inPicker(find.text(en.assigneePickerNoResults)), findsOneWidget);
    });

    testWidgets('is a Cupertino sheet on iOS', (tester) async {
      await openPage(tester);
      await openPicker(tester);

      expect(
        ModalRoute.of(tester.element(picker())),
        isA<CupertinoSheetRoute<List<User>>>(),
      );
      expect(inPicker(find.byType(CupertinoCheckbox)), findsNWidgets(3));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('the page stays the same while the picker is dismissed', (
    tester,
  ) async {
    await openPage(tester);
    await openPicker(tester);

    await tester.tap(row('bob'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditPage), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'bob'), findsNothing);
    expect(editSaveEnabled(tester), isFalse);
  });

  testWidgets('the picker meets the tap target and label guidelines', (
    tester,
  ) async {
    users.searchFailure = const NetworkFailure(NetworkProblem.unreachable);
    await openPage(tester);
    await openPicker(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
