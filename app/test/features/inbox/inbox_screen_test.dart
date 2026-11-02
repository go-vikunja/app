import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_page.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../accounts/accounts_harness.dart';
import 'inbox_samples.dart';

void main() {
  final now = DateTime(2026, 10, 13, 15);
  final anna = payloadUser(id: 2, username: 'anna', name: 'Anna Example');
  final me = payloadUser(id: 7, username: 'alice', name: 'Alice Example');
  final plants = payloadTask(id: 40, title: 'Water the plants', index: 12);
  final gone = payloadTask(id: 99, title: 'Old chore', index: 3);
  late SyncFakes data;

  final comment = inboxNotification(
    id: 6,
    name: 'task.comment',
    created: DateTime(2026, 10, 13, 14),
    payload: {
      'doer': anna,
      'task': plants,
      'comment': {'id': 1, 'comment': '<p>Done with the balcony</p>'},
    },
  );
  final assigned = inboxNotification(
    id: 5,
    name: 'task.assigned',
    created: DateTime(2026, 10, 13, 9),
    payload: {'doer': anna, 'task': plants, 'assignee': me},
  );
  final projectCreated = inboxNotification(
    id: 4,
    name: 'project.created',
    created: DateTime(2026, 10, 12, 18),
    readAt: DateTime(2026, 10, 12, 19),
    payload: {
      'doer': anna,
      'project': {'id': 3, 'title': 'Garden'},
    },
  );
  final teamAdded = inboxNotification(
    id: 3,
    name: 'team.member.added',
    created: DateTime(2026, 10, 12, 8),
    payload: {
      'doer': anna,
      'member': me,
      'team': {'id': 1, 'name': 'Family'},
    },
  );
  final deleted = inboxNotification(
    id: 2,
    name: 'task.deleted',
    created: DateTime(2026, 10, 2),
    readAt: DateTime(2026, 10, 3),
    payload: {'doer': anna, 'task': gone},
  );
  final mentioned = inboxNotification(
    id: 1,
    name: 'task.mentioned',
    created: DateTime(2026, 9, 30),
    payload: {'doer': anna, 'task': gone, 'is_new': false},
  );
  final allKinds = [
    comment,
    assigned,
    projectCreated,
    teamAdded,
    deleted,
    mentioned,
  ];

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [sampleTask(id: 40, title: 'Water the plants')];
    data.activity.notifications = allKinds;
  });

  Future<void> openInbox(WidgetTester tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.byType(InboxButton));
    await tester.pumpAndSettle();
  }

  Finder inInbox(Finder finder) =>
      find.descendant(of: find.byType(InboxScreen), matching: finder);

  Finder inboxScrollable() => inInbox(find.byType(Scrollable)).first;

  String location(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider).state.matchedLocation;

  final commentText = en.inboxCommented('Anna Example', 'Water the plants');

  group('the bell', () {
    testWidgets('shows the unread count and names it', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSignedInApp(tester, sync: data, now: now);

      expect(
        find.descendant(of: find.byType(InboxButton), matching: find.text('4')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(en.inboxButton(4)), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('follows reads and shows no badge without unread ones', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSignedInApp(tester, sync: data, now: now);

      await data.activity.markAllRead();
      await tester.pumpAndSettle();

      final badge = tester.widget<Badge>(
        find.descendant(
          of: find.byType(InboxButton),
          matching: find.byType(Badge),
        ),
      );
      expect(badge.isLabelVisible, isFalse);
      expect(find.bySemanticsLabel(en.inboxButton(0)), findsOneWidget);
      expect(en.inboxButton(0), en.inboxTitle);
      semantics.dispose();
    });

    testWidgets('counts a notification the server pushes at once', (
      tester,
    ) async {
      data.realtime.accepts = true;
      await pumpSignedInApp(tester, sync: data, now: now);
      expect(data.realtime.connectCalls, 1);

      data.realtime.lastSocket.push(
        RealtimeNotification(
          inboxNotification(
            id: 7,
            name: 'task.assigned',
            created: DateTime(2026, 10, 13, 14, 30),
            payload: {'doer': anna, 'task': plants, 'assignee': me},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(InboxButton), matching: find.text('5')),
        findsOneWidget,
      );
      expect(data.activity.notifications.first.id, 7);
    });

    testWidgets('opens the inbox over the shell', (tester) async {
      await openInbox(tester);

      expect(location(tester), AppRoutes.inbox);
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text(en.tabOverview), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.overview);
    });
  });

  testWidgets('lists every kind newest first under Today, Yesterday and '
      'Earlier', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1400));
    await openInbox(tester);

    final texts = [
      en.inboxToday,
      commentText,
      en.inboxAssignedYou('Anna Example', 'Water the plants'),
      en.inboxYesterday,
      en.inboxProjectCreated('Anna Example', 'Garden'),
      en.inboxAddedYouToTeam('Anna Example', 'Family'),
      en.inboxEarlier,
      en.inboxTaskDeleted('Anna Example', 'Old chore'),
      en.inboxMentioned('Anna Example', 'Old chore'),
    ];
    final tops = [
      for (final text in texts) tester.getTopLeft(inInbox(find.text(text))).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(
      inInbox(find.text(en.inboxQuoted('Done with the balcony'))),
      findsOne,
    );
    // The row's text names the task; the line below only says when.
    expect(inInbox(find.textContaining('Water the plants · ')), findsNothing);
    expect(
      find.descendant(
        of: find.ancestor(
          of: inInbox(find.text(commentText)),
          matching: find.byType(ListTile),
        ),
        matching: find.text(en.relativeHoursAgo(1)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('unread rows are bold and announced as unread', (tester) async {
    final semantics = tester.ensureSemantics();
    usePhoneSurface(tester, logicalSize: const Size(400, 1400));
    await openInbox(tester);

    FontWeight? weightOf(String text) =>
        tester.widget<Text>(inInbox(find.text(text))).style?.fontWeight;
    String labelOf(String text) => tester
        .getSemantics(
          find.ancestor(
            of: inInbox(find.text(text)),
            matching: find.byType(ListTile),
          ),
        )
        .label;
    final readText = en.inboxProjectCreated('Anna Example', 'Garden');

    expect(weightOf(commentText), FontWeight.w700);
    expect(weightOf(readText), isNot(FontWeight.w700));
    expect(labelOf(commentText), contains(en.inboxUnread));
    expect(labelOf(readText), isNot(contains(en.inboxUnread)));
    semantics.dispose();
  });

  group('a tap', () {
    testWidgets('on a task on this device marks it read and opens it', (
      tester,
    ) async {
      await openInbox(tester);

      await tester.tap(inInbox(find.text(commentText)));
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [6]);
      // At the comment, which may have scrolled the title out of the list.
      final sheet = tester.widget<TaskDetailSheet>(
        find.byType(TaskDetailSheet),
      );
      expect(sheet.task.title, 'Water the plants');
      expect(sheet.commentId, 1);
    });

    testWidgets('on a task that is not on this device reads it online', (
      tester,
    ) async {
      data.activity.notifications = [mentioned];
      data.resolver.online[const TaskById(99)] = sampleTask(
        id: 99,
        title: 'Old chore',
      );
      await openInbox(tester);

      await tester.tap(
        inInbox(find.text(en.inboxMentioned('Anna Example', 'Old chore'))),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [1]);
      expect(data.resolver.onlineRequests, [const TaskById(99)]);
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TaskDetailSheet),
          matching: find.text('Old chore'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TaskDetailSheet>(find.byType(TaskDetailSheet)).commentId,
        isNull,
      );
    });

    for (final (name, failure, message) in [
      ('gone on the server', null, en.taskOpenNotFound),
      (
        'not readable any more',
        const Forbidden() as Exception,
        en.taskOpenForbidden,
      ),
      (
        'not on this device while offline',
        const NetworkFailure(NetworkProblem.unreachable),
        en.taskOpenOffline,
      ),
    ]) {
      testWidgets('on a task $name says so', (tester) async {
        data.activity.notifications = [mentioned];
        if (failure != null) {
          data.resolver.failures[const TaskById(99)] = failure;
        }
        await openInbox(tester);

        await tester.tap(
          inInbox(find.text(en.inboxMentioned('Anna Example', 'Old chore'))),
        );
        await tester.pumpAndSettle();

        expect(data.activity.markedRead, [1]);
        expect(find.byType(TaskDetailSheet), findsNothing);
        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('on a read row marks nothing; a deleted task says so', (
      tester,
    ) async {
      data.activity.notifications = [deleted];
      await openInbox(tester);

      await tester.tap(
        inInbox(find.text(en.inboxTaskDeleted('Anna Example', 'Old chore'))),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, isEmpty);
      expect(find.text(en.inboxTaskWasDeleted), findsOneWidget);
      expect(find.text(en.inboxTaskNotLocal), findsNothing);
    });

    testWidgets('on a new project over the edit page with unsaved changes '
        'asks before it drops them', (tester) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 2200));
      data.projects.all = [
        ...data.projects.all,
        sampleProject(id: 3, title: 'Garden'),
      ];
      await pumpSignedInApp(
        tester,
        sync: data,
        now: now,
        overrides: [
          labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        ],
      );
      final router = containerOf(tester).read(appRouterProvider);
      unawaited(router.push(AppRoutes.taskEdit(40)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, en.taskEditTitleLabel),
        'Changed',
      );
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.inbox));
      await tester.pumpAndSettle();

      await tester.tap(
        inInbox(find.text(en.inboxProjectCreated('Anna Example', 'Garden'))),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(location(tester), AppRoutes.taskEdit(40));
      expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
    });

    testWidgets('on a new project opens it when it is on this device', (
      tester,
    ) async {
      data.projects.all = [
        ...data.projects.all,
        sampleProject(id: 3, title: 'Garden'),
      ];
      await openInbox(tester);

      await tester.tap(
        inInbox(find.text(en.inboxProjectCreated('Anna Example', 'Garden'))),
      );
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.project(3));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    testWidgets('on a new project that is not on this device says so', (
      tester,
    ) async {
      await openInbox(tester);

      await tester.tap(
        inInbox(find.text(en.inboxProjectCreated('Anna Example', 'Garden'))),
      );
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.inbox);
      expect(find.text(en.inboxProjectNotLocal), findsOneWidget);
    });

    testWidgets("on a team membership marks it read and opens the team's "
        'page', (tester) async {
      const alice = User(id: 7, username: 'alice', name: 'Alice Example');
      data.teams
        ..me = alice
        ..teams = [
          Team(
            id: 1,
            name: 'Family',
            members: const [TeamMember(user: alice)],
          ),
        ];
      await openInbox(tester);

      await tester.tap(
        inInbox(find.text(en.inboxAddedYouToTeam('Anna Example', 'Family'))),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [3]);
      expect(location(tester), AppRoutes.team(1));
      expect(find.byType(TeamPage), findsOneWidget);
      expect(data.teams.calls, ['read 1']);
    });

    testWidgets('on a team membership that names no team only marks it read', (
      tester,
    ) async {
      data.activity.notifications = [
        inboxNotification(
          id: 3,
          name: 'team.member.added',
          created: DateTime(2026, 10, 12, 8),
          payload: {
            'doer': anna,
            'member': me,
            'team': {'name': 'Family'},
          },
        ),
      ];
      await openInbox(tester);

      await tester.tap(
        inInbox(find.text(en.inboxAddedYouToTeam('Anna Example', 'Family'))),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [3]);
      expect(location(tester), AppRoutes.inbox);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets("the server's reminders are listed but stay out of the badge; "
      'mark all still takes them', (tester) async {
    final semantics = tester.ensureSemantics();
    data.activity.notifications = [
      inboxNotification(
        id: 9,
        name: 'task.reminder',
        created: DateTime(2026, 10, 13, 10),
        payload: {'task': plants},
      ),
    ];
    await pumpSignedInApp(tester, sync: data, now: now);

    expect(find.bySemanticsLabel(en.inboxButton(0)), findsOneWidget);

    await tester.tap(find.byType(InboxButton));
    await tester.pumpAndSettle();
    expect(
      inInbox(find.text(en.inboxReminder('Water the plants'))),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    final entry = tester.widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text(en.inboxMarkAllRead),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    expect(entry.enabled, isTrue);
    semantics.dispose();
  });

  testWidgets('mark all as read, then the menu entry rests', (tester) async {
    await openInbox(tester);

    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.inboxMarkAllRead));
    await tester.pumpAndSettle();

    expect(data.activity.markAllReadCalls, 1);
    expect(data.activity.unreadCount, 0);
    expect(inInbox(find.byType(InboxButton)), findsNothing);

    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    final entry = tester.widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text(en.inboxMarkAllRead),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    expect(entry.enabled, isFalse);
  });

  group('pull-to-refresh', () {
    testWidgets('refreshes the inbox far enough back to take what was '
        'read elsewhere', (tester) async {
      await openInbox(tester);
      // The foreground cadence refreshes at start too.
      final before = data.activity.refreshCalls;

      await pullToRefresh(tester, inboxScrollable());

      expect(data.activity.refreshCalls, before + 1);
      expect(data.activity.wholeWindowRefreshes, 1);
      expect(find.byType(OfflineNotice), findsNothing);
    });

    testWidgets('offline shows the notice above the saved notifications', (
      tester,
    ) async {
      data.activity.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await openInbox(tester);

      await pullToRefresh(tester, inboxScrollable());

      expect(inInbox(find.byType(OfflineNotice)), findsOneWidget);
      expect(inInbox(find.text(commentText)), findsOneWidget);
    });

    testWidgets('another failure shows the failure card', (tester) async {
      data.activity.onRefresh = () async => throw const UnexpectedResponse(500);
      await openInbox(tester);

      await pullToRefresh(tester, inboxScrollable());

      expect(inInbox(find.byType(DataFailureCard)), findsOneWidget);
      expect(inInbox(find.text(commentText)), findsOneWidget);
    });

    testWidgets('the app bar button refreshes too', (tester) async {
      await openInbox(tester);
      final before = data.activity.refreshCalls;

      await tester.tap(inInbox(find.byTooltip(en.refresh)));
      await tester.pumpAndSettle();

      expect(data.activity.refreshCalls, before + 1);
    });
  });

  testWidgets('says when there is nothing', (tester) async {
    data.activity.notifications = [];
    await openInbox(tester);

    expect(find.text(en.inboxEmptyTitle), findsOneWidget);
    expect(find.text(en.inboxEmptyBody), findsOneWidget);
  });

  testWidgets('an account switch closes the inbox', (tester) async {
    final accounts = ThreeAccounts();
    await accounts.seed();
    accounts.aliceData.activity.notifications = [comment];
    await accounts.pump(tester);
    await tester.tap(find.byType(InboxButton));
    await tester.pumpAndSettle();
    expect(find.byType(InboxScreen), findsOneWidget);

    await containerOf(tester)
        .read(accountSwitcherProvider)
        .switchTo(accounts.bob.id);
    await tester.pumpAndSettle();

    expect(find.byType(InboxScreen), findsNothing);
    expect(location(tester), AppRoutes.overview);
  });

  testWidgets('German texts', (tester) async {
    useLocale(tester, const Locale('de'));
    await openInbox(tester);

    expect(find.text(de.inboxTitle), findsWidgets);
    expect(find.text(de.inboxToday), findsOneWidget);
    expect(
      find.text(de.inboxCommented('Anna Example', 'Water the plants')),
      findsOneWidget,
    );
    expect(find.text(de.inboxQuoted('Done with the balcony')), findsOneWidget);
  });
}
