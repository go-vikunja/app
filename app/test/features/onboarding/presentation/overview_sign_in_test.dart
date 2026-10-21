import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');

final Finder _continueButton = find.widgetWithText(
  FilledButton,
  en.continueToSignIn,
);

void main() {
  late AuthFakes auth;

  setUp(() {
    auth = AuthFakes()..serveUser(_alice, now: DateTime.now().toUtc());
  });

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  testWidgets('signing in opens the home screen as that user', (tester) async {
    await pumpServerOverview(tester, fullServer270(), auth: auth);

    await tester.tap(_continueButton);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(HomeShell), findsOneWidget);
    await openTab(tester, en.tabAccount);
    expect(find.text('Alice Example'), findsOneWidget);
    expect(
      find.text(en.accountSubtitle('alice', 'tasks.example.org')),
      findsOneWidget,
    );
    expect(auth.webAuthenticator.schemes, [oauthCallbackScheme]);
    final accounts = containerOf(tester).read(accountsProvider).value;
    expect(accounts?.activeAccount?.account.userId, 7);
  });

  testWidgets('the button shows progress while the browser is open', (
    tester,
  ) async {
    final browser = Completer<Uri?>();
    auth.webAuthenticator.handler = (_, _) => browser.future;
    await pumpServerOverview(tester, oauthServer230(), auth: auth);

    await tester.tap(_continueButton);
    await tester.pump();

    expect(find.text(en.signInWaiting), findsOneWidget);
    expect(_continueButton, findsNothing);
    final otherServer = tester.widget<TextButton>(
      find.widgetWithText(TextButton, en.useDifferentServer),
    );
    expect(otherServer.onPressed, isNull);

    await tester.tap(find.text(en.signInWaiting));
    await tester.pump();
    expect(auth.webAuthenticator.urls, hasLength(1));

    browser.complete(null);
    await tester.pumpAndSettle();
    expect(_continueButton, findsOneWidget);
  });

  testWidgets('back and repeated taps cannot interrupt the token exchange', (
    tester,
  ) async {
    final exchange = Completer<TokenSet>();
    auth.tokenGateway.onExchange = (_) => exchange.future;
    await pumpServerOverview(tester, fullServer270(), auth: auth);

    await tester.tap(_continueButton);
    await tester.pump();
    expect(auth.tokenGateway.exchangedCodes, hasLength(1));

    await tester.tap(find.text(en.signInWaiting));
    await tester.pageBack();
    await tester.pump();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(seconds: 1));

    expect(location(tester), AppRoutes.serverOverview);
    expect(auth.webAuthenticator.urls, hasLength(1));
    expect(auth.tokenGateway.exchangedCodes, hasLength(1));

    exchange.complete(issueTokens(issuedAt: DateTime.now().toUtc()));
    await tester.pumpAndSettle();
    expect(location(tester), AppRoutes.overview);
  });

  testWidgets('the app bar back button is disabled while signing in', (
    tester,
  ) async {
    final browser = Completer<Uri?>();
    auth.webAuthenticator.handler = (_, _) => browser.future;
    await pumpServerOverview(tester, fullServer270(), auth: auth);
    IconButton backButton() => tester.widget<IconButton>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
    );
    expect(backButton().onPressed, isNotNull);

    await tester.tap(_continueButton);
    await tester.pump();
    expect(backButton().onPressed, isNull);
    expect(find.byType(BackButtonIcon), findsOneWidget);

    browser.complete(null);
    await tester.pumpAndSettle();
    expect(backButton().onPressed, isNotNull);
  });

  testWidgets('back leaves the overview again once the attempt is over', (
    tester,
  ) async {
    auth.webAuthenticator.handler = (_, _) async => null;
    await pumpServerOverview(tester, fullServer270(), auth: auth);

    await tester.tap(_continueButton);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
  });

  testWidgets('closing the browser stays on the overview without an error', (
    tester,
  ) async {
    auth.webAuthenticator.handler = (_, _) async => null;
    await pumpServerOverview(tester, oauthServer230(), auth: auth);

    await tester.tap(_continueButton);
    await tester.pumpAndSettle();

    expect(find.byType(ServerOverviewScreen), findsOneWidget);
    expect(find.byType(ConnectionErrorCard), findsNothing);
    expect(auth.tokenGateway.exchangedCodes, isEmpty);
  });

  for (final (name, arrange, title) in [
    (
      'an expired code',
      (AuthFakes auth) =>
          auth.tokenGateway.onExchange = (_) async =>
              throw const OAuthFailure(OAuthProblem.codeExpired, code: 17005),
      en.signInExpiredTitle,
    ),
    (
      'an unreachable server',
      (AuthFakes auth) =>
          auth.tokenGateway.onExchange = (_) async =>
              throw const NetworkFailure(NetworkProblem.unreachable),
      en.failureUnreachableTitle,
    ),
    (
      'rate limiting',
      (AuthFakes auth) =>
          auth.tokenGateway.onExchange = (_) async =>
              throw const RateLimited(retryAfter: Duration(seconds: 42)),
      en.signInRateLimitedTitle,
    ),
    (
      'a foreign state',
      (AuthFakes auth) => auth.webAuthenticator.handler = (_, _) async =>
          appOAuthClient.redirectUri.replace(
            queryParameters: {'code': 'c', 'state': 'forged'},
          ),
      en.signInDiscardedTitle,
    ),
    (
      'no browser',
      (AuthFakes auth) => auth.webAuthenticator.handler = (_, _) async =>
          throw const WebAuthenticationFailed(
            WebAuthenticationProblem.noBrowser,
          ),
      en.signInNoBrowserTitle,
    ),
  ]) {
    testWidgets('$name is explained above the server details', (tester) async {
      arrange(auth);
      await pumpServerOverview(tester, fullServer270(), auth: auth);

      await tester.tap(_continueButton);
      await tester.pumpAndSettle();

      expect(find.byType(ServerOverviewScreen), findsOneWidget);
      final card = find.byType(ConnectionErrorCard);
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(title)),
        findsOneWidget,
      );
      expect(tester.getTopLeft(card).dy, lessThan(200));
    });
  }

  testWidgets('trying again after a failure can succeed', (tester) async {
    var attempts = 0;
    auth.tokenGateway.onExchange = (_) async {
      if (++attempts == 1) {
        throw const NetworkFailure(NetworkProblem.timeout);
      }
      return issueTokens(issuedAt: DateTime.now().toUtc());
    };
    await pumpServerOverview(tester, fullServer270(), auth: auth);

    await tester.tap(_continueButton);
    await tester.pumpAndSettle();
    expect(find.text(en.failureTimeoutTitle), findsOneWidget);

    await tester.tap(_continueButton);
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('a failure is announced as one live region', (tester) async {
    auth.tokenGateway.onExchange = (_) async =>
        throw const OAuthFailure(OAuthProblem.codeInvalid, code: 17004);
    final semantics = tester.ensureSemantics();
    await pumpServerOverview(tester, fullServer270(), auth: auth);

    await tester.tap(_continueButton);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(ConnectionErrorCard)),
      matchesSemantics(
        isLiveRegion: true,
        label:
            '${en.signInExpiredTitle}\n${en.signInExpiredExplanation}\n'
            '${en.signInRetrySuggestion}',
      ),
    );
    semantics.dispose();
  });
}
