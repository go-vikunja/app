import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/overview_actions.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/server_connections.dart';

final Finder _createAccount = find.widgetWithText(
  TextButton,
  en.overviewCreateAccount,
);
final Finder _forgotPassword = find.widgetWithText(
  TextButton,
  en.overviewForgotPassword,
);
final Finder _dialog = find.byWidgetPredicate((w) => w is AlertDialog);

void main() {
  late AuthFakes auth;

  setUp(() {
    auth = AuthFakes()
      ..serveUser(
        const User(id: 7, username: 'alice', name: 'Alice Example'),
        now: DateTime.now().toUtc(),
      );
  });

  // Tall enough that the whole lazily built list is laid out at once.
  void useTallSurface(WidgetTester tester) =>
      usePhoneSurface(tester, logicalSize: const Size(400, 2400));

  bool isEnabled(WidgetTester tester, Finder button) =>
      tester.widget<TextButton>(button).onPressed != null;

  testWidgets('an open server offers both pages under the sign-in', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, accountPagesServer270(), auth: auth);

    expect(_createAccount, findsOneWidget);
    expect(_forgotPassword, findsOneWidget);
    expect(find.text(en.overviewSignInPageOffersBoth), findsOneWidget);
    expect(find.text(en.signInBrowserSubtitle), findsOneWidget);
    expect(find.text(en.overviewRegistrationNeedsInvitation), findsNothing);
    final signIn = tester.getRect(
      find.widgetWithText(FilledButton, en.continueToSignIn),
    );
    expect(tester.getTopLeft(_createAccount).dy, greaterThan(signIn.bottom));
  });

  testWidgets('Create account says where to find it, then opens the sign-in', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, accountPagesServer270(), auth: auth);

    await tester.tap(_createAccount);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _dialog,
        matching: find.text(en.overviewCreateAccountHint),
      ),
      findsOneWidget,
    );
    expect(auth.webAuthenticator.urls, isEmpty);

    await tester.tap(
      find.descendant(of: _dialog, matching: find.text(en.continueToSignIn)),
    );
    await tester.pumpAndSettle();

    expect(auth.webAuthenticator.urls, hasLength(1));
    expect(auth.webAuthenticator.urls.single.path, '/vikunja/oauth/authorize');
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('cancelling the explanation opens nothing', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, accountPagesServer270(), auth: auth);

    await tester.tap(_createAccount);
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
    await tester.tap(find.text(en.cancel));
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(auth.webAuthenticator.urls, isEmpty);
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  testWidgets("Forgot password? opens the web's reset page in the browser", (
    tester,
  ) async {
    final linkOpener = FakeExternalLinkOpener();
    useTallSurface(tester);
    await pumpServerOverview(
      tester,
      accountPagesServer270(
        root: 'https://api.example.org',
        frontendUrl: Uri.parse('https://tasks.example.org/'),
      ),
      auth: auth,
      linkOpener: linkOpener,
    );

    await tester.tap(_forgotPassword);
    await tester.pumpAndSettle();

    expect(linkOpener.opened, [
      Uri.parse('https://tasks.example.org/get-password-reset'),
    ]);
    expect(auth.webAuthenticator.urls, isEmpty);
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  testWidgets('a browser that does not open is reported', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(
      tester,
      accountPagesServer270(),
      auth: auth,
      linkOpener: FakeExternalLinkOpener(succeeds: false),
    );

    await tester.tap(_forgotPassword);
    await tester.pumpAndSettle();

    expect(find.text(en.accountSettingsWebNotOpened), findsOneWidget);
  });

  testWidgets('both rest while signing in', (tester) async {
    final browser = Completer<Uri?>();
    auth.webAuthenticator.handler = (_, _) => browser.future;
    useTallSurface(tester);
    await pumpServerOverview(tester, accountPagesServer270(), auth: auth);

    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    await tester.pump();

    expect(isEnabled(tester, _createAccount), isFalse);
    expect(isEnabled(tester, _forgotPassword), isFalse);

    browser.complete(null);
    await tester.pumpAndSettle();
    expect(isEnabled(tester, _createAccount), isTrue);
    expect(isEnabled(tester, _forgotPassword), isTrue);
  });

  testWidgets('closed registration leaves the password reset', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(
      tester,
      accountPagesServer270(registration: false),
      auth: auth,
    );

    expect(_createAccount, findsNothing);
    expect(_forgotPassword, findsOneWidget);
    expect(find.text(en.overviewSignInPageOffersPasswordReset), findsOneWidget);
    expect(find.text(en.overviewRegistrationNeedsInvitation), findsNothing);
  });

  testWidgets('a server with invite links only says registration needs one', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(
      tester,
      accountPagesServer270(registration: false, invites: true),
      auth: auth,
    );

    expect(find.text(en.overviewRegistrationNeedsInvitation), findsOneWidget);
    expect(_createAccount, findsNothing);
    expect(_forgotPassword, findsOneWidget);
  });

  testWidgets('single sign-on only offers neither page', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(
      tester,
      accountPagesServer270(localAuth: false, invites: true),
      auth: auth,
    );

    expect(_createAccount, findsNothing);
    expect(_forgotPassword, findsNothing);
    expect(find.text(en.overviewRegistrationNeedsInvitation), findsNothing);
    for (final hint in [
      en.overviewSignInPageOffersBoth,
      en.overviewSignInPageOffersRegistration,
      en.overviewSignInPageOffersPasswordReset,
    ]) {
      expect(find.text(hint), findsNothing);
    }
    expect(
      find.text(en.signInBrowserProvidersSubtitle('Keycloak')),
      findsOneWidget,
    );
  });

  testWidgets('a server too old for sign-in offers neither page', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, legacyServer100(), auth: auth);

    expect(_createAccount, findsNothing);
    expect(_forgotPassword, findsNothing);
  });

  for (final (scale, pinned) in [(1.0, true), (1.3, true), (2.0, false)]) {
    testWidgets('at ${scale * 100} % text the actions are '
        '${pinned ? 'pinned' : 'scrolled with the content'}', (tester) async {
      usePhoneSurface(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpServerOverview(tester, accountPagesServer270(), auth: auth);
      await tester.scrollUntilVisible(find.byType(OverviewActions), 300);

      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(OverviewActions),
        ),
        pinned ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets('is in German', (tester) async {
    useTallSurface(tester);
    useLocale(tester, const Locale('de'));
    await pumpServerOverview(tester, accountPagesServer270(), auth: auth);

    expect(
      find.widgetWithText(TextButton, de.overviewCreateAccount),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, de.overviewForgotPassword),
      findsOneWidget,
    );
    expect(find.text(de.overviewSignInPageOffersBoth), findsOneWidget);
  });
}
