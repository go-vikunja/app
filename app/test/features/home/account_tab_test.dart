import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

final String aliceSignOutBody = en.signOutDialogBody(
  en.signOutDialogAccount('Alice Example', 'alice'),
  'tasks.example.org',
);

void main() {
  late AuthFakes auth;
  late SyncFakes data;
  late DateTime now;

  setUp(() {
    auth = AuthFakes();
    now = DateTime.now().toUtc();
    data = SyncFakes(now: now);
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    ServerConnection? connection,
    bool needsReauth = false,
    String displayName = 'Alice Example',
    FakeServerConnector? connector,
    TokenSet? tokens,
    List<Override> overrides = const [],
    String? tabLabel,
  }) async {
    await auth.seedAccount(
      connection ?? fullServer270(),
      tokens: tokens ?? issueTokens(issuedAt: now),
      displayName: displayName,
      needsReauth: needsReauth,
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      connector: connector,
      sync: data,
      overrides: [clockProvider.overrideWithValue(() => now), ...overrides],
    );
    await openTab(tester, tabLabel ?? en.tabAccount);
  }

  /// The Accounts section pushes the sync section below the fold.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
  }

  /// [label] is the button's text, which differs with other accounts left.
  Future<void> tapSignOut(WidgetTester tester, {String? label}) async {
    final button = find.widgetWithText(OutlinedButton, label ?? en.homeSignOut);
    await tester.scrollUntilVisible(
      button,
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // The scroll lays out on the next frame.
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('shows who is signed in on which server', (tester) async {
    await pumpHome(tester);

    expect(find.text(en.tabAccount), findsAtLeast(1));
    expect(find.text('AE'), findsOneWidget);
    expect(find.text('Alice Example'), findsOneWidget);
    expect(find.text(en.homeUsername('alice')), findsOneWidget);
    expect(find.text('tasks.example.org'), findsOneWidget);
    expect(find.text(en.overviewVikunjaVersion('2.7.0')), findsOneWidget);
    expect(find.byType(ReauthBanner), findsNothing);
  });

  testWidgets('without a separate name the username is shown once', (
    tester,
  ) async {
    await pumpHome(tester, displayName: 'alice');

    expect(find.text('alice'), findsOneWidget);
    expect(find.text(en.homeUsername('alice')), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('the name is a heading and the avatar is not announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester);

    expect(
      tester.getSemantics(find.text('Alice Example')),
      matchesSemantics(label: 'Alice Example', isHeader: true),
    );
    expect(find.bySemanticsLabel('AE'), findsNothing);
    semantics.dispose();
  });

  testWidgets('cancelling the sign-out dialog keeps the account', (
    tester,
  ) async {
    await pumpHome(tester);

    await tapSignOut(tester);
    expect(find.text(en.signOutDialogTitle), findsOneWidget);
    expect(find.text(aliceSignOutBody), findsOneWidget);
    await tester.tap(find.text(en.signOutDialogCancel));
    await tester.pumpAndSettle();

    expect(find.byType(AccountTab), findsOneWidget);
    expect(auth.accountGateway.logoutTokens, isEmpty);
    expect((await auth.registry.load()).accounts, hasLength(1));
  });

  testWidgets('the sign-out dialog warns about changes not sent yet', (
    tester,
  ) async {
    data.tasks.pendingChanges = 2;
    await pumpHome(tester);

    await tapSignOut(tester);

    expect(
      find.text('$aliceSignOutBody ${en.signOutDialogPendingChanges(2)}'),
      findsOneWidget,
    );
  });

  testWidgets('signing out returns to the connect screen', (tester) async {
    await pumpHome(tester);

    await tapSignOut(tester);
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(auth.accountGateway.logoutTokens, hasLength(1));
    expect(auth.secureStore.values, isEmpty);
    expect((await auth.registry.load()).accounts, isEmpty);
  });

  testWidgets('signing out stops the sync and deletes the local database', (
    tester,
  ) async {
    await pumpHome(tester);
    final accountId = (await auth.registry.load()).activeAccountId;

    await tapSignOut(tester);
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    expect(data.engine.disposed, isTrue);
    expect(data.files.deleted, [accountId]);
  });

  group('sync status', () {
    testWidgets('shows when the account was last synced and syncs on demand', (
      tester,
    ) async {
      data = SyncFakes(
        now: now,
        status: SyncIdle(
          lastSyncedAt: now.subtract(const Duration(seconds: 50)),
        ),
      );
      final run = Completer<void>();
      data.engine.onRefresh = () => run.future;
      await pumpHome(tester);

      expect(find.text(en.accountLastSynced('1 minute ago')), findsOneWidget);
      expect(data.engine.refreshCalls, 0);

      await tester.tap(find.text(en.accountSyncNow));
      await tester.pump();

      expect(data.engine.refreshCalls, 1);
      expect(find.text(en.accountSyncing), findsOneWidget);
      expect(find.text(en.syncPhaseAccount), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.accountSyncing),
      );
      expect(button.onPressed, isNull);

      run.complete();
      await tester.pumpAndSettle();
      expect(find.text(en.accountLastSyncedJustNow), findsOneWidget);
      expect(find.text(en.accountSyncNow), findsOneWidget);
    });

    testWidgets('"Sync now" rests for a session that needs a new sign-in', (
      tester,
    ) async {
      await pumpHome(tester, needsReauth: true);
      await scrollTo(tester, find.text(en.accountSyncNow));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.accountSyncNow),
      );
      expect(button.onPressed, isNull);
      expect(data.engine.refreshCalls, 0);
    });

    testWidgets('"Full resync" pulls everything again and rests, like '
        '"Sync now", while it runs', (tester) async {
      final run = Completer<void>();
      data.engine.onFullResync = () => run.future;
      await pumpHome(tester);

      await tester.tap(find.text(en.accountFullResync));
      await tester.pump();

      expect(data.engine.fullResyncCalls, 1);
      expect(data.engine.refreshCalls, 0);
      expect(find.text(en.accountSyncing), findsOneWidget);
      expect(find.text(en.syncPhaseAccount), findsOneWidget);
      TextButton fullResync() => tester.widget<TextButton>(
        find.widgetWithText(TextButton, en.accountFullResync),
      );
      expect(fullResync().onPressed, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, en.accountSyncing),
            )
            .onPressed,
        isNull,
      );

      run.complete();
      await tester.pumpAndSettle();
      expect(find.text(en.accountLastSyncedJustNow), findsOneWidget);
      expect(fullResync().onPressed, isNotNull);
    });

    testWidgets('"Full resync" rests for a session that needs a new sign-in', (
      tester,
    ) async {
      await pumpHome(tester, needsReauth: true);
      await scrollTo(tester, find.text(en.accountFullResync));

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, en.accountFullResync),
      );
      expect(button.onPressed, isNull);
      expect(data.engine.fullResyncCalls, 0);
    });

    testWidgets('"Sync now" rests while signing out', (tester) async {
      final logout = Completer<void>();
      auth.accountGateway.onLogout = (_) => logout.future;
      await pumpHome(tester);

      await tapSignOut(tester);
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.accountSyncNow),
      );
      expect(button.onPressed, isNull);

      logout.complete();
      await tester.pumpAndSettle();
      expect(data.engine.refreshCalls, 0);
    });

    testWidgets('a failed sync is explained next to the last success', (
      tester,
    ) async {
      data = SyncFakes(
        now: now,
        status: SyncFailed(
          failure: const ServerFailure(502),
          lastSyncedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      data.engine.onRefresh = () async => throw const ServerFailure(502);
      await pumpHome(tester);

      // The quiet sync at start retried and failed again.
      expect(data.engine.refreshCalls, 1);
      expect(find.text(en.accountSyncFailed), findsOneWidget);
      expect(
        find.text(en.failureUnavailableExplanation('tasks.example.org')),
        findsOneWidget,
      );
      expect(find.text(en.accountLastSynced('2 days ago')), findsOneWidget);
    });

    testWidgets('a run is announced once, not per phase, a failure when it '
        'appears, and the time that ticks every minute not at all', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      usePhoneSurface(tester);
      data = SyncFakes(
        now: now,
        status: SyncFailed(
          failure: const ServerFailure(502),
          lastSyncedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      data.engine.onRefresh = () async => throw const ServerFailure(502);
      await pumpHome(tester);

      bool inLiveRegion(Finder finder) {
        for (
          SemanticsNode? node = tester.getSemantics(finder);
          node != null;
          node = node.parent
        ) {
          if (node.flagsCollection.isLiveRegion) return true;
        }
        return false;
      }

      expect(inLiveRegion(find.text(en.accountSyncFailed)), isTrue);
      expect(
        inLiveRegion(find.text(en.accountLastSynced('2 days ago'))),
        isFalse,
      );

      final run = Completer<void>();
      data.engine.onRefresh = () => run.future;
      await scrollTo(tester, find.text(en.accountSyncNow));
      await tester.tap(find.text(en.accountSyncNow));
      await tester.pump();

      final announced = tester.getSemantics(find.text(en.syncPhaseAccount));
      expect(announced.flagsCollection.isLiveRegion, isTrue);
      expect(announced.label, en.accountSyncing);

      data.engine.emit(
        const SyncRunning(phase: SyncPhase.labels, done: 0, initial: false),
      );
      await tester.pump();
      expect(find.text(en.syncPhaseLabels), findsOneWidget);
      expect(
        tester.getSemantics(find.text(en.syncPhaseLabels)).label,
        en.accountSyncing,
      );

      run.completeError(const ServerFailure(502));
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('is in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpHome(tester, tabLabel: de.tabAccount);

      expect(find.text(de.accountLastSyncedJustNow), findsOneWidget);
      expect(find.text(de.accountSyncNow), findsOneWidget);
      expect(find.text(de.accountFullResync), findsOneWidget);
    });
  });

  testWidgets('system back cannot close the app while signing out', (
    tester,
  ) async {
    final systemCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        systemCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final logout = Completer<void>();
    auth.accountGateway.onLogout = (_) => logout.future;
    await pumpHome(tester);

    await tapSignOut(tester);
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(systemCalls, isNot(contains('SystemNavigator.pop')));
    expect(find.byType(AccountTab), findsOneWidget);

    logout.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });

  testWidgets('the sign-out dialog marks the destructive action on Android', (
    tester,
  ) async {
    await pumpHome(tester);

    await tapSignOut(tester);

    final confirmFinder = find.widgetWithText(
      TextButton,
      en.signOutDialogConfirm,
    );
    final context = tester.element(confirmFinder);
    final confirm = tester.widget<TextButton>(confirmFinder);
    expect(
      confirm.style?.foregroundColor?.resolve({}),
      Theme.of(context).colorScheme.error,
    );
    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, en.signOutDialogCancel),
    );
    expect(cancel.style, isNull);
  });

  testWidgets('the sign-out dialog is a Cupertino alert on iOS', (
    tester,
  ) async {
    await pumpHome(tester);

    await tapSignOut(tester);

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final confirm = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, en.signOutDialogConfirm),
    );
    expect(confirm.isDestructiveAction, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('with another account left, signing out switches to it', (
    tester,
  ) async {
    await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      displayName: 'Bob',
      activate: false,
    );
    await pumpHome(tester);

    await tapSignOut(tester, label: en.homeSignOutOfThisAccount);
    expect(
      find.text('$aliceSignOutBody ${en.signOutDialogSwitchesTo('Bob')}'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    // Like every switch, it starts on the overview.
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.text(en.accountSignedOutOf('Alice Example')), findsOneWidget);
    await openTab(tester, en.tabAccount);
    expect(find.text('Bob'), findsOneWidget);
    await scrollTo(tester, find.text(en.homeSignOut));
    expect(find.text(en.homeSignOut), findsOneWidget);
  });

  group('session check', () {
    Override checkingEveryTime() => sessionCheckProvider.overrideWith(
      (ref) => SessionCheck(
        sessions: ref.watch(sessionManagersProvider),
        accountGateway: ref.watch(accountGatewayProvider),
        minInterval: Duration.zero,
      ),
    );

    testWidgets('a session the server ended shows the banner', (tester) async {
      auth.tokenGateway.onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired, code: 16003);
      await pumpHome(
        tester,
        tokens: issueTokens(issuedAt: now.subtract(const Duration(days: 3))),
      );

      expect(find.byType(ReauthBanner), findsOneWidget);
      expect(find.byType(ConnectionErrorCard), findsNothing);
    });

    testWidgets('an unreachable server changes nothing on screen', (
      tester,
    ) async {
      auth.accountGateway.onCurrentUser = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await pumpHome(tester);

      expect(auth.accountGateway.currentUserTokens, hasLength(1));
      expect(find.byType(ReauthBanner), findsNothing);
      expect(find.byType(ConnectionErrorCard), findsNothing);
    });

    testWidgets('returning to the app checks again', (tester) async {
      auth.serveUser(
        const User(id: 7, username: 'alice', name: 'Alice Example'),
        now: now,
      );
      await pumpHome(tester, overrides: [checkingEveryTime()]);
      expect(auth.accountGateway.currentUserTokens, hasLength(1));

      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pumpAndSettle();

      expect(auth.accountGateway.currentUserTokens, hasLength(2));
    });

    testWidgets('an account that already needs a new sign-in is not checked', (
      tester,
    ) async {
      await pumpHome(tester, needsReauth: true);

      expect(auth.accountGateway.currentUserTokens, isEmpty);
    });
  });

  testWidgets('the banner stays hidden while signing out of a session that '
      'ends during the logout', (tester) async {
    final refresh = Completer<TokenSet>();
    auth.tokenGateway.onRefresh = (_) => refresh.future;
    final deleting = Completer<void>();
    final releaseDelete = Completer<void>();
    auth.secureStore.beforeDelete = (_) {
      if (!deleting.isCompleted) deleting.complete();
      return releaseDelete.future;
    };
    // The session check's refresh is still running when the user signs out.
    await pumpHome(
      tester,
      tokens: issueTokens(issuedAt: now.subtract(const Duration(days: 3))),
    );
    await tapSignOut(tester);
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pump();

    refresh.completeError(
      const SessionEnded(SessionEndReason.expired, code: 16003),
    );
    await tester.pump();
    await tester.pump();
    expect(deleting.isCompleted, isTrue);
    expect(find.text(en.homeSigningOut), findsOneWidget);
    expect(find.byType(ReauthBanner), findsNothing);

    releaseDelete.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });

  group('session ended', () {
    testWidgets('a banner offers to sign in again', (tester) async {
      await pumpHome(tester, needsReauth: true);

      expect(find.byType(ReauthBanner), findsOneWidget);
      expect(find.text(en.reauthTitle), findsOneWidget);
      expect(find.text(en.reauthBody('tasks.example.org')), findsOneWidget);
      expect(find.text('Alice Example'), findsOneWidget);
    });

    testWidgets('signing in again clears the banner', (tester) async {
      final connection = fullServer270();
      auth.serveUser(
        const User(id: 7, username: 'alice', name: 'Alice Example'),
        now: now,
      );
      final connector = FakeServerConnector.succeeding(connection);
      await pumpHome(tester, needsReauth: true, connector: connector);

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await tester.pumpAndSettle();

      expect(connector.inputs, ['https://tasks.example.org/vikunja']);
      expect(auth.webAuthenticator.urls, hasLength(1));
      expect(find.byType(ReauthBanner), findsNothing);
      final active = containerOf(tester).read(accountsProvider).value;
      expect(active?.accounts, hasLength(1));
      expect(active?.activeAccount?.account.needsReauth, isFalse);
    });

    testWidgets('signing in again uses the stored server when it cannot be '
        'reached for negotiation', (tester) async {
      auth.serveUser(
        const User(id: 7, username: 'alice', name: 'Alice Example'),
        now: now,
      );
      final connector = FakeServerConnector((_) async => throw StateError('x'));
      await pumpHome(tester, needsReauth: true, connector: connector);

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await tester.pumpAndSettle();

      expect(find.byType(ReauthBanner), findsNothing);
    });

    testWidgets('a failed attempt is explained and the banner stays', (
      tester,
    ) async {
      final connector = FakeServerConnector.succeeding(fullServer270());
      auth.tokenGateway.onExchange = (_) async =>
          throw const SessionEnded(SessionEndReason.accountDisabled);
      await pumpHome(tester, needsReauth: true, connector: connector);

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await tester.pumpAndSettle();

      expect(find.byType(ReauthBanner), findsOneWidget);
      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      expect(find.text(en.signInAccountDisabledTitle), findsOneWidget);
    });

    testWidgets('signing in as someone else is refused and explained', (
      tester,
    ) async {
      auth.serveUser(const User(id: 8, username: 'bob'), now: now);
      final connector = FakeServerConnector.succeeding(fullServer270());
      await pumpHome(tester, needsReauth: true, connector: connector);

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await tester.pumpAndSettle();

      expect(find.byType(ReauthBanner), findsOneWidget);
      expect(find.text(en.signInDifferentUserTitle), findsOneWidget);
      expect(
        find.text(en.signInDifferentUserExplanation('bob', 'alice')),
        findsOneWidget,
      );
      final registry = containerOf(tester).read(accountsProvider).value;
      expect(registry?.accounts, hasLength(1));
      expect(registry?.activeAccount?.account.username, 'alice');
      expect(registry?.activeAccount?.account.needsReauth, isTrue);
    });

    testWidgets('a failure card does not follow to another account', (
      tester,
    ) async {
      await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        displayName: 'Bob',
        activate: false,
      );
      auth.tokenGateway.onExchange = (_) async =>
          throw const SessionEnded(SessionEndReason.accountDisabled);
      await pumpHome(
        tester,
        needsReauth: true,
        connector: FakeServerConnector.succeeding(fullServer270()),
      );
      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionErrorCard), findsOneWidget);

      await tapSignOut(tester, label: en.homeSignOutOfThisAccount);
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pumpAndSettle();
      await openTab(tester, en.tabAccount);

      expect(find.text('Bob'), findsOneWidget);
      expect(find.byType(ConnectionErrorCard), findsNothing);
    });

    testWidgets('an unreachable server is reported before the browser opens', (
      tester,
    ) async {
      final connection = fullServer270();
      final connector = FakeServerConnector.failing(
        ServerUnreachable(connection.rootUri),
      );
      await pumpHome(tester, needsReauth: true, connector: connector);

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await tester.pumpAndSettle();

      expect(auth.webAuthenticator.urls, isEmpty);
      expect(find.text(en.failureUnreachableTitle), findsOneWidget);
    });
  });
}
