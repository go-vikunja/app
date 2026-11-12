import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');

final Finder _dialog = find.byWidgetPredicate((w) => w is AlertDialog);

/// tasks.example.org, whose sign-in page is at auth.example.org.
ServerConnection _elsewhere() =>
    accountPagesServer270(frontendUrl: Uri.parse('https://auth.example.org/'));

void main() {
  late AuthFakes auth;

  setUp(() {
    auth = AuthFakes()..serveUser(_alice, now: DateTime.now().toUtc());
  });

  Finder warningTitle(AppLocalizations l10n) =>
      find.text(l10n.signInOtherHostTitle('auth.example.org'));

  void expectWarning(AppLocalizations l10n) {
    expect(warningTitle(l10n), findsOneWidget);
    expect(
      find.text(
        l10n.signInOtherHostBody('tasks.example.org', 'auth.example.org'),
      ),
      findsOneWidget,
    );
  }

  Future<void> answer(WidgetTester tester, String button) async {
    await tester.tap(find.descendant(of: _dialog, matching: find.text(button)));
    await tester.pumpAndSettle();
  }

  Future<void> tapContinueToSignIn(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, en.continueToSignIn);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('first sign-in', () {
    testWidgets("a sign-in page on the server's origin asks nothing", (
      tester,
    ) async {
      await pumpServerOverview(
        tester,
        accountPagesServer270(
          frontendUrl: Uri.parse('https://tasks.example.org/'),
        ),
        auth: auth,
      );

      await tapContinueToSignIn(tester);

      expect(_dialog, findsNothing);
      expect(auth.webAuthenticator.urls, hasLength(1));
    });

    testWidgets('another host asks first; Cancel opens nothing and asks '
        'again, Sign in opens the browser there', (tester) async {
      await pumpServerOverview(tester, _elsewhere(), auth: auth);

      await tapContinueToSignIn(tester);
      expectWarning(en);
      await answer(tester, en.cancel);
      expect(auth.webAuthenticator.urls, isEmpty);
      expect(find.byType(ServerOverviewScreen), findsOneWidget);

      await tapContinueToSignIn(tester);
      expectWarning(en);
      expect(
        find.descendant(
          of: _dialog,
          matching: find.text(en.connectionBrowserHintContinue),
        ),
        findsNothing,
      );
      await answer(tester, en.signInOtherHostConfirm);
      expect(auth.webAuthenticator.urls.single.host, 'auth.example.org');
    });

    testWidgets('is asked in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpServerOverview(tester, _elsewhere(), auth: auth);

      final button = find.widgetWithText(FilledButton, de.continueToSignIn);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expectWarning(de);
      expect(find.text(de.cancel), findsOneWidget);
      expect(find.text(de.signInOtherHostConfirm), findsOneWidget);
    });

    testWidgets('connection settings go into the same question, without '
        'naming the host twice', (tester) async {
      final server = _elsewhere();
      await profilesOver(auth)
          .setHeaders(OriginKey.of(server.rootUri), {'X-Gate-Token': 'dummy'});
      await pumpServerOverview(tester, server, auth: auth);

      await tapContinueToSignIn(tester);

      expectWarning(en);
      expect(find.text(en.connectionBrowserHintHeaders), findsOneWidget);
      expect(find.text(en.connectionBrowserHintTitle), findsNothing);
      expect(
        find.text(en.connectionBrowserHintOtherHost('auth.example.org')),
        findsNothing,
      );
    });

    testWidgets('Create account says it in the question it asks anyway', (
      tester,
    ) async {
      usePhoneSurface(tester, logicalSize: const Size(400, 2400));
      await pumpServerOverview(tester, _elsewhere(), auth: auth);

      await tester.tap(find.text(en.overviewCreateAccount));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${en.signInOtherHostBody('tasks.example.org', 'auth.example.org')}'
          '\n\n${en.overviewCreateAccountHint}',
        ),
        findsOneWidget,
      );
      expect(warningTitle(en), findsNothing);
      await answer(tester, en.cancel);
      expect(auth.webAuthenticator.urls, isEmpty);

      await tester.tap(find.text(en.overviewCreateAccount));
      await tester.pumpAndSettle();
      await answer(tester, en.continueToSignIn);
      expect(auth.webAuthenticator.urls.single.host, 'auth.example.org');
    });
  });

  testWidgets('adding an account asks too', (tester) async {
    await pumpSignedInApp(tester, auth: auth);
    final container = containerOf(tester);
    container.read(currentServerProvider.notifier).select(_elsewhere());
    unawaited(container.read(appRouterProvider).push(AppRoutes.addAccount));
    await tester.pumpAndSettle();
    unawaited(
      container.read(appRouterProvider).push(AppRoutes.addAccountServer),
    );
    await tester.pumpAndSettle();

    await tapContinueToSignIn(tester);

    expectWarning(en);
    await answer(tester, en.cancel);
    expect(auth.webAuthenticator.urls, isEmpty);
  });

  group('signing in again', () {
    /// Alice's session ended on a server whose sign-in page was its own;
    /// negotiated again, it is at auth.example.org.
    Future<void> pumpEnded(
      WidgetTester tester, {
      SyncFakes? sync,
      FakeServerConnector? connector,
      bool settle = true,
    }) async {
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        needsReauth: true,
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: sync ?? SyncFakes(),
        connector: connector ?? FakeServerConnector.succeeding(_elsewhere()),
        settle: settle,
      );
    }

    Future<void> push(WidgetTester tester, String location) async {
      unawaited(containerOf(tester).read(appRouterProvider).push(location));
      await tester.pumpAndSettle();
    }

    testWidgets('from the Account tab asks about the page the new '
        'negotiation gives; Sign in signs in there', (tester) async {
      await pumpEnded(tester);
      await openTab(tester, en.tabAccount);

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await pumpUntil(tester, warningTitle(en));
      expectWarning(en);
      await answer(tester, en.cancel);
      expect(auth.webAuthenticator.urls, isEmpty);
      expect(find.byType(ReauthBanner), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await pumpUntil(tester, warningTitle(en));
      await answer(tester, en.signInOtherHostConfirm);
      expect(auth.webAuthenticator.urls.single.host, 'auth.example.org');
      expect(find.byType(ReauthBanner), findsNothing);
    });

    testWidgets('from the account settings', (tester) async {
      usePhoneSurface(tester);
      await pumpEnded(tester);
      await push(tester, AppRoutes.accountSettings);

      await tester.tap(find.widgetWithText(TextButton, en.reauthAction));
      await pumpUntil(tester, warningTitle(en));

      expectWarning(en);
      await answer(tester, en.cancel);
      expect(auth.webAuthenticator.urls, isEmpty);
    });

    testWidgets('from the avatar page', (tester) async {
      usePhoneSurface(tester);
      await pumpEnded(tester);
      await push(tester, AppRoutes.accountAvatar);

      await tester.tap(find.widgetWithText(TextButton, en.reauthAction));
      await pumpUntil(tester, warningTitle(en));

      expectWarning(en);
      await answer(tester, en.cancel);
      expect(auth.webAuthenticator.urls, isEmpty);
    });

    testWidgets('from a page left during the new negotiation asks nothing '
        'and opens no browser', (tester) async {
      usePhoneSurface(tester);
      final negotiated = Completer<ServerConnection>();
      await pumpEnded(
        tester,
        connector: FakeServerConnector((_) => negotiated.future),
      );
      await push(tester, AppRoutes.accountSettings);

      await tester.tap(find.widgetWithText(TextButton, en.reauthAction));
      await tester.pump();
      await tester.pageBack();
      await pumpFrames(tester, 20);
      expect(find.text(en.accountSettingsSignInAgain), findsNothing);
      negotiated.complete(_elsewhere());
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(auth.webAuthenticator.urls, isEmpty);
      expect(
        containerOf(tester).read(signInControllerProvider),
        isA<SignInIdle>(),
      );
    });

    testWidgets('from the first-sync screen', (tester) async {
      final sync = SyncFakes(status: const SyncNeverRun());
      sync.engine.onEnsureInitialSync = () => Completer<void>().future;
      await pumpEnded(tester, sync: sync, settle: false);
      await pumpUntil(tester, find.byType(ReauthBanner));

      await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
      await pumpUntil(tester, warningTitle(en));

      expectWarning(en);
      await tester.tap(find.text(en.cancel));
      await pumpFrames(tester, 5);
      expect(warningTitle(en), findsNothing);
      expect(auth.webAuthenticator.urls, isEmpty);
    });
  });

  group('every way into the browser sign-in', () {
    final lib = Directory('lib');

    Iterable<(String, String)> sources() => lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map(
          (file) => (
            file.path.substring(lib.path.length + 1),
            file.readAsStringSync(),
          ),
        );

    test('goes through the sign-in controller', () {
      expect(
        [
          for (final (path, source) in sources())
            if (source.contains('browserSignInProvider')) path,
        ]..sort(),
        [
          'core/auth/auth_providers.g.dart',
          'features/session/application/sign_in_controller.dart',
        ],
      );
    });

    // A new caller needs its test in this file.
    test('starts from a screen tested here', () {
      final call = RegExp(r'\.signIn(Again)?\(');
      expect(
        [
          for (final (path, source) in sources())
            if (source.contains('signInControllerProvider.notifier') &&
                call.hasMatch(source))
              path,
        ]..sort(),
        [
          'features/connection/presentation/browser_leg_hint.dart',
          'features/onboarding/presentation/overview/server_overview_screen.dart',
        ],
      );
    });
  });
}
