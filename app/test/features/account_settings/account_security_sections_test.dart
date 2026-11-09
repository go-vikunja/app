import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_deletion.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_tokens_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/caldav_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/data_export_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sessions_page.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';
import 'security_harness.dart';

void main() {
  late SecurityHarness harness;

  setUp(() => harness = SecurityHarness());

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      scrollToIn(tester, AccountSettingsPage, finder);

  Future<void> tapRow(WidgetTester tester, String title) async {
    final row = find.widgetWithText(ListTile, title);
    await scrollTo(tester, row);
    await tester.tap(row.first);
    await tester.pumpAndSettle();
  }

  /// [text]'s place in the whole list, so texts further down come after.
  Future<double> placeInList(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await scrollTo(tester, finder);
    final list = find
        .descendant(
          of: find.byType(AccountSettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final scrolled = tester.state<ScrollableState>(list).position.pixels;
    return tester.getTopLeft(finder.first).dy + scrolled;
  }

  testWidgets('security follows password and email, integrations and your '
      'data follow privacy, deleting the account comes last', (tester) async {
    await harness.pump(tester);

    final places = [
      await placeInList(tester, en.accountSettingsChangeEmail),
      await placeInList(tester, en.accountSettingsTotp),
      await placeInList(tester, en.accountSettingsSessions),
      await placeInList(tester, en.accountSettingsDefaults),
      await placeInList(tester, en.accountSettingsDiscoverableByEmail),
      await placeInList(tester, en.accountSettingsApiTokens),
      await placeInList(tester, en.accountSettingsCaldav),
      await placeInList(tester, en.accountSettingsExport),
      await placeInList(tester, en.accountSettingsDeleteAccount),
    ];
    expect(places, orderedEquals([...places]..sort()));
  });

  group('password and email', () {
    testWidgets('on 2.8.0 a note under both rows says that the web asks for '
        'the password and ten wrong ones lock the account', (tester) async {
      await harness.pump(tester, connection: securityServer(version: 'v2.8.0'));

      final note =
          '${en.accountSettingsWebAsksPassword} '
          '${en.accountSettingsAccountLockout}';
      final places = [
        await placeInList(tester, en.accountSettingsChangePassword),
        await placeInList(tester, en.accountSettingsChangeEmail),
        await placeInList(tester, note),
        await placeInList(tester, en.accountSettingsSecurity),
      ];
      expect(places, orderedEquals([...places]..sort()));
      expect(find.text(note), findsOneWidget);
    });

    testWidgets('before 2.8.0 there is no such note', (tester) async {
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsTotp));
      expect(find.text(en.accountSettingsWebAsksPassword), findsNothing);
      expect(
        find.textContaining(en.accountSettingsAccountLockout),
        findsNothing,
      );
    });

    testWidgets('an account of a sign-in provider has no such note', (
      tester,
    ) async {
      await harness.pump(
        tester,
        connection: securityServer(version: 'v2.8.0'),
        state: fakeAccountSettingsState(isLocalUser: false),
      );

      await scrollTo(tester, find.text(en.accountSettingsSessions));
      expect(
        find.textContaining(en.accountSettingsAccountLockout),
        findsNothing,
      );
    });

    testWidgets('the note in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await harness.pump(tester, connection: securityServer(version: 'v2.8.0'));

      await scrollTo(tester, find.text(de.accountSettingsChangeEmail));
      expect(
        find.text(
          '${de.accountSettingsWebAsksPassword} '
          '${de.accountSettingsAccountLockout}',
        ),
        findsOneWidget,
      );
    });
  });

  group('two-factor authentication', () {
    for (final (status, label) in [
      (TotpStatus.notSetUp, en.accountSettingsTotpOff),
      (TotpStatus.setupStarted, en.accountSettingsTotpSetupStarted),
      (TotpStatus.enabled, en.accountSettingsTotpOn),
    ]) {
      testWidgets('shows ${status.name} as "$label"', (tester) async {
        harness.security.totp = status;
        await harness.pump(tester);

        await scrollTo(tester, find.text(en.accountSettingsTotp));
        expect(find.text(label), findsOneWidget);
        expect(
          find.text(
            status == TotpStatus.enabled
                ? en.accountSettingsTotpOnNote
                : en.accountSettingsTotpTurnOnNote,
          ),
          findsOneWidget,
        );
      });
    }

    for (final (status, note) in [
      (TotpStatus.notSetUp, en.accountSettingsTotpTurnOnPasswordNote),
      (TotpStatus.setupStarted, en.accountSettingsTotpTurnOnPasswordNote),
      (TotpStatus.enabled, en.accountSettingsTotpOnNote),
    ]) {
      testWidgets('on 2.8.0, which asks for the password both ways, the '
          '${status.name} note adds that ten wrong ones lock the account', (
        tester,
      ) async {
        harness.security.totp = status;
        await harness.pump(
          tester,
          connection: securityServer(version: 'v2.8.0'),
        );

        await scrollTo(tester, find.text(en.accountSettingsTotp));
        expect(
          find.text('$note ${en.accountSettingsAccountLockout}'),
          findsOneWidget,
        );
      });
    }

    testWidgets('on 2.8.0 the turn-on note names the password in German', (
      tester,
    ) async {
      useLocale(tester, const Locale('de'));
      harness.security.totp = TotpStatus.notSetUp;
      await harness.pump(tester, connection: securityServer(version: 'v2.8.0'));

      await scrollTo(tester, find.text(de.accountSettingsTotp));
      expect(
        find.text(
          '${de.accountSettingsTotpTurnOnPasswordNote} '
          '${de.accountSettingsAccountLockout}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(de.accountSettingsTotpTurnOnNote),
        findsNothing,
      );
    });

    testWidgets('a server with it off has no row and is not asked', (
      tester,
    ) async {
      await harness.pump(tester, connection: securityServer(totp: false));

      await scrollTo(tester, find.text(en.accountSettingsSessions));
      expect(find.text(en.accountSettingsTotp), findsNothing);
      expect(harness.security.calls, isNot(contains('totpStatus')));
    });

    testWidgets('an account of a sign-in provider has no row', (tester) async {
      await harness.pump(
        tester,
        state: fakeAccountSettingsState(
          isLocalUser: false,
          authProvider: 'Keycloak',
        ),
      );

      await scrollTo(tester, find.text(en.accountSettingsSessions));
      expect(find.text(en.accountSettingsTotp), findsNothing);
      expect(harness.security.calls, isNot(contains('totpStatus')));
    });

    testWidgets('a route the server lacks reads "not offered"', (tester) async {
      harness.security.failures['totpStatus'] = const NotFound();
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsTotp));
      expect(find.text(en.accountSettingsTotpNotOffered), findsOneWidget);
    });

    for (final (why, failure, label) in [
      (
        'a route the server lacks',
        const NotFound(),
        en.accountSettingsTotpNotOffered,
      ),
      (
        "an account the server takes for a sign-in provider's",
        const DomainError(412, code: 1021, message: 'not a local user'),
        en.accountSettingsTotpNotAvailable,
      ),
    ]) {
      testWidgets('$why: no turn-on note and nothing to open', (tester) async {
        harness.security.failures['totpStatus'] = failure;
        await harness.pump(tester);

        final row = find.widgetWithText(ListTile, en.accountSettingsTotp);
        await scrollTo(tester, row);
        expect(find.text(label), findsOneWidget);
        expect(find.text(en.accountSettingsTotpTurnOnNote), findsNothing);
        expect(tester.widget<ListTile>(row).enabled, isFalse);
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.open_in_new)),
          findsNothing,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(harness.links.opened, isEmpty);
      });
    }

    testWidgets('back from anything but its web page, the status is not '
        'read again, as servers before 2.7 send the secret with it', (
      tester,
    ) async {
      await harness.pump(tester);

      resumeApp(tester);
      await tester.pumpAndSettle();
      await tapRow(tester, en.accountSettingsSessions);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final calls = harness.security.calls;
      // The page's own read, the resume, the Sessions page and the return.
      expect(calls.where((call) => call == 'sessions'), hasLength(4));
      expect(calls.where((call) => call == 'totpStatus'), hasLength(1));
    });

    testWidgets('over http to a server before 2.7 it is not read at all, and '
        'the web page still opens', (tester) async {
      await harness.pump(
        tester,
        connection: securityServer(insecure: true, version: 'v2.6.0'),
      );

      await scrollTo(tester, find.text(en.accountSettingsTotp));
      expect(find.text(en.accountSettingsTotpNotChecked), findsOneWidget);
      expect(harness.security.calls, isNot(contains('totpStatus')));
      await tapRow(tester, en.accountSettingsTotp);
      expect(harness.links.opened, hasLength(1));
    });

    testWidgets('a status that cannot be read says so', (tester) async {
      harness.security.failures['totpStatus'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsTotp));
      expect(find.text(en.accountSettingsTotpUnknown), findsOneWidget);
    });

    testWidgets('opens the web page, and back from it the session is checked '
        'at once and the status read again', (tester) async {
      harness.auth.tokenGateway.onRefresh = (_) async =>
          throw const SessionEnded(
            SessionEndReason.invalidRefreshToken,
            code: 16002,
          );
      await harness.pump(tester);

      await tapRow(tester, en.accountSettingsTotp);
      expect(harness.links.opened, [webPage('user/settings/totp')]);
      expect(harness.auth.tokenGateway.refreshedTokens, isEmpty);

      harness.security.totp = TotpStatus.enabled;
      resumeApp(tester);
      // The session manager looks for a sibling's rotation for a few
      // seconds before it gives a 16002 up.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();

      expect(harness.auth.tokenGateway.refreshedTokens, hasLength(1));
      final accounts = containerOf(tester).read(accountsProvider).value!;
      expect(accounts.activeAccount!.account.needsReauth, isTrue);
      expect(
        harness.security.calls.where((call) => call == 'totpStatus'),
        hasLength(2),
      );
      await scrollTo(tester, find.text(en.accountSettingsTotp));
      expect(find.text(en.accountSettingsTotpOn), findsOneWidget);
    });
  });

  group('rows to the pages', () {
    testWidgets('sessions with their count', (tester) async {
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsSessions));
      expect(find.text(en.accountSettingsSessionsCount(3)), findsOneWidget);
      await tapRow(tester, en.accountSettingsSessions);

      expect(find.byType(SessionsPage), findsOneWidget);
    });

    testWidgets('API tokens with their count', (tester) async {
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsApiTokens));
      expect(find.text(en.accountSettingsApiTokensCount(0)), findsOneWidget);
      await tapRow(tester, en.accountSettingsApiTokens);

      expect(find.byType(ApiTokensPage), findsOneWidget);
    });

    testWidgets('CalDAV only where the server offers it', (tester) async {
      await harness.pump(tester);

      await tapRow(tester, en.accountSettingsCaldav);
      expect(find.byType(CaldavPage), findsOneWidget);
    });

    testWidgets('no CalDAV row on a server without it', (tester) async {
      await harness.pump(tester, connection: securityServer(caldav: false));

      await scrollTo(tester, find.text(en.accountSettingsExport));
      expect(find.text(en.accountSettingsCaldav), findsNothing);
    });

    testWidgets('the data export with its status', (tester) async {
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsExport));
      expect(find.text(en.accountSettingsExportNone), findsOneWidget);
      await tapRow(tester, en.accountSettingsExport);

      expect(find.byType(DataExportPage), findsOneWidget);
    });

    testWidgets('a ready export names the day it goes', (tester) async {
      harness.security.export = UserDataExport(
        id: 4,
        size: 2372,
        created: harness.now.subtract(const Duration(days: 1)),
        expires: harness.now.add(const Duration(days: 6)),
      );
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsExport));
      expect(find.textContaining('Ready to download until'), findsOneWidget);
    });

    testWidgets('offline, the pages still open and show their own state', (
      tester,
    ) async {
      harness.data = SyncFakes(
        now: harness.now,
        status: SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: harness.now.subtract(const Duration(hours: 1)),
        ),
      );
      harness.security.failure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await harness.pump(tester);

      await scrollTo(tester, find.text(en.accountSettingsSessions));
      expect(find.text(en.accountSettingsSessionsHint), findsOneWidget);
      await tapRow(tester, en.accountSettingsSessions);

      expect(find.byType(SessionsPage), findsOneWidget);
      expect(find.text(en.retry), findsOneWidget);
    });
  });

  group('deleting the account', () {
    testWidgets('explains what it means, then continues in the browser', (
      tester,
    ) async {
      await harness.pump(tester);

      await tapRow(tester, en.accountSettingsDeleteAccount);
      expect(find.text(en.accountDeletionDialogTitle), findsOneWidget);
      expect(
        find.textContaining(en.accountDeletionDialogPermanent),
        findsOneWidget,
      );
      expect(
        find.textContaining(en.accountDeletionDialogNoEmail),
        findsOneWidget,
      );
      expect(
        find.textContaining(en.accountSettingsWebAsksPassword),
        findsOneWidget,
      );
      // 2.7 does not lock an account after wrong passwords.
      expect(
        find.textContaining(en.accountSettingsAccountLockout),
        findsNothing,
      );

      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(harness.links.opened, isEmpty);

      await tapRow(tester, en.accountSettingsDeleteAccount);
      await tester.tap(find.text(en.accountDeletionContinue));
      await tester.pumpAndSettle();
      expect(harness.links.opened, [webPage('user/settings/deletion')]);
    });

    testWidgets('on 2.8.0 also says that ten wrong passwords lock the '
        'account', (tester) async {
      await harness.pump(tester, connection: securityServer(version: 'v2.8.0'));

      await tapRow(tester, en.accountSettingsDeleteAccount);

      // The same sentences stand under Password and email.
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining(
            '${en.accountSettingsWebAsksPassword} '
            '${en.accountSettingsAccountLockout}',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a sign-in provider account is not told about a password', (
      tester,
    ) async {
      await harness.pump(
        tester,
        state: fakeAccountSettingsState(isLocalUser: false),
      );

      await tapRow(tester, en.accountSettingsDeleteAccount);

      expect(
        find.textContaining(en.accountSettingsWebAsksPassword),
        findsNothing,
      );
    });

    testWidgets('nor about the lockout on 2.8.0', (tester) async {
      await harness.pump(
        tester,
        connection: securityServer(version: 'v2.8.0'),
        state: fakeAccountSettingsState(isLocalUser: false),
      );

      await tapRow(tester, en.accountSettingsDeleteAccount);

      expect(find.text(en.accountDeletionDialogTitle), findsOneWidget);
      expect(
        find.textContaining(en.accountSettingsWebAsksPassword),
        findsNothing,
      );
      expect(
        find.textContaining(en.accountSettingsAccountLockout),
        findsNothing,
      );
    });

    testWidgets('where the server does not allow it, says whom to ask and '
        'opens nothing', (tester) async {
      await harness.pump(
        tester,
        connection: securityServer(userDeletion: false),
      );

      await scrollTo(tester, find.text(en.accountSettingsDeleteAccount));
      expect(find.text(en.accountDeletionNotAllowedRow), findsOneWidget);
      expect(find.text(en.accountSettingsOpensWeb), findsNothing);
      await tapRow(tester, en.accountSettingsDeleteAccount);

      expect(find.text(en.accountDeletionNotAllowedTitle), findsOneWidget);
      expect(find.text(en.accountDeletionNotAllowedBody), findsOneWidget);
      expect(find.text(en.accountDeletionDialogTitle), findsNothing);
      await tester.tap(find.text(en.accountDeletionNotAllowedOk));
      await tester.pumpAndSettle();

      expect(find.text(en.accountDeletionNotAllowedTitle), findsNothing);
      expect(harness.links.opened, isEmpty);
    });

    testWidgets('where the server does not allow it, says so in German', (
      tester,
    ) async {
      useLocale(tester, const Locale('de'));
      await harness.pump(
        tester,
        connection: securityServer(userDeletion: false),
      );

      await tapRow(tester, de.accountSettingsDeleteAccount);

      expect(find.text(de.accountDeletionNotAllowedTitle), findsOneWidget);
      expect(find.text(de.accountDeletionNotAllowedBody), findsOneWidget);
      await tester.tap(find.text(de.accountDeletionNotAllowedOk));
      await tester.pumpAndSettle();
      expect(harness.links.opened, isEmpty);
    });

    testWidgets('a deletion scheduled before the server stopped allowing it '
        'is still cancelled on the web', (tester) async {
      await harness.pump(
        tester,
        connection: securityServer(userDeletion: false),
        state: fakeAccountSettingsState(
          deletionScheduledAt: harness.now.add(const Duration(days: 3)),
        ),
      );

      await scrollTo(tester, find.text(en.accountSettingsDeleteAccount));
      expect(find.textContaining('Deletion on'), findsOneWidget);
      await tester.tap(find.text(en.accountSettingsDeleteAccount));
      await tester.pumpAndSettle();

      expect(find.text(en.accountDeletionNotAllowedTitle), findsNothing);
      expect(harness.links.opened, [webPage('user/settings/deletion')]);
    });

    testWidgets('once scheduled, the page and the Account tab say when, and '
        'cancelling opens the web', (tester) async {
      await harness.pump(
        tester,
        state: fakeAccountSettingsState(
          deletionScheduledAt: harness.now.add(const Duration(days: 3)),
        ),
      );

      expect(
        find.textContaining('Your account will be deleted on'),
        findsOneWidget,
      );
      await tester.tap(find.text(en.accountDeletionCancel));
      await tester.pumpAndSettle();
      expect(harness.links.opened, [webPage('user/settings/deletion')]);

      await scrollTo(tester, find.text(en.accountSettingsDeleteAccount));
      expect(find.textContaining('Deletion on'), findsOneWidget);
      await tester.tap(find.text(en.accountSettingsDeleteAccount));
      await tester.pumpAndSettle();
      // No question first: the web's page is where it is cancelled.
      expect(find.text(en.accountDeletionDialogTitle), findsNothing);
      expect(harness.links.opened, hasLength(2));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.tabAccount);
      expect(
        find.textContaining('Your account will be deleted on'),
        findsOneWidget,
      );
      await tester.tap(find.text(en.accountDeletionCancel));
      await tester.pumpAndSettle();
      expect(harness.links.opened.last, webPage('user/settings/deletion'));
    });

    group('the note of a scheduled deletion, whose cancel the web asks the '
        'password for', () {
      Finder inNote(String text) => find.descendant(
        of: find.byType(DeletionScheduledNote),
        matching: find.text(text),
      );

      Future<void> showBothNotes(
        WidgetTester tester,
        void Function() expectNote, {
        ServerConnection? connection,
        bool isLocalUser = true,
      }) async {
        await harness.pump(
          tester,
          connection: connection,
          state: fakeAccountSettingsState(
            isLocalUser: isLocalUser,
            deletionScheduledAt: harness.now.add(const Duration(days: 3)),
          ),
        );
        expectNote();

        await tester.pageBack();
        await tester.pumpAndSettle();
        await openTab(tester, en.tabAccount);
        expect(find.byType(DeletionScheduledNote), findsOneWidget);
        expectNote();
      }

      testWidgets('says so on the page and the Account tab, without the '
          'lockout before 2.8.0', (tester) async {
        await showBothNotes(tester, () {
          expect(inNote(en.accountSettingsWebAsksPassword), findsOneWidget);
          expect(
            find.textContaining(en.accountSettingsAccountLockout),
            findsNothing,
          );
        });
      });

      testWidgets('on 2.8.0 adds that ten wrong passwords lock the account', (
        tester,
      ) async {
        await showBothNotes(
          tester,
          () => expect(
            inNote(
              '${en.accountSettingsWebAsksPassword} '
              '${en.accountSettingsAccountLockout}',
            ),
            findsOneWidget,
          ),
          connection: securityServer(version: 'v2.8.0'),
        );
      });

      testWidgets('an account of a sign-in provider is told neither', (
        tester,
      ) async {
        await showBothNotes(
          tester,
          () {
            expect(
              find.textContaining(en.accountSettingsWebAsksPassword),
              findsNothing,
            );
            expect(
              find.textContaining(en.accountSettingsAccountLockout),
              findsNothing,
            );
          },
          connection: securityServer(version: 'v2.8.0'),
          isLocalUser: false,
        );
      });

      testWidgets('in German', (tester) async {
        useLocale(tester, const Locale('de'));
        await harness.pump(
          tester,
          connection: securityServer(version: 'v2.8.0'),
          state: fakeAccountSettingsState(
            deletionScheduledAt: harness.now.add(const Duration(days: 3)),
          ),
        );

        expect(
          inNote(
            '${de.accountSettingsWebAsksPassword} '
            '${de.accountSettingsAccountLockout}',
          ),
          findsOneWidget,
        );
      });
    });

    group('the Delete account row of a scheduled deletion, which opens the '
        'web without a dialog, says so too', () {
      Finder inRow(String text) => find.descendant(
        of: find.widgetWithText(ListTile, en.accountSettingsDeleteAccount),
        matching: find.text(text),
      );

      Future<void> showRow(
        WidgetTester tester, {
        ServerConnection? connection,
        bool isLocalUser = true,
        Duration until = const Duration(days: 3),
      }) async {
        await harness.pump(
          tester,
          connection: connection,
          state: fakeAccountSettingsState(
            isLocalUser: isLocalUser,
            deletionScheduledAt: harness.now.add(until),
          ),
        );
        await scrollTo(tester, find.text(en.accountSettingsDeleteAccount));
      }

      testWidgets('without the lockout before 2.8.0', (tester) async {
        await showRow(tester);

        expect(inRow(en.accountSettingsWebAsksPassword), findsOneWidget);
        expect(
          find.textContaining(en.accountSettingsAccountLockout),
          findsNothing,
        );
      });

      testWidgets('on 2.8.0 with it, also once the date has passed, and the '
          'tap still opens the web', (tester) async {
        await showRow(
          tester,
          connection: securityServer(version: 'v2.8.0'),
          until: const Duration(days: -3),
        );

        expect(find.textContaining('Deletion due since'), findsOneWidget);
        expect(
          inRow(
            '${en.accountSettingsWebAsksPassword} '
            '${en.accountSettingsAccountLockout}',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(en.accountSettingsDeleteAccount));
        await tester.pumpAndSettle();
        expect(find.text(en.accountDeletionDialogTitle), findsNothing);
        expect(harness.links.opened, [webPage('user/settings/deletion')]);
      });

      testWidgets('not for an account of a sign-in provider', (tester) async {
        await showRow(
          tester,
          connection: securityServer(version: 'v2.8.0'),
          isLocalUser: false,
        );

        expect(find.textContaining('Deletion on'), findsOneWidget);
        expect(
          find.textContaining(en.accountSettingsWebAsksPassword),
          findsNothing,
        );
      });

      testWidgets('nor before a deletion is scheduled, as the dialog says it', (
        tester,
      ) async {
        await harness.pump(
          tester,
          connection: securityServer(version: 'v2.8.0'),
        );
        await scrollTo(tester, find.text(en.accountSettingsDeleteAccount));

        expect(inRow(en.accountSettingsOpensWeb), findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, en.accountSettingsDeleteAccount),
            matching: find.textContaining(en.accountSettingsWebAsksPassword),
          ),
          findsNothing,
        );
      });

      testWidgets('in German', (tester) async {
        useLocale(tester, const Locale('de'));
        await harness.pump(
          tester,
          connection: securityServer(version: 'v2.8.0'),
          state: fakeAccountSettingsState(
            deletionScheduledAt: harness.now.add(const Duration(days: 3)),
          ),
        );
        await scrollTo(tester, find.text(de.accountSettingsDeleteAccount));

        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, de.accountSettingsDeleteAccount),
            matching: find.text(
              '${de.accountSettingsWebAsksPassword} '
              '${de.accountSettingsAccountLockout}',
            ),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('a date that has passed reads as due since then', (
      tester,
    ) async {
      await harness.pump(
        tester,
        state: fakeAccountSettingsState(
          deletionScheduledAt: harness.now.subtract(const Duration(days: 3)),
        ),
      );

      expect(
        find.textContaining('has been due for deletion since'),
        findsOneWidget,
      );
      expect(find.textContaining('will be deleted'), findsNothing);
      await scrollTo(tester, find.text(en.accountSettingsDeleteAccount));
      expect(find.textContaining('Deletion due since'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.tabAccount);
      expect(
        find.textContaining('has been due for deletion since'),
        findsOneWidget,
      );
      expect(find.text(en.accountDeletionCancel), findsOneWidget);
    });

    testWidgets('a browser that does not open says so', (tester) async {
      harness.links = FakeExternalLinkOpener(succeeds: false);
      await harness.pump(
        tester,
        location: null,
        state: fakeAccountSettingsState(
          deletionScheduledAt: harness.now.add(const Duration(days: 3)),
        ),
      );
      await openTab(tester, en.tabAccount);

      await tester.tap(find.text(en.accountDeletionCancel));
      await tester.pumpAndSettle();

      expect(find.text(en.accountSettingsWebNotOpened), findsOneWidget);
    });
  });

  testWidgets('the end of the page stays clear of the navigation bar', (
    tester,
  ) async {
    usePhoneSurface(tester);
    tester.view.padding = const FakeViewPadding(bottom: 48 * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48 * 3);
    await harness.pump(tester);

    final list = find
        .descendant(
          of: find.byType(AccountSettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(list).position;
    // The lazy list's extent is an estimate until its end is built.
    for (var i = 0; i < 5 && position.extentAfter > 0; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }

    expect(
      tester
          .getBottomLeft(
            find.widgetWithText(ListTile, en.accountSettingsDeleteAccount),
          )
          .dy,
      lessThanOrEqualTo(phoneSize.height - 48),
    );
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await harness.pump(tester);

    await scrollTo(tester, find.text(de.accountSettingsSecurity));
    expect(find.text(de.accountSettingsTotp), findsOneWidget);
    await scrollTo(tester, find.text(de.accountSettingsIntegrations));
    expect(find.text(de.accountSettingsIntegrations), findsOneWidget);
  });

  test('the routes stay under the account settings', () {
    expect(AppRoutes.accountSessions, '/home/account-settings/sessions');
    expect(
      AppRoutes.accountApiTokenNew,
      '/home/account-settings/api-tokens/new',
    );
  });
}
