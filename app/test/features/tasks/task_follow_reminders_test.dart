import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const reminder = TaskReminder(
    relativePeriod: Duration(hours: -1),
    relativeTo: ReminderRelativeTo.dueDate,
  );
  const own = Subscription(entity: SubscriptionEntity.task, entityId: 2);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      sampleTask(
        id: 2,
        title: 'Call back',
        due: DateTime(2026, 10, 12, 9),
        reminders: const [reminder],
      ),
      sampleTask(id: 3, title: 'No reminders'),
      sampleTask(
        id: 4,
        title: 'Finished',
        due: DateTime(2026, 10, 12, 9),
        reminders: const [reminder],
        done: true,
      ),
    ];
  });

  Finder inSheet(Finder matching) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: matching);

  Finder note() => inSheet(find.text(en.taskRemindersNotFollowed));

  Future<void> openDetail(
    WidgetTester tester,
    int id, {
    bool remindsFollowers = true,
  }) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1800));
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      connection: remindsFollowers ? fullServer280() : fullServer270(),
    );
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: data.tasks.find(id)!));
    await tester.pumpAndSettle();
  }

  Future<void> tapBell(WidgetTester tester) async {
    await tester.tap(inSheet(find.byType(FollowButton)));
    await tester.pumpAndSettle();
  }

  testWidgets('on a server that reminds only followers, a task the user does '
      "not follow says under its reminders that they won't notify, and "
      'Follow follows it', (tester) async {
    await openDetail(tester, 2);

    expect(note(), findsOneWidget);
    final reminders = tester.getRect(
      inSheet(find.text(en.taskDetailReminders)),
    );
    expect(tester.getRect(note()).top, greaterThan(reminders.top));

    await tester.tap(inSheet(find.text(en.followTask)));
    await tester.pumpAndSettle();

    expect(data.subscriptions.calls, ['setTask 2 true']);
    expect(note(), findsNothing);
    expect(inSheet(find.text(en.taskFollowed)), findsOneWidget);
  });

  testWidgets('unfollowing there says that the task no longer notifies, and '
      'the note appears', (tester) async {
    data.subscriptions.taskStates[2] = own;
    data.details.detailsByTask[2] = const TaskDetails(subscription: own);
    await openDetail(tester, 2);
    expect(note(), findsNothing);

    await tapBell(tester);

    expect(data.subscriptions.calls, ['setTask 2 false']);
    expect(inSheet(find.text(en.taskUnfollowedSilenced)), findsOneWidget);
    expect(note(), findsOneWidget);

    await tapBell(tester);
    expect(inSheet(find.text(en.taskFollowed)), findsOneWidget);
  });

  testWidgets('on an older server unfollowing only says so, and there is no '
      'note', (tester) async {
    data.subscriptions.taskStates[2] = own;
    data.details.detailsByTask[2] = const TaskDetails(subscription: own);
    await openDetail(tester, 2, remindsFollowers: false);

    await tapBell(tester);

    expect(inSheet(find.text(en.taskUnfollowed)), findsOneWidget);
    expect(inSheet(find.text(en.taskUnfollowedSilenced)), findsNothing);
    expect(note(), findsNothing);
  });

  testWidgets('no note without reminders', (tester) async {
    await openDetail(tester, 3);
    expect(note(), findsNothing);
  });

  testWidgets('a done task gets no note', (tester) async {
    await openDetail(tester, 4);
    expect(inSheet(find.text(en.taskDetailReminders)), findsOneWidget);
    expect(note(), findsNothing);
  });
}
