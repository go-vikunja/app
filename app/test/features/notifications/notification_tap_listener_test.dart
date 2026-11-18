import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/about/presentation/about_page.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/headers_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/secret_text_field.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/editor_bridge_fakes.dart';
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
  late AuthFakes auth;

  setUp(() {
    auth = _withLinkKey(AuthFakes());
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

  /// As the app's own notifications carry it: with the install's link key.
  String payload({
    required String accountId,
    int taskId = 7,
    String key = '7:due',
    String? linkKey = _linkKey,
  }) => NotificationPayload(
    accountId: accountId,
    taskId: taskId,
    key: key,
    linkKey: linkKey,
  ).toJson();

  final sheet = find.byType(TaskDetailSheet);

  BuildContext rootContext(WidgetTester tester) =>
      routerOf(tester).routerDelegate.navigatorKey.currentContext!;

  /// A sheet whose typed note is asked about before it goes.
  void showNoteSheet(WidgetTester tester, {VoidCallback? onAsk}) =>
      showModalBottomSheet<void>(
        context: rootContext(tester),
        builder: (sheet) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            onAsk?.call();
            final drop = await showDialog<bool>(
              context: sheet,
              builder: (dialog) => AlertDialog(
                title: const Text('Drop the note?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Keep the note'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Drop it'),
                  ),
                ],
              ),
            );
            if ((drop ?? false) && sheet.mounted) Navigator.pop(sheet);
          },
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: TextField(key: Key('note')),
          ),
        ),
      );

  Future<void> typeNote(WidgetTester tester, {VoidCallback? onAsk}) async {
    showNoteSheet(tester, onAsk: onAsk);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note')), 'Half a thought');
    await tester.pumpAndSettle();
  }

  testWidgets('a tap opens the task over the overview', (tester) async {
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );
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
      auth: auth,
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
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );
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
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );

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

  group('a tap over a page outside /home', () {
    final origin = OriginKey.of(Uri.parse('https://vikunja.example.com'));

    Finder plantsTask() =>
        find.descendant(of: sheet, matching: find.text('Water the plants'));

    Future<void> push(WidgetTester tester, String page) async {
      unawaited(routerOf(tester).push(page));
      await tester.pumpAndSettle();
    }

    testWidgets('leaves About and opens the task over the overview', (
      tester,
    ) async {
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );
      await push(tester, AppRoutes.about);

      notifications.taps.tap(payload(accountId: activeAccountId(tester)));
      await tester.pumpAndSettle();

      expect(find.byType(AboutPage), findsNothing);
      expect(location(tester), AppRoutes.overview);
      expect(plantsTask(), findsOneWidget);
    });

    testWidgets("another account's tap leaves About, then switches and "
        'opens the task', (tester) async {
      final accounts = ThreeAccounts();
      _withLinkKey(accounts.auth);
      await accounts.seed();
      accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
      accounts.bobData.tasks.all = [
        sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
      ];
      await accounts.pump(tester, notifications: notifications);
      await push(tester, AppRoutes.about);

      notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
      await tester.pumpAndSettle();

      expect(find.byType(AboutPage), findsNothing);
      expect(activeAccountId(tester), accounts.bob.id);
      expect(location(tester), AppRoutes.overview);
      expect(
        find.descendant(of: sheet, matching: find.text('Mow the lawn')),
        findsOneWidget,
      );
    });

    testWidgets('leaves only Connection: the edit page under it keeps its '
        'unsaved changes under the sheet', (tester) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 2200));
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
        overrides: [
          labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        ],
      );
      await push(tester, AppRoutes.taskEdit(7));
      await tester.enterText(
        find.widgetWithText(TextField, en.taskEditTitleLabel),
        'Changed',
      );
      await tester.pumpAndSettle();
      await push(tester, AppRoutes.connectionFor(origin));
      expect(find.byType(ConnectionPage), findsOneWidget);

      notifications.taps.tap(payload(accountId: activeAccountId(tester)));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionPage), findsNothing);
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(location(tester), AppRoutes.taskEdit(7));
      expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
      expect(plantsTask(), findsOneWidget);
    });

    testWidgets('a Connection editor stays with what was typed, as it '
        'would not ask; the task opens once the user is back under /home', (
      tester,
    ) async {
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );
      await push(tester, AppRoutes.connectionFor(origin));
      await push(
        tester,
        AppRoutes.connectionFor(origin, editor: ConnectionEditor.headers),
      );
      const typed = 'dummy-client-secret';
      await tester.enterText(
        find
            .descendant(
              of: find.byType(SecretTextField).last,
              matching: find.byType(TextField),
            )
            .first,
        typed,
      );
      await tester.pumpAndSettle();

      notifications.taps.tap(payload(accountId: activeAccountId(tester)));
      await tester.pumpAndSettle();

      expect(find.byType(HeadersPage), findsOneWidget);
      expect(find.widgetWithText(TextField, typed), findsOneWidget);
      expect(sheet, findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HeadersPage), findsNothing);
      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(sheet, findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.overview);
      expect(plantsTask(), findsOneWidget);
    });

    testWidgets('a sheet over Connection asks; keeping it keeps the tap '
        'until the user is back under /home, then the task opens', (
      tester,
    ) async {
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );
      await push(tester, AppRoutes.connectionFor(origin));
      await typeNote(tester);

      notifications.taps.tap(payload(accountId: activeAccountId(tester)));
      await tester.pumpAndSettle();
      expect(find.text('Drop the note?'), findsOneWidget);
      await tester.tap(find.text('Keep the note'));
      await tester.pumpAndSettle();

      expect(find.text('Drop the note?'), findsNothing);
      expect(find.widgetWithText(TextField, 'Half a thought'), findsOneWidget);
      expect(location(tester), AppRoutes.connection);
      expect(sheet, findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drop it'));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(sheet, findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.overview);
      expect(plantsTask(), findsOneWidget);

      // Kept only until then: a later tap leaves a page again.
      await push(tester, AppRoutes.about);
      notifications.taps.tap(payload(accountId: activeAccountId(tester)));
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsNothing);
      expect(plantsTask(), findsOneWidget);
    });

    testWidgets('a second tap during the question asks nothing more; the '
        'last tap opens once the page is left', (tester) async {
      data.tasks.all = [
        sampleTask(id: 7, title: 'Water the plants'),
        sampleTask(id: 8, title: 'Buy milk'),
      ];
      var asked = 0;
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );
      await push(tester, AppRoutes.connectionFor(origin));
      await typeNote(tester, onAsk: () => asked++);

      notifications.taps.tap(payload(accountId: activeAccountId(tester)));
      await tester.pumpAndSettle();
      notifications.taps.tap(
        payload(accountId: activeAccountId(tester), taskId: 8, key: '8:due'),
      );
      await tester.pumpAndSettle();
      expect(asked, 1);

      await tester.tap(find.text('Drop it'));
      await tester.pumpAndSettle();

      expect(asked, 1);
      expect(find.byType(ConnectionPage), findsNothing);
      expect(
        find.descendant(of: sheet, matching: find.text('Buy milk')),
        findsOneWidget,
      );
    });

    testWidgets('over the first sync the tap waits for the shell and '
        'Connection stays meanwhile', (tester) async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
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
      unawaited(routerOf(tester).push(AppRoutes.connectionFor(origin)));
      await pumpFrames(tester, 10);
      expect(find.byType(ConnectionPage), findsOneWidget);

      notifications.taps.tap(payload(accountId: entry.id));
      await pumpFrames(tester, 10);
      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(sheet, findsNothing);

      firstSync.complete();
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.overview);
      expect(plantsTask(), findsOneWidget);
    });

    testWidgets('signed out the tap is dropped and About stays', (
      tester,
    ) async {
      await pumpVikunjaApp(tester, notifications: notifications);
      await push(tester, AppRoutes.about);

      notifications.taps.tap(payload(accountId: 'someone'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutPage), findsOneWidget);
      expect(sheet, findsNothing);
    });
  });

  testWidgets('a tap for another account switches to it first', (tester) async {
    final accounts = ThreeAccounts();
    _withLinkKey(accounts.auth);
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
    _withLinkKey(accounts.auth);
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
    _withLinkKey(accounts.auth);
    await accounts.seed(bobNeedsReauth: true);
    accounts.bobData.tasks.all = [
      sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
    ];
    accounts.auth.webAuthenticator.handler = (_, _) => Completer<Uri?>().future;
    await accounts.pump(tester, notifications: notifications);
    unawaited(
      containerOf(tester)
          .read(signInControllerProvider.notifier)
          .signInAgain(accounts.bob, confirm: (_) async => true),
    );
    await tester.pump();

    notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
    await tester.pump();
    await tester.pump();

    expect(activeAccountId(tester), accounts.alice.id);
    expect(sheet, findsNothing);
  });

  // The switch would remove the pages over the shell without asking.
  group('a tap for another account over a page that covers the shell', () {
    late ThreeAccounts accounts;
    late FakeEditorBridges bridges;

    setUp(() async {
      accounts = ThreeAccounts();
      _withLinkKey(accounts.auth);
      await accounts.seed();
      accounts.aliceData.projects.all = data.projects.all;
      accounts.aliceData.tasks.all = data.tasks.all;
      accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
      accounts.bobData.tasks.all = [
        sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
      ];
      bridges = FakeEditorBridges();
    });

    Future<void> pumpAndEditTitle(
      WidgetTester tester, {
      bool switcherBusy = false,
    }) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 2200));
      await accounts.pump(
        tester,
        notifications: notifications,
        overrides: [
          bridges.override,
          if (switcherBusy)
            accountSwitcherProvider.overrideWith(
              (ref) => AccountSwitcher(
                registry: ref.watch(accountRegistryProvider),
                prepare: (_) async {},
                busy: () => true,
              ),
            ),
        ],
      );
      unawaited(routerOf(tester).push(AppRoutes.taskEdit(7)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, en.taskEditTitleLabel),
        'Changed',
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapForBob(WidgetTester tester) async {
      notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
      await tester.pumpAndSettle();
    }

    Finder bobsTask() =>
        find.descendant(of: sheet, matching: find.text('Mow the lawn'));

    testWidgets('with unsaved changes asks first; Keep editing keeps the '
        'page, its text and the account, and drops the tap', (tester) async {
      await pumpAndEditTitle(tester);

      await tapForBob(tester);
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(activeAccountId(tester), accounts.alice.id);

      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();
      expect(activeAccountId(tester), accounts.alice.id);
      expect(location(tester), AppRoutes.taskEdit(7));
      expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
      expect(sheet, findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();
      expect(activeAccountId(tester), accounts.alice.id);
      expect(location(tester), AppRoutes.overview);
      expect(sheet, findsNothing);
    });

    testWidgets('Discard lets the switch go on', (tester) async {
      await pumpAndEditTitle(tester);

      await tapForBob(tester);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.bob.id);
      expect(location(tester), AppRoutes.overview);
      expect(find.byType(TaskEditPage), findsNothing);
      expect(bobsTask(), findsOneWidget);
      expect(accounts.aliceData.tasks.writes, isEmpty);
    });

    testWidgets('each page asks in turn: Save in the description editor '
        'saves, Discard on the edit page under it, then the switch goes on', (
      tester,
    ) async {
      await pumpAndEditTitle(tester);
      unawaited(routerOf(tester).push(AppRoutes.taskDescription(7)));
      await tester.pumpAndSettle();
      bridges.last.edit('<p>Edited</p>');
      await tester.pump();

      await tapForBob(tester);
      expect(find.text(en.descriptionEditorLeaveTitle), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.taskEditSave),
        ),
      );
      await tester.pumpAndSettle();
      expect(accounts.aliceData.tasks.descriptionUpdates, [
        (7, '<p>Edited</p>', ''),
      ]);
      expect(location(tester), AppRoutes.taskEdit(7));
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(activeAccountId(tester), accounts.alice.id);

      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.bob.id);
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(bobsTask(), findsOneWidget);
    });

    testWidgets('without changes nothing is asked', (tester) async {
      await accounts.pump(tester, notifications: notifications);
      unawaited(routerOf(tester).push(AppRoutes.taskEdit(7)));
      await tester.pumpAndSettle();

      await tapForBob(tester);

      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(activeAccountId(tester), accounts.bob.id);
      expect(find.byType(TaskEditPage), findsNothing);
      expect(bobsTask(), findsOneWidget);
    });

    testWidgets('while a sign-in or sign-out runs nothing is asked: the '
        'switch would be refused anyway', (tester) async {
      await pumpAndEditTitle(tester, switcherBusy: true);

      await tapForBob(tester);

      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(activeAccountId(tester), accounts.alice.id);
      expect(location(tester), AppRoutes.taskEdit(7));
      expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
    });

    testWidgets('two pages at the same location both go', (tester) async {
      await accounts.pump(tester, notifications: notifications);
      for (var page = 0; page < 2; page++) {
        unawaited(routerOf(tester).push(AppRoutes.privacy));
        await tester.pumpAndSettle();
      }

      await tapForBob(tester);

      expect(activeAccountId(tester), accounts.bob.id);
      expect(location(tester), AppRoutes.overview);
      expect(bobsTask(), findsOneWidget);
    });

    testWidgets('a sheet over the page asks through its PopScope; keeping it '
        'refuses the switch with the sheet, its text and the page kept', (
      tester,
    ) async {
      await pumpAndEditTitle(tester);
      await typeNote(tester);

      await tapForBob(tester);
      expect(find.text('Drop the note?'), findsOneWidget);
      await tester.tap(find.text('Keep the note'));
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.alice.id);
      expect(find.widgetWithText(TextField, 'Half a thought'), findsOneWidget);
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(location(tester), AppRoutes.taskEdit(7));
      expect(bobsTask(), findsNothing);
    });

    testWidgets('once the sheet over the page is left, the page asks in '
        'turn', (tester) async {
      await pumpAndEditTitle(tester);
      await typeNote(tester);

      await tapForBob(tester);
      await tester.tap(find.text('Drop it'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note')), findsNothing);
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.bob.id);
      expect(bobsTask(), findsOneWidget);
    });

    testWidgets('a sheet that would not ask closes at once, never showing '
        "the next account's data", (tester) async {
      await accounts.pump(tester, notifications: notifications);
      showModalBottomSheet<void>(
        context: rootContext(tester),
        builder: (_) => Consumer(
          builder: (context, ref, _) =>
              Text('Sheet of ${ref.watch(activeAccountIdProvider)}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sheet of ${accounts.alice.id}'), findsOneWidget);

      notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.text('Sheet of ${accounts.bob.id}'), findsNothing);
      }
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.bob.id);
      expect(bobsTask(), findsOneWidget);
    });

    testWidgets("the description editor's offer of a draft refuses the "
        'switch and keeps the draft', (tester) async {
      await accounts.pump(
        tester,
        notifications: notifications,
        overrides: [bridges.override],
      );
      final drafts = containerOf(tester).read(descriptionDraftsProvider);
      await drafts.save(
        const DescriptionDraft(html: '<p>Draft</p>', base: ''),
        account: accounts.alice.id,
        target: const TaskDescriptionTarget(7),
      );
      unawaited(routerOf(tester).push(AppRoutes.taskDescription(7)));
      await pumpFrames(tester, 10);
      expect(find.text(en.descriptionEditorRestoreTitle), findsOneWidget);

      notifications.taps.tap(payload(accountId: accounts.bob.id, taskId: 31));
      await pumpFrames(tester, 10);

      expect(find.text(en.descriptionEditorRestoreTitle), findsOneWidget);
      expect(activeAccountId(tester), accounts.alice.id);
      expect(
        (await drafts.read(
          account: accounts.alice.id,
          target: const TaskDescriptionTarget(7),
        ))?.html,
        '<p>Draft</p>',
      );
      await tester.tap(find.text(en.descriptionEditorRestore));
      await tester.pumpAndSettle();
      expect(bridges.last.init!.html, '<p>Draft</p>');
      expect(activeAccountId(tester), accounts.alice.id);
      expect(bobsTask(), findsNothing);
    });
  });

  testWidgets('a task that is gone is reported', (tester) async {
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );

    notifications.taps.tap(
      payload(accountId: activeAccountId(tester), taskId: 99),
    );
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(find.text(en.notificationTaskGone), findsOneWidget);
  });

  testWidgets('a test notification closes an open sheet and opens the '
      'Account tab', (tester) async {
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );
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
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );
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
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );

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
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );

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
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );

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
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );

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
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );

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
      await pumpSignedInApp(
        tester,
        auth: auth,
        sync: data,
        notifications: notifications,
      );

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
      _withLinkKey(accounts.auth);
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
    _withLinkKey(accounts.auth);
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

  testWidgets('a reminder to open the app before a session ends only opens '
      'it: no switch, the sheet and the tab stay', (tester) async {
    final accounts = ThreeAccounts();
    _withLinkKey(accounts.auth);
    await accounts.seed();
    accounts.aliceData.tasks.all = data.tasks.all;
    await accounts.pump(tester, notifications: notifications);
    notifications.taps.tap(payload(accountId: accounts.alice.id));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    final before = location(tester);

    for (final linkKey in [_linkKey, null]) {
      for (final accountId in [accounts.alice.id, accounts.bob.id]) {
        notifications.taps.tap(
          payload(
            accountId: accountId,
            taskId: 0,
            key: SessionReminders.key(accountId),
            linkKey: linkKey,
          ),
        );
        await tester.pumpAndSettle();
      }
    }

    expect(activeAccountId(tester), accounts.alice.id);
    expect(sheet, findsOneWidget);
    expect(location(tester), before);
    expect(find.text(en.notificationTestReceived), findsNothing);
  });

  testWidgets('a session notification over the edit page with unsaved '
      'changes asks before it drops them', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2200));
    await pumpSignedInApp(
      tester,
      auth: auth,
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
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );
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
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );

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
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
    );
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

  // On Android any app can send MainActivity a tap with a payload it made
  // up; notifications scheduled before the key existed carry none either.
  group('without the link key', () {
    late ThreeAccounts accounts;

    setUp(() async {
      accounts = ThreeAccounts();
      _withLinkKey(accounts.auth);
      await accounts.seed(bobNeedsReauth: true);
      accounts.aliceData.tasks.all = data.tasks.all;
      accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
      accounts.bobData.tasks.all = [
        sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
      ];
      accounts.bobData.activity.notifications = [
        inboxNotification(
          id: 9,
          name: 'task.comment',
          created: DateTime.now(),
          payload: {
            'doer': payloadUser(id: 2, username: 'anna', name: 'Anna'),
            'task': payloadTask(id: 31, title: 'Mow the lawn'),
          },
        ),
      ];
    });

    for (final (name, linkKey) in [
      ('none', null),
      ('a wrong one', _otherLinkKey),
    ]) {
      testWidgets("with $name, another account's task asks before it "
          'switches and marks nothing read', (tester) async {
        await accounts.pump(tester, notifications: notifications);

        notifications.taps.tap(
          payload(
            accountId: accounts.bob.id,
            taskId: 31,
            key: 'activity:9',
            linkKey: linkKey,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccountPickerSheet), findsOneWidget);
        expect(activeAccountId(tester), accounts.alice.id);
        expect(accounts.bobData.activity.markedRead, isEmpty);
        expect(sheet, findsNothing);
      });
    }

    testWidgets("another account's session, inbox and test notifications "
        'open nothing', (tester) async {
      await accounts.pump(tester, notifications: notifications);
      await openTab(tester, en.tabUpcoming);
      final bob = accounts.bob.id;

      for (final (taskId, key) in [
        (0, ActivityTray.sessionKey(bob)),
        (0, ActivityTray.activityKey(9)),
        (0, ActivityTray.moreKey(bob)),
        (testNotificationTaskId, 'test'),
      ]) {
        notifications.taps.tap(
          payload(accountId: bob, taskId: taskId, key: key, linkKey: null),
        );
        await tester.pumpAndSettle();
      }

      expect(activeAccountId(tester), accounts.alice.id);
      expect(location(tester), AppRoutes.upcoming);
      expect(accounts.bobData.activity.markedRead, isEmpty);
      expect(find.byType(AccountPickerSheet), findsNothing);
    });

    testWidgets('in the active account a task opens without asking and the '
        'test notification still answers', (tester) async {
      await accounts.pump(tester, notifications: notifications);
      final alice = accounts.alice.id;

      notifications.taps.tap(payload(accountId: alice, linkKey: null));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPickerSheet), findsNothing);
      expect(
        find.descendant(of: sheet, matching: find.text('Water the plants')),
        findsOneWidget,
      );

      notifications.taps.tap(
        payload(
          accountId: alice,
          taskId: testNotificationTaskId,
          key: 'test',
          linkKey: null,
        ),
      );
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.account);
    });
  });
}

/// The install's widget-link key in these tests (32 bytes 0…31).
const String _linkKey = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
const String _otherLinkKey = 'HxwdHhcYGRoTFBUWDxAREgsMDQ4HCAkKAwQFBgABAgM';

AuthFakes _withLinkKey(AuthFakes auth) =>
    auth..preferences.values[widgetLinkKeyPreference] = _linkKey;
