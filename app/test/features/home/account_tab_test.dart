import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';

void main() {
  late AuthFakes auth;
  late DateTime now;

  setUp(() {
    auth = AuthFakes();
    now = DateTime.now().toUtc();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    ServerConnection? connection,
    bool needsReauth = false,
    String displayName = 'Alice Example',
    FakeServerConnector? connector,
    TokenSet? tokens,
    List<Override> overrides = const [],
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
      overrides: overrides,
    );
    await openTab(tester, en.tabAccount);
  }

  Future<void> tapSignOut(WidgetTester tester) async {
    final button = find.widgetWithText(OutlinedButton, en.homeSignOut);
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
    expect(
      find.text(en.signOutDialogBody('tasks.example.org')),
      findsOneWidget,
    );
    await tester.tap(find.text(en.signOutDialogCancel));
    await tester.pumpAndSettle();

    expect(find.byType(AccountTab), findsOneWidget);
    expect(auth.accountGateway.logoutTokens, isEmpty);
    expect((await auth.registry.load()).accounts, hasLength(1));
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

    await tapSignOut(tester);
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(AccountTab), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
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

      await tapSignOut(tester);
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pumpAndSettle();

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

  group('initialsOf', () {
    test('takes the first letters of the first and last word', () {
      expect(initialsOf('Alice Mary Example'), 'AE');
      expect(initialsOf('  bob  '), 'B');
      expect(initialsOf('élodie durand'), 'ÉD');
      expect(initialsOf('👩‍💻 Dev'), '👩‍💻D');
      expect(initialsOf(''), '?');
    });
  });
}
