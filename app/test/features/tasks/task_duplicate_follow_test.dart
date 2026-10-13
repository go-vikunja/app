import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

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
      sampleTask(id: 2, title: 'Bare task', identifier: 'W-2'),
      const Task(id: -1, title: 'Fresh task', projectId: 1),
    ];
  });

  Finder sheet() => find.byType(TaskDetailSheet).last;

  Finder inSheet(Finder matching) =>
      find.descendant(of: sheet(), matching: matching);

  Future<void> openDetail(WidgetTester tester, String title) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();
  }

  IconButton bell(WidgetTester tester) => tester.widget<IconButton>(
    inSheet(
      find.descendant(
        of: find.byType(FollowButton),
        matching: find.byType(IconButton),
      ),
    ),
  );

  Future<void> tapBell(WidgetTester tester) async {
    await tester.tap(inSheet(find.byType(FollowButton)));
    await tester.pumpAndSettle();
  }

  group('follow', () {
    testWidgets('not following: the bell is off and a tap follows', (
      tester,
    ) async {
      await openDetail(tester, 'Bare task');

      expect(data.subscriptions.calls, ['forTask 2']);
      expect(inSheet(find.byTooltip(en.followTask)), findsOneWidget);
      expect(bell(tester).isSelected, isFalse);

      await tapBell(tester);

      expect(data.subscriptions.calls, ['forTask 2', 'setTask 2 true']);
      expect(inSheet(find.byTooltip(en.unfollowTask)), findsOneWidget);
      expect(bell(tester).isSelected, isTrue);
    });

    testWidgets('its own subscription: on, and a tap unfollows', (
      tester,
    ) async {
      data.subscriptions.taskStates[2] = const Subscription(
        entity: SubscriptionEntity.task,
        entityId: 2,
      );
      await openDetail(tester, 'Bare task');

      expect(bell(tester).isSelected, isTrue);
      expect(inSheet(find.text(en.followingViaProject('Work'))), findsNothing);

      await tapBell(tester);

      expect(data.subscriptions.calls.last, 'setTask 2 false');
      expect(bell(tester).isSelected, isFalse);
    });

    testWidgets('inherited from the project: on with a note, and unfollowing '
        'asks whether to stop following just this task', (tester) async {
      data.subscriptions.taskStates[2] = const Subscription(
        entity: SubscriptionEntity.project,
        entityId: 1,
      );
      await openDetail(tester, 'Bare task');

      expect(bell(tester).isSelected, isTrue);
      expect(
        inSheet(find.text(en.followingViaProject('Work'))),
        findsOneWidget,
      );

      await tapBell(tester);
      expect(find.text(en.followInheritedTaskTitle), findsOneWidget);
      expect(find.text(en.followInheritedTaskBody('Work')), findsOneWidget);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(data.subscriptions.calls, ['forTask 2']);
      expect(bell(tester).isSelected, isTrue);

      await tapBell(tester);
      await tester.tap(find.text(en.followInheritedConfirm));
      await tester.pumpAndSettle();

      expect(data.subscriptions.calls, ['forTask 2', 'setTask 2 false']);
      expect(bell(tester).isSelected, isFalse);
      expect(inSheet(find.text(en.followingViaProject('Work'))), findsNothing);
    });

    testWidgets('offline the bell is a dimmed plain button, not an unselected '
        'toggle; a tap says why and asks again', (tester) async {
      data.subscriptions.readFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await openDetail(tester, 'Bare task');

      expect(bell(tester).isSelected, isNull);
      expect(bell(tester).onPressed, isNotNull);
      expect(inSheet(find.byTooltip(en.followTaskUnavailable)), findsOneWidget);
      expect(inSheet(find.byTooltip(en.followTask)), findsNothing);

      await tapBell(tester);
      expect(inSheet(find.text(en.followNeedsConnection)), findsOneWidget);
      expect(data.subscriptions.calls, ['forTask 2', 'forTask 2']);

      data.subscriptions.readFailure = null;
      await tapBell(tester);
      expect(data.subscriptions.calls, ['forTask 2', 'forTask 2', 'forTask 2']);

      await tapBell(tester);
      expect(data.subscriptions.calls.last, 'setTask 2 true');
      expect(bell(tester).isSelected, isTrue);
    });

    testWidgets('the bell waits while the state loads', (tester) async {
      final loaded = Completer<void>();
      data.subscriptions.beforeCall = (_) => loaded.future;
      await openDetail(tester, 'Bare task');

      expect(bell(tester).onPressed, isNull);
      expect(inSheet(find.byTooltip(en.followChecking)), findsOneWidget);

      loaded.complete();
      await tester.pumpAndSettle();
      expect(bell(tester).onPressed, isNotNull);
    });

    testWidgets('a task not yet synced can be followed once it is, without '
        'asking the server', (tester) async {
      await openDetail(tester, 'Fresh task');

      expect(data.subscriptions.calls, isEmpty);
      expect(bell(tester).isSelected, isNull);
      expect(inSheet(find.byTooltip(en.followTaskUnavailable)), findsOneWidget);
      await tapBell(tester);

      expect(inSheet(find.text(en.followTaskOnceSynced)), findsOneWidget);
      expect(data.subscriptions.calls, isEmpty);
    });

    testWidgets('once the server names the task its state loads', (
      tester,
    ) async {
      await openDetail(tester, 'Fresh task');

      data.tasks.remapTask(-1, 40);
      await tester.pumpAndSettle();

      expect(data.subscriptions.calls, ['forTask 40']);
      await tapBell(tester);
      expect(data.subscriptions.calls.last, 'setTask 40 true');
    });

    testWidgets('a failed change says so and keeps the state', (tester) async {
      data.subscriptions.writeFailure = const ServerFailure(500);
      await openDetail(tester, 'Bare task');

      await tapBell(tester);

      expect(inSheet(find.text(en.followFailed)), findsOneWidget);
      expect(bell(tester).isSelected, isFalse);
    });

    testWidgets('a task the server cannot address yet is explained', (
      tester,
    ) async {
      data.subscriptions.writeFailure = const TaskNotSyncedYet(2);
      await openDetail(tester, 'Bare task');

      await tapBell(tester);

      expect(inSheet(find.text(en.followTaskOnceSynced)), findsOneWidget);
    });
  });

  group('duplicate', () {
    Future<void> duplicate(WidgetTester tester) async {
      await tester.tap(inSheet(find.byTooltip(en.moreActions)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskDuplicate));
      await tester.pumpAndSettle();
    }

    testWidgets('confirms in the sheet, and Open shows the copy', (
      tester,
    ) async {
      await openDetail(tester, 'Bare task');

      await duplicate(tester);

      expect(data.tasks.duplicated, [2]);
      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(inSheet(find.text(en.taskDuplicated)), findsOneWidget);
      expect(inSheet(find.text(en.taskRelationCopiedTo)), findsOneWidget);

      await tester.tap(inSheet(find.text(en.taskDuplicateOpen)));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNWidgets(2));
      expect(inSheet(find.text(en.taskRelationCopiedFrom)), findsOneWidget);
      expect(
        find.ancestor(
          of: inSheet(find.text('Bare task')).last,
          matching: find.byType(RelationRow),
        ),
        findsOneWidget,
      );
    });

    for (final (name, failure, message) in [
      (
        'offline it needs a connection',
        const NetworkFailure(NetworkProblem.unreachable) as Exception,
        en.taskDuplicateNeedsConnection,
      ),
      (
        'with changes not synced it says so',
        const TaskNotSyncedYet(2),
        en.taskDuplicateNotSynced,
      ),
      (
        'a refusal names the reason',
        const Forbidden(message: 'No access'),
        en.taskDuplicateFailed('No access'),
      ),
    ]) {
      testWidgets(name, (tester) async {
        data.tasks.duplicateFailure = failure;
        await openDetail(tester, 'Bare task');

        await duplicate(tester);

        expect(inSheet(find.text(message)), findsOneWidget);
        expect(inSheet(find.text(en.taskDuplicated)), findsNothing);
        expect(find.byType(TaskDetailSheet), findsOneWidget);
      });
    }
  });
}
