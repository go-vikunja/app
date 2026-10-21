import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_tokens_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/caldav_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/one_time_secret_view.dart';

import '../../helpers/account_security_fakes.dart';
import '../../helpers/account_settings_fakes.dart';
import '../../helpers/pump_app.dart';
import 'security_harness.dart';

void main() {
  late SecurityHarness harness;
  late List<String> clipboardTexts;
  late bool clipboardFails;

  setUp(() {
    harness = SecurityHarness();
    clipboardTexts = [];
    clipboardFails = false;
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    ServerConnection? connection,
    bool isLocalUser = true,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          if (clipboardFails) throw PlatformException(code: 'clipboard');
          clipboardTexts.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await harness.pump(
      tester,
      location: AppRoutes.accountCaldav,
      connection: connection,
      state: fakeAccountSettingsState(
        isLocalUser: isLocalUser,
        authProvider: isLocalUser ? 'local' : 'Keycloak',
      ),
    );
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      scrollToIn(tester, CaldavPage, finder);

  const address = 'https://tasks.example.org/vikunja/dav/principals/alice/';

  testWidgets('shows the address and the username to copy', (tester) async {
    await pumpPage(tester);

    expect(find.text(address), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    await tester.tap(find.byTooltip(en.caldavCopyAddress));
    await tester.tap(find.byTooltip(en.caldavCopyUsername));
    await tester.pumpAndSettle();

    expect(clipboardTexts, [address, 'alice']);
    // Neither is a secret, so the screen stays as it is.
    expect(harness.secureDisplay.changes, isEmpty);
  });

  testWidgets('a copy shows a check for a moment, as not every system '
      'shows one', (tester) async {
    await pumpPage(tester);

    Icon copyIcon(String tooltip) => tester.widget<Icon>(
      find.descendant(of: find.byTooltip(tooltip), matching: find.byType(Icon)),
    );
    await tester.tap(find.byTooltip(en.caldavCopyAddress));
    await tester.pump();
    expect(copyIcon(en.caldavCopyAddress).icon, Icons.check);
    expect(copyIcon(en.caldavCopyUsername).icon, Icons.copy);

    await tester.pump(const Duration(seconds: 3));
    expect(copyIcon(en.caldavCopyAddress).icon, Icons.copy);
  });

  testWidgets('a copy that fails says so', (tester) async {
    clipboardFails = true;
    await pumpPage(tester);

    await tester.tap(find.byTooltip(en.caldavCopyAddress));
    await tester.pumpAndSettle();

    expect(find.text(en.copyToClipboardFailed), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('the end of a long list stays clear of the navigation bar', (
    tester,
  ) async {
    harness.security.caldavTokenList = [
      for (var id = 1; id <= 12; id++)
        CaldavToken(id: id, created: harness.now),
    ];
    usePhoneSurface(tester);
    tester.view.padding = const FakeViewPadding(bottom: 48 * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48 * 3);
    await pumpPage(tester);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    final button = find.ancestor(
      of: find.text(en.caldavNewToken),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(
      tester.getBottomLeft(button).dy,
      lessThanOrEqualTo(phoneSize.height - 48),
    );
  });

  group('which password works', () {
    testWidgets('a password account without two-factor: either', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text(en.caldavPasswordOrToken), findsOneWidget);
    });

    testWidgets('with two-factor on: only a token', (tester) async {
      harness.security.totp = TotpStatus.enabled;
      await pumpPage(tester);

      expect(find.text(en.caldavTokenTotp), findsOneWidget);
      expect(find.text(en.caldavPasswordOrToken), findsNothing);
    });

    testWidgets('a sign-in provider account: only a token', (tester) async {
      await pumpPage(tester, isLocalUser: false);

      expect(find.text(en.caldavTokenProvider('Keycloak')), findsOneWidget);
      expect(harness.security.calls, isNot(contains('totpStatus')));
    });

    testWidgets('a server without two-factor: either, without asking', (
      tester,
    ) async {
      await pumpPage(tester, connection: securityServer(totp: false));

      expect(find.text(en.caldavPasswordOrToken), findsOneWidget);
      expect(harness.security.calls, isNot(contains('totpStatus')));
    });

    testWidgets('a two-factor status that cannot be read: the cautious text', (
      tester,
    ) async {
      harness.security.failures['totpStatus'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpPage(tester);

      expect(find.text(en.caldavTokenUnknown), findsOneWidget);
    });
  });

  testWidgets('an API token works too, and its page is one tap away', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text(en.caldavApiTokenHint), findsOneWidget);
    await tester.tap(
      find.widgetWithText(TextButton, en.accountSettingsApiTokens),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ApiTokensPage), findsOneWidget);
  });

  testWidgets("links to Vikunja's CalDAV documentation", (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text(en.caldavDocs));
    await tester.pumpAndSettle();

    expect(harness.links.opened, [
      Uri.parse('https://vikunja.io/docs/caldav/'),
    ]);
  });

  testWidgets('a new token is shown once with the username, then listed', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text(en.caldavTokensEmpty), findsOneWidget);

    await scrollTo(tester, find.text(en.caldavNewToken));
    await tester.tap(find.text(en.caldavNewToken));
    await tester.pumpAndSettle();

    final secret = fakeCaldavTokenSecret(1);
    expect(find.byType(OneTimeSecretPage), findsOneWidget);
    expect(find.text(secret), findsOneWidget);
    expect(find.text(en.oneTimeSecretCaldavUsage('alice')), findsOneWidget);
    expect(clipboardTexts, isEmpty);
    expect(harness.secureDisplay.secure, isTrue);
    await tester.tap(find.text(en.oneTimeSecretCopy));
    await tester.pumpAndSettle();
    expect(harness.clipboard.copied, [secret]);
    expect(clipboardTexts, isEmpty);

    await tester.tap(find.text(en.oneTimeSecretDone));
    await tester.pumpAndSettle();
    expect(find.byType(CaldavPage), findsOneWidget);
    expect(harness.secureDisplay.secure, isFalse);
    expect(find.text(secret), findsNothing);
    await scrollTo(tester, find.text(en.caldavTokenName(1)));
    expect(find.text(en.caldavTokenName(1)), findsOneWidget);
  });

  group('the new value selected', () {
    Future<String> selectSecret(WidgetTester tester) async {
      await pumpPage(tester);
      await scrollTo(tester, find.text(en.caldavNewToken));
      await tester.tap(find.text(en.caldavNewToken));
      await tester.pumpAndSettle();
      final secret = fakeCaldavTokenSecret(1);
      await tester.longPress(find.text(secret));
      await tester.pumpAndSettle();
      return secret;
    }

    Finder menuItem(String label) => find.descendant(
      of: find.byType(AdaptiveTextSelectionToolbar),
      matching: find.text(label),
    );

    testWidgets("the menu's Copy uses the sensitive clipboard and there is "
        'no Share', (tester) async {
      final secret = await selectSecret(tester);
      expect(menuItem('Copy'), findsOneWidget);
      expect(menuItem('Share'), findsNothing);

      await tester.tap(menuItem('Copy'));
      await tester.pumpAndSettle();

      expect(harness.clipboard.copied, [secret]);
      expect(clipboardTexts, isEmpty);
      expect(find.text(en.copiedToClipboard), findsOneWidget);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    });

    testWidgets('the keyboard shortcut uses the sensitive clipboard', (
      tester,
    ) async {
      final secret = await selectSecret(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(harness.clipboard.copied, [secret]);
      expect(clipboardTexts, isEmpty);
    });
  });

  testWidgets('opened from the Account settings page it takes the two-factor '
      'status from there', (tester) async {
    harness.security.totp = TotpStatus.enabled;
    await harness.pump(tester);

    await scrollToIn(
      tester,
      AccountSettingsPage,
      find.text(en.accountSettingsCaldav),
    );
    await tester.tap(find.text(en.accountSettingsCaldav));
    await tester.pumpAndSettle();

    expect(find.byType(CaldavPage), findsOneWidget);
    expect(find.text(en.caldavTokenTotp), findsOneWidget);
    expect(
      harness.security.calls.where((call) => call == 'totpStatus'),
      hasLength(1),
    );
  });

  testWidgets('over http to a server before 2.7 the two-factor status is not '
      'read', (tester) async {
    await pumpPage(
      tester,
      connection: securityServer(insecure: true, version: 'v2.6.0'),
    );

    expect(find.text(en.caldavTokenUnknown), findsOneWidget);
    expect(harness.security.calls, isNot(contains('totpStatus')));
  });

  testWidgets('a token is deleted after asking', (tester) async {
    harness.security.caldavTokenList = [
      CaldavToken(
        id: 7,
        created: harness.now.subtract(const Duration(days: 2)),
      ),
    ];
    await pumpPage(tester);

    await scrollTo(tester, find.byTooltip(en.caldavDeleteToken(7)));
    await tester.tap(find.byTooltip(en.caldavDeleteToken(7)));
    await tester.pumpAndSettle();
    expect(find.text(en.caldavDeleteTitle(7)), findsOneWidget);
    expect(find.text(en.caldavDeleteBody), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(en.caldavDelete),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.security.calls, contains('deleteCaldavToken 7'));
    expect(find.text(en.caldavTokenName(7)), findsNothing);
  });

  testWidgets('a token that cannot be made says why', (tester) async {
    harness.security.failures['createCaldavToken'] = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpPage(tester);

    await scrollTo(tester, find.text(en.caldavNewToken));
    await tester.tap(find.text(en.caldavNewToken));
    await tester.pumpAndSettle();

    expect(find.text(en.accountSecurityNeedsConnection), findsOneWidget);
    expect(find.byType(OneTimeSecretPage), findsNothing);
  });

  testWidgets('offline the address still shows, the tokens offer a retry', (
    tester,
  ) async {
    harness.security.failure = const NetworkFailure(NetworkProblem.unreachable);
    await pumpPage(tester);

    expect(find.text(address), findsOneWidget);
    await scrollTo(tester, find.text(en.retry));
    expect(find.text(en.dataFailureLoadTitle), findsOneWidget);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpPage(tester);

    expect(find.text(de.caldavAddress), findsOneWidget);
    expect(find.text(de.caldavPasswordOrToken), findsOneWidget);
  });
}
