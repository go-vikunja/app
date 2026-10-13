import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/add_relation_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  Task bare(Task task) => task.copyWith(relatedTasks: const {});

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 2, title: 'Home'),
    ];
    final trip = sampleTask(id: 1, title: 'Plan the trip', identifier: 'W-1');
    final flights = sampleTask(id: 2, title: 'Book flights', identifier: 'W-2');
    final pack = sampleTask(
      id: 3,
      title: 'Pack the bags',
      identifier: 'W-3',
      done: true,
    );
    final passport = sampleTask(
      id: 4,
      title: 'Renew passport',
      identifier: 'H-4',
      projectId: 2,
    );
    final visa = sampleTask(id: 5, title: 'Get a visa', identifier: 'W-5');
    data.tasks.all = [
      trip.copyWith(
        relatedTasks: {
          TaskRelationKind.subtask: [flights, pack],
          TaskRelationKind.related: [passport],
          TaskRelationKind.blocked: [visa],
        },
      ),
      flights.copyWith(
        relatedTasks: {
          TaskRelationKind.parentTask: [bare(trip)],
        },
      ),
      pack.copyWith(
        relatedTasks: {
          TaskRelationKind.parentTask: [bare(trip)],
        },
      ),
      passport.copyWith(
        relatedTasks: {
          TaskRelationKind.related: [bare(trip)],
        },
      ),
      visa.copyWith(
        relatedTasks: {
          TaskRelationKind.blocking: [bare(trip)],
        },
      ),
      sampleTask(id: 6, title: 'Buy sunscreen', identifier: 'W-6'),
      sampleTask(id: 7, title: 'Buy a suitcase', identifier: 'W-7', done: true),
    ];
  });

  Finder sheet() => find.byType(TaskDetailSheet).last;

  Finder inSheet(Finder matching) =>
      find.descendant(of: sheet(), matching: matching);

  Finder rowOf(String title) => find.ancestor(
    of: inSheet(find.text(title)),
    matching: find.byType(RelationRow),
  );

  Future<void> openDetail(WidgetTester tester, String title) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2000));
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('subtasks', () {
    testWidgets('list each with its done state, identifier and the progress', (
      tester,
    ) async {
      await openDetail(tester, 'Plan the trip');

      expect(inSheet(find.text(en.taskDetailSubtasks)), findsOneWidget);
      expect(
        inSheet(find.text(en.taskDetailSubtasksDone(1, 2))),
        findsOneWidget,
      );
      expect(rowOf('Book flights'), findsOneWidget);
      expect(
        find.descendant(of: rowOf('Book flights'), matching: find.text('W-2')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rowOf('Book flights'),
          matching: find.byTooltip(en.taskMarkDone),
        ),
        findsOneWidget,
      );
      final packed = tester.widget<Text>(inSheet(find.text('Pack the bags')));
      expect(packed.style?.decoration, TextDecoration.lineThrough);
      expect(
        find.descendant(
          of: rowOf('Pack the bags'),
          matching: find.byTooltip(en.taskMarkNotDone),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the done control marks the subtask done, not the parent', (
      tester,
    ) async {
      await openDetail(tester, 'Plan the trip');

      await tapVisible(
        tester,
        find.descendant(
          of: rowOf('Book flights'),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );

      expect(data.tasks.writes, ['setDone 2 true']);
    });

    testWidgets('a tap opens the subtask over the sheet, which comes back', (
      tester,
    ) async {
      await openDetail(tester, 'Plan the trip');

      await tapVisible(tester, inSheet(find.text('Book flights')));

      expect(find.byType(TaskDetailSheet), findsNWidgets(2));
      expect(inSheet(find.text(en.taskDetailParentTask)), findsOneWidget);
      expect(rowOf('Plan the trip'), findsOneWidget);

      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailSubtasks)), findsOneWidget);
    });

    testWidgets('deleting the subtask from its sheet over the parent says so '
        'in the parent sheet', (tester) async {
      await openDetail(tester, 'Plan the trip');
      await tapVisible(tester, inSheet(find.text('Book flights')));
      expect(find.byType(TaskDetailSheet), findsNWidgets(2));

      await tester.tap(inSheet(find.byTooltip(en.moreActions)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskDeleteDialogConfirm));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(data.tasks.writes, ['delete 2']);
      expect(inSheet(find.text(en.taskDeleted)), findsOneWidget);
    });

    testWidgets('the parent line opens the parent', (tester) async {
      await openDetail(tester, 'Book flights');

      expect(inSheet(find.text(en.taskDetailParentTask)), findsOneWidget);
      await tapVisible(tester, inSheet(find.text('Plan the trip')));

      expect(find.byType(TaskDetailSheet), findsNWidgets(2));
      expect(
        inSheet(find.text(en.taskDetailSubtasksDone(1, 2))),
        findsOneWidget,
      );
    });

    testWidgets('adding one offline creates it in the parent project and '
        'queues the parent relation behind the create', (tester) async {
      data.engine.emit(
        const SyncFailed(
          failure: NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: null,
        ),
      );
      await openDetail(tester, 'Plan the trip');

      final field = inSheet(
        find.widgetWithText(TextField, en.taskDetailAddSubtask),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, '  Check in online ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['create -1 Check in online', 'update -1']);
      expect(
        data.tasks.creates.single,
        const NewTask(projectId: 1, title: 'Check in online'),
      );
      expect(data.tasks.updates.single, (
        -1,
        TaskChanges(
          relations: RelationChange(
            added: {const TaskRelationRef(TaskRelationKind.parentTask, 1)},
          ),
        ),
      ));
      expect(rowOf('Check in online'), findsOneWidget);
      expect(
        inSheet(find.text(en.taskDetailSubtasksDone(1, 3))),
        findsOneWidget,
      );
      final editable = tester.widget<TextField>(field);
      expect(editable.controller!.text, isEmpty);
      expect(editable.focusNode!.hasFocus, isTrue);
    });

    testWidgets('a subtask whose relation cannot be queued is not offered '
        'again, which would make it twice', (tester) async {
      data.tasks.beforeWrite = () async {
        if (data.tasks.updates.isNotEmpty) throw StateError('database');
      };
      await openDetail(tester, 'Plan the trip');

      final field = inSheet(
        find.widgetWithText(TextField, en.taskDetailAddSubtask),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Check in online');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(data.tasks.creates, hasLength(1));
      expect(inSheet(find.text(en.taskDetailSubtaskNotLinked)), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    });

    testWidgets('on iOS Done keeps the keyboard for the next subtask, Done on '
        'the empty field and a drag of the sheet close it', (tester) async {
      await openDetail(tester, 'Plan the trip');
      final field = inSheet(
        find.widgetWithText(TextField, en.taskDetailAddSubtask),
      );
      FocusNode focus() => tester.widget<TextField>(field).focusNode!;
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Check in online');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(data.tasks.creates.single.title, 'Check in online');
      expect(focus().hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(focus().hasFocus, isFalse);
      expect(data.tasks.creates, hasLength(1));

      await tester.showKeyboard(field);
      await tester.pumpAndSettle();
      expect(focus().hasFocus, isTrue);
      await tester.drag(
        inSheet(find.text(en.taskDetailDescription)),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      expect(focus().hasFocus, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the typed title and the focus stay when the pending chip '
        'above goes', (tester) async {
      data.tasks.pendingTaskIds = {1};
      await openDetail(tester, 'Plan the trip');
      expect(inSheet(find.text(en.taskNotYetSynced)), findsOneWidget);
      final field = inSheet(
        find.widgetWithText(TextField, en.taskDetailAddSubtask),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Check in');
      await tester.pumpAndSettle();

      data.tasks.pendingTaskIds = {};
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.taskNotYetSynced)), findsNothing);
      final editable = tester.widget<TextField>(field);
      expect(editable.controller!.text, 'Check in');
      expect(editable.focusNode!.hasFocus, isTrue);
    });

    testWidgets('a task without subtasks still offers the field', (
      tester,
    ) async {
      await openDetail(tester, 'Buy sunscreen');

      expect(inSheet(find.text(en.taskDetailSubtasks)), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailSubtasksDone(0, 0))), findsNothing);
      expect(
        inSheet(find.widgetWithText(TextField, en.taskDetailAddSubtask)),
        findsOneWidget,
      );
      expect(inSheet(find.text(en.taskDetailParentTask)), findsNothing);
    });
  });

  group('related tasks', () {
    testWidgets('are grouped under their localized kinds, with the project of '
        'a task elsewhere', (tester) async {
      await openDetail(tester, 'Plan the trip');

      expect(inSheet(find.text(en.taskDetailRelatedTasks)), findsOneWidget);
      expect(inSheet(find.text(en.taskRelationRelated)), findsOneWidget);
      expect(inSheet(find.text(en.taskRelationBlocked)), findsOneWidget);
      expect(inSheet(find.text(en.taskRelationBlocking)), findsNothing);
      expect(
        find.descendant(
          of: rowOf('Renew passport'),
          matching: find.text('H-4 · Home'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rowOf('Get a visa'), matching: find.text('W-5')),
        findsOneWidget,
      );
      final related = tester.getTopLeft(
        inSheet(find.text(en.taskRelationRelated)),
      );
      final blocked = tester.getTopLeft(
        inSheet(find.text(en.taskRelationBlocked)),
      );
      expect(related.dy, lessThan(blocked.dy));
    });

    testWidgets('the other side shows the inverse kind', (tester) async {
      await openDetail(tester, 'Get a visa');

      expect(inSheet(find.text(en.taskRelationBlocking)), findsOneWidget);
      expect(rowOf('Plan the trip'), findsOneWidget);
    });

    testWidgets('removing one asks first, then removes it from both tasks', (
      tester,
    ) async {
      await openDetail(tester, 'Plan the trip');

      await tapVisible(
        tester,
        find.descendant(
          of: rowOf('Renew passport'),
          matching: find.byTooltip(en.taskRelationRemove),
        ),
      );
      expect(find.text(en.taskRelationRemoveTitle), findsOneWidget);
      expect(
        find.text(en.taskRelationRemoveBody('Renew passport')),
        findsOneWidget,
      );
      expect(data.tasks.updates, isEmpty);

      await tester.tap(find.text(en.taskRelationRemoveConfirm));
      await tester.pumpAndSettle();

      expect(data.tasks.updates.single, (
        1,
        TaskChanges(
          relations: RelationChange(
            removed: {const TaskRelationRef(TaskRelationKind.related, 4)},
          ),
        ),
      ));
      expect(rowOf('Renew passport'), findsNothing);
      expect(inSheet(find.text(en.taskRelationRelated)), findsNothing);
      expect(data.tasks.find(4)!.relatedTasks, isEmpty);
    });

    testWidgets('cancelling the removal keeps the relation', (tester) async {
      await openDetail(tester, 'Plan the trip');

      await tapVisible(
        tester,
        find.descendant(
          of: rowOf('Get a visa'),
          matching: find.byTooltip(en.taskRelationRemove),
        ),
      );
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(data.tasks.updates, isEmpty);
      expect(rowOf('Get a visa'), findsOneWidget);
    });

    testWidgets('removing a subtask removes the subtask relation', (
      tester,
    ) async {
      await openDetail(tester, 'Plan the trip');

      await tapVisible(
        tester,
        find.descendant(
          of: rowOf('Book flights'),
          matching: find.byTooltip(en.taskRelationRemove),
        ),
      );
      await tester.tap(find.text(en.taskRelationRemoveConfirm));
      await tester.pumpAndSettle();

      expect(
        data.tasks.updates.single.$2.relations,
        RelationChange(
          removed: {const TaskRelationRef(TaskRelationKind.subtask, 2)},
        ),
      );
      expect(data.tasks.find(2)!.parentTasks, isEmpty);
    });

    testWidgets('the removal asks with a destructive Cupertino alert on iOS', (
      tester,
    ) async {
      await openDetail(tester, 'Plan the trip');
      await tapVisible(
        tester,
        find.descendant(
          of: rowOf('Get a visa'),
          matching: find.byTooltip(en.taskRelationRemove),
        ),
      );

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      final confirm = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(
          CupertinoDialogAction,
          en.taskRelationRemoveConfirm,
        ),
      );
      expect(confirm.isDestructiveAction, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('add relation', () {
    Finder pickerRows() => find.descendant(
      of: find.byType(AddRelationSheet),
      matching: find.byType(ListTile),
    );

    Future<void> openPicker(WidgetTester tester) async {
      await openDetail(tester, 'Plan the trip');
      await tapVisible(tester, inSheet(find.text(en.taskDetailAddRelation)));
      expect(find.byType(AddRelationSheet), findsOneWidget);
    }

    Finder inPicker(Finder matching) =>
        find.descendant(of: find.byType(AddRelationSheet), matching: matching);

    testWidgets('offers the open tasks except the task itself and those it '
        'already has that relation to, Related to by default', (tester) async {
      await openPicker(tester);

      expect(inPicker(find.text(en.taskRelationRelated)), findsOneWidget);
      expect(inPicker(find.text('Buy sunscreen')), findsOneWidget);
      expect(inPicker(find.text('Book flights')), findsOneWidget);
      expect(inPicker(find.text('Get a visa')), findsOneWidget);
      expect(inPicker(find.text('Plan the trip')), findsNothing);
      expect(inPicker(find.text('Renew passport')), findsNothing);
      expect(inPicker(find.text('Buy a suitcase')), findsNothing);
      expect(inPicker(find.text('Pack the bags')), findsNothing);
    });

    testWidgets('searches title and identifier and can include done tasks', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.enterText(
        inPicker(find.widgetWithText(TextField, en.addRelationSearch)),
        'buy',
      );
      await tester.pump();
      expect(inPicker(find.text('Buy sunscreen')), findsOneWidget);
      expect(inPicker(find.text('Buy a suitcase')), findsNothing);

      await tester.tap(inPicker(find.text(en.addRelationShowDone)));
      await tester.pumpAndSettle();
      expect(inPicker(find.text('Buy a suitcase')), findsOneWidget);

      await tester.enterText(
        inPicker(find.widgetWithText(TextField, en.addRelationSearch)),
        'w-5',
      );
      await tester.pump();
      expect(inPicker(find.text('Get a visa')), findsOneWidget);
      expect(pickerRows(), findsNWidgets(2));

      await tester.enterText(
        inPicker(find.widgetWithText(TextField, en.addRelationSearch)),
        'nothing like this',
      );
      await tester.pump();
      expect(inPicker(find.text(en.addRelationNoMatches)), findsOneWidget);
    });

    testWidgets('picking a task adds the relation of the chosen kind', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(inPicker(find.text(en.taskRelationRelated)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskRelationBlocking).last);
      await tester.pumpAndSettle();
      await tester.tap(inPicker(find.text('Buy sunscreen')));
      await tester.pumpAndSettle();

      expect(find.byType(AddRelationSheet), findsNothing);
      expect(data.tasks.updates.single, (
        1,
        TaskChanges(
          relations: RelationChange(
            added: {const TaskRelationRef(TaskRelationKind.blocking, 6)},
          ),
        ),
      ));
      expect(inSheet(find.text(en.taskRelationBlocking)), findsOneWidget);
      expect(rowOf('Buy sunscreen'), findsOneWidget);
      expect(data.tasks.find(6)!.relatedTasks[TaskRelationKind.blocked], [
        isA<Task>().having((task) => task.id, 'id', 1),
      ]);
    });

    testWidgets('dismissing the picker changes nothing', (tester) async {
      await openPicker(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AddRelationSheet), findsNothing);
      expect(data.tasks.updates, isEmpty);
    });
  });

  testWidgets('the sheet with relations meets the tap target and label '
      'guidelines', (tester) async {
    await openDetail(tester, 'Plan the trip');

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('the add relation sheet meets the tap target and label '
      'guidelines', (tester) async {
    await openDetail(tester, 'Plan the trip');
    await tapVisible(tester, inSheet(find.text(en.taskDetailAddRelation)));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
