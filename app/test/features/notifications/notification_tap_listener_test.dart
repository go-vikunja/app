import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../accounts/accounts_harness.dart';
import '../inbox/inbox_samples.dart';

void main() {
  late SyncFakes data;
  late NotificationFakes notifications;

  setUp(() {
    data = SyncFakes();
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [sampleTask(id: 7, title: 'Water the plants')];
    notifications = NotificationFakes();
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) =>
      routerOf(tester).state.matchedLocation;

  String activeAccountId(WidgetTester tester) =>
      containerOf(tester).read(accountsProvider).value!.activeAccountId!;

  String payload({
    required String accountId,
    int taskId = 7,
    String key = '7:due',
  }) => NotificationPayload(
    accountId: accountId,
    taskId: taskId,
    key: key,
  ).toJson();

  final sheet = find.byType(TaskDetailSheet);

  testWidgets('a tap opens the task over the overview', (tester) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);
    routerOf(tester).go(AppRoutes.project(1));
    await tester.pumpAndSettle();

    notifications.taps.tap(payload(accountId: activeAccountId(tester)));
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Water the plants')),
      findsOneWidget,
    );
  });

  testWidgets('a tap over the edit page keeps the page and its unsaved '
      'changes under the sheet', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2200));
    await pumpSignedInApp(
      tester,
      sync: data,
      notifications: notifications,
      overrides: [
        labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    unawaited(routerOf(tester).push(AppRoutes.taskEdit(7)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, en.taskEditTitleLabel),
      'Changed',
    );
    await tester.pumpAndSettle();

    notifications.taps.tap(payload(accountId: activeAccountId(tester)));
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.taskEdit(7));
    expect(find.byType(TaskEditPage), findsOneWidget);
    expect(sheet, findsOneWidget);
    expect(find.text(en.taskEditDiscardTitle), findsNothing);
    expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
  });

  testWidgets('a tap over the add-account screen keeps it', (tester) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);
    unawaited(routerOf(tester).push(AppRoutes.addAccount));
    await tester.pumpAndSettle();

    notifications.taps.tap(payload(accountId: activeAccountId(tester)));
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.addAccount);
    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(sheet, findsOneWidget);
  });

  testWidgets('two taps in quick succession open the last one', (tester) async {
    data.tasks.all = [
      sampleTask(id: 7, title: 'Water the plants'),
      sampleTask(id: 8, title: 'Buy milk'),
    ];
    await pumpSignedInApp(tester, sync: data, notifications: notifications);

    notifications.taps
      ..tap(payload(accountId: activeAccountId(tester)))
      ..tap(
        payload(accountId: activeAccountId(tester), taskId: 8, key: '8:due'),
      );
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Buy milk')),
      findsOneWidget,
    );
  });

  testWidgets('the notification that launched the app waits for the shell', (
    tester,
  ) async {
    final auth = AuthFakes();
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    notifications.taps.launchedWith = payload(accountId: entry.id);
    final sync = SyncFakes(status: const SyncNeverRun());
    sync.projects.all = data.projects.all;
    sync.tasks.all = data.tasks.all;
    final firstSync = Completer<void>();
    sync.engine.onEnsureInitialSync = () => firstSync.future;
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: sync,
      notifications: notifications,
      settle: false,
    );
    await pumpUntil(tester, find.byType(FirstSyncScreen));
    await pumpFrames(tester, 3);
    expect(sheet, findsNothing);

    firstSync.complete();
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(sheet, findsOneWidget);
  });

  testWidgets('a tap for another account switches to it first', (tester) async {
    final accounts = ThreeAccounts();
    await accounts.seed();
    accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
    accounts.bobData.tasks.all = [
      sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
    ];
    await accounts.pump(tester, notifications: notifications);
    expect(activeAccountId(tester), accounts.alice.id);

    notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
    await tester.pumpAndSettle();

    expect(activeAccountId(tester), accounts.bob.id);
    expect(location(tester), AppRoutes.overview);
    expect(
      find.descendant(of: sheet, matching: find.text('Mow the lawn')),
      findsOneWidget,
    );
  });

  testWidgets('a tap for another account waits until the switch has reached '
      'the shell', (tester) async {
    final accounts = ThreeAccounts();
    await accounts.seed();
    accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
    accounts.bobData.tasks.all = [
      sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
    ];
    // A switcher over its own registry instance: the switch succeeds, but
    // the providers hear of it only when the test's write below emits.
    await accounts.pump(
      tester,
      notifications: notifications,
      overrides: [
        accountSwitcherProvider.overrideWith(
          (ref) => AccountSwitcher(
            registry: AccountRegistry(accounts.auth.preferences),
            prepare: (accountId) => prepareSyncStatus(ref.container, accountId),
            busy: () => false,
          ),
        ),
      ],
    );

    notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
    await pumpFrames(tester, 5);
    expect(activeAccountId(tester), accounts.alice.id);
    expect(sheet, findsNothing);

    await containerOf(tester)
        .read(accountRegistryProvider)
        .setActive(accounts.bob.id);
    await tester.pumpAndSettle();

    expect(activeAccountId(tester), accounts.bob.id);
    expect(location(tester), AppRoutes.overview);
    expect(
      find.descendant(of: sheet, matching: find.text('Mow the lawn')),
      findsOneWidget,
    );
  });

  testWidgets('a switch refused during a sign-in drops the tap', (
    tester,
  ) async {
    final accounts = ThreeAccounts();
    await accounts.seed(bobNeedsReauth: true);
    accounts.bobData.tasks.all = [
      sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
    ];
    accounts.auth.webAuthenticator.handler = (_, _) => Completer<Uri?>().future;
    await accounts.pump(tester, notifications: notifications);
    unawaited(
      containerOf(tester)
          .read(signInControllerProvider.notifier)
          .signInAgain(accounts.bob),
    );
    await tester.pump();

    notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
    await tester.pump();
    await tester.pump();

    expect(activeAccountId(tester), accounts.alice.id);
    expect(sheet, findsNothing);
  });

  testWidgets('a task that is gone is reported', (tester) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);

    notifications.taps.tap(
      payload(accountId: activeAccountId(tester), taskId: 99),
    );
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(find.text(en.notificationTaskGone), findsOneWidget);
  });

  testWidgets('a test notification closes an open sheet and opens the '
      'Account tab', (tester) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);
    notifications.taps.tap(payload(accountId: activeAccountId(tester)));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);

    notifications.taps.tap(
      payload(
        accountId: activeAccountId(tester),
        taskId: testNotificationTaskId,
        key: 'test',
      ),
    );
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(location(tester), AppRoutes.account);
    expect(find.byType(AccountTab), findsOneWidget);
    expect(find.text(en.notificationTestReceived), findsNothing);
  });

  testWidgets('a test notification tapped on the Account tab says so', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);
    await openTab(tester, en.tabAccount);

    notifications.taps.tap(
      payload(
        accountId: activeAccountId(tester),
        taskId: testNotificationTaskId,
        key: 'test',
      ),
    );
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.account);
    expect(find.text(en.notificationTestReceived), findsOneWidget);
  });

  testWidgets('an unknown account and a broken payload are dropped', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);

    notifications.taps
      ..tap(payload(accountId: 'nobody'))
      ..tap('{"account": 1}')
      ..tap('not json');
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(location(tester), AppRoutes.overview);
    expect(tester.takeException(), isNull);
  });

  group('activity', () {
    ServerNotification comment({int id = 5, int taskId = 7, int? commentId}) =>
        inboxNotification(
          id: id,
          name: 'task.comment',
          created: DateTime.now(),
          payload: {
            'doer': payloadUser(id: 2, username: 'anna', name: 'Anna'),
            'task': payloadTask(id: taskId, title: 'Water the plants'),
            if (commentId != null)
              'comment': {'id': commentId, 'comment': '<p>Done</p>'},
          },
        );

    testWidgets('a tap marks it read and opens its task', (tester) async {
      data.activity.notifications = [comment()];
      await pumpSignedInApp(tester, sync: data, notifications: notifications);

      notifications.taps.tap(
        payload(accountId: activeAccountId(tester), key: 'activity:5'),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [5]);
      expect(data.activity.unreadCount, 0);
      expect(location(tester), AppRoutes.overview);
      expect(
        find.descendant(of: sheet, matching: find.text('Water the plants')),
        findsOneWidget,
      );
    });

    testWidgets('a tap on a comment opens its task at the comment the '
        'stored notification names', (tester) async {
      data.activity.notifications = [comment(commentId: 12)];
      await pumpSignedInApp(tester, sync: data, notifications: notifications);

      notifications.taps.tap(
        payload(accountId: activeAccountId(tester), key: 'activity:5'),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [5]);
      final shown = tester.widget<TaskDetailSheet>(sheet);
      expect(shown.task.title, 'Water the plants');
      expect(shown.commentId, 12);
    });

    testWidgets('a reminder tap and an activity this device no longer has '
        'open the task without a comment', (tester) async {
      await pumpSignedInApp(tester, sync: data, notifications: notifications);

      notifications.taps.tap(
        payload(accountId: activeAccountId(tester), key: 'activity:5'),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TaskDetailSheet>(sheet).commentId, isNull);
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();

      notifications.taps.tap(payload(accountId: activeAccountId(tester)));
      await tester.pumpAndSettle();
      expect(tester.widget<TaskDetailSheet>(sheet).commentId, isNull);
    });

    testWidgets('a tap without a task marks it read and opens the inbox', (
      tester,
    ) async {
      await pumpSignedInApp(tester, sync: data, notifications: notifications);

      notifications.taps.tap(
        payload(
          accountId: activeAccountId(tester),
          taskId: 0,
          key: 'activity:6',
        ),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [6]);
      expect(location(tester), AppRoutes.inbox);
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text(en.notificationTestReceived), findsNothing);
    });

    testWidgets('a tap for a task that is not on this device says so', (
      tester,
    ) async {
      await pumpSignedInApp(tester, sync: data, notifications: notifications);

      notifications.taps.tap(
        payload(
          accountId: activeAccountId(tester),
          taskId: 99,
          key: 'activity:5',
        ),
      );
      await tester.pumpAndSettle();

      expect(data.activity.markedRead, [5]);
      expect(sheet, findsNothing);
      expect(find.text(en.inboxTaskNotLocal), findsOneWidget);
    });

    testWidgets('a tap for another account marks it read there after the '
        'switch', (tester) async {
      final accounts = ThreeAccounts();
      await accounts.seed();
      accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
      accounts.bobData.tasks.all = [
        sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
      ];
      accounts.bobData.activity.notifications = [comment(id: 9, taskId: 31)];
      await accounts.pump(tester, notifications: notifications);

      notifications.taps.tap(
        payload(accountId: accounts.bob.id, taskId: 31, key: 'activity:9'),
      );
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.bob.id);
      expect(accounts.bobData.activity.markedRead, [9]);
      expect(accounts.aliceData.activity.markedRead, isEmpty);
      expect(
        find.descendant(of: sheet, matching: find.text('Mow the lawn')),
        findsOneWidget,
      );
    });
  });

  testWidgets('a session notification switches to its account and opens the '
      'Account tab with the banner', (tester) async {
    final accounts = ThreeAccounts();
    await accounts.seed(bobNeedsReauth: true);
    accounts.aliceData.tasks.all = data.tasks.all;
    await accounts.pump(tester, notifications: notifications);
    notifications.taps.tap(payload(accountId: accounts.alice.id));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);

    notifications.taps.tap(
      payload(
        accountId: accounts.bob.id,
        taskId: 0,
        key: 'session:${accounts.bob.id}',
      ),
    );
    await tester.pumpAndSettle();

    expect(activeAccountId(tester), accounts.bob.id);
    expect(sheet, findsNothing);
    expect(location(tester), AppRoutes.account);
    expect(find.byType(ReauthBanner), findsOneWidget);
    expect(find.text(en.notificationTestReceived), findsNothing);
  });

  testWidgets('a session notification over the edit page with unsaved '
      'changes asks before it drops them', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2200));
    await pumpSignedInApp(
      tester,
      sync: data,
      notifications: notifications,
      overrides: [
        labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    unawaited(routerOf(tester).push(AppRoutes.taskEdit(7)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, en.taskEditTitleLabel),
      'Changed',
    );
    await tester.pumpAndSettle();

    notifications.taps.tap(
      payload(
        accountId: activeAccountId(tester),
        taskId: 0,
        key: 'session:${activeAccountId(tester)}',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
    expect(location(tester), AppRoutes.taskEdit(7));
    expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
  });

  testWidgets('a session notification over a page without changes opens the '
      'Account tab', (tester) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);
    unawaited(routerOf(tester).push(AppRoutes.addAccount));
    await tester.pumpAndSettle();

    notifications.taps.tap(
      payload(
        accountId: activeAccountId(tester),
        taskId: 0,
        key: 'session:${activeAccountId(tester)}',
      ),
    );
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.account);
    expect(find.byType(ConnectServerScreen), findsNothing);
  });

  testWidgets('the notification standing for several opens the inbox', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);

    notifications.taps.tap(
      payload(
        accountId: activeAccountId(tester),
        taskId: 0,
        key: 'inbox:${activeAccountId(tester)}',
      ),
    );
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.inbox);
    expect(data.activity.markedRead, isEmpty);
    expect(find.text(en.notificationTestReceived), findsNothing);
  });

  testWidgets('a session notification tapped on the Account tab stays quiet', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, notifications: notifications);
    await openTab(tester, en.tabAccount);

    notifications.taps.tap(
      payload(
        accountId: activeAccountId(tester),
        taskId: 0,
        key: 'session:${activeAccountId(tester)}',
      ),
    );
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.account);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('signed out the tap is dropped', (tester) async {
    await pumpVikunjaApp(tester, notifications: notifications);

    notifications.taps.tap(payload(accountId: 'someone'));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(sheet, findsNothing);
  });
}
