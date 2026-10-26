import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_tile.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/guest_note.dart';
import 'package:vikunja_mobile/features/home/presentation/guest_reauth_banner.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/share_password_sheet.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/guest_entry_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../accounts/accounts_harness.dart';

void main() {
  const host = 'tasks.example.org';
  late AuthFakes auth;
  late SyncFakes data;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
  });

  Future<void> pumpGuestTab(
    WidgetTester tester, {
    Permission? permission = Permission.read,
    bool needsReauth = false,
  }) async {
    await pumpGuestApp(
      tester,
      auth: auth,
      data: data,
      permission: permission,
      needsReauth: needsReauth,
    );
    await openTab(tester, en.tabAccount);
  }

  Finder tabList() => find
      .descendant(
        of: find.byType(AccountTab),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 100, scrollable: tabList());
    await tester.pump();
  }

  /// The banner's button, scrolled into view. While a password is asked
  /// for, the button's progress never settles.
  Future<void> tapOpenLinkAgain(
    WidgetTester tester, {
    bool asksPassword = false,
  }) async {
    final button = find.widgetWithText(FilledButton, en.guestOpenLinkAgain);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    if (asksPassword) {
      await pumpUntil(tester, find.byType(SharePasswordSheet));
      await pumpFrames(tester, 5);
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> submitPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpFrames(tester, 5);
  }

  group('a guest on the Account tab', () {
    testWidgets('is shown by its link, share name and Guest · host, without '
        'the way to account settings, labels and teams', (tester) async {
      await pumpGuestTab(tester);

      final header = find.byType(AccountHeader);
      expect(
        find.descendant(of: header, matching: find.byIcon(Icons.link)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Helper')),
        findsOneWidget,
      );
      expect(find.text(en.guestAccountSubtitle(host)), findsOneWidget);
      expect(find.text(en.accountHeaderEdit), findsNothing);
      expect(find.text(en.accountSettingsEntry), findsNothing);
      expect(find.text(en.accountOrganiseHeading), findsNothing);
      expect(find.byType(ReauthBanner), findsNothing);
      // A heading that opens nothing.
      expect(
        tester.getSemantics(find.text('Helper')),
        isSemantics(isHeader: true, isButton: false, hasTapAction: false),
      );
      await scrollTo(tester, find.text(en.overviewVikunjaVersion('2.7.0')));
      expect(find.text(en.accountServerHeading), findsOneWidget);
    });

    testWidgets('the note says what a read share allows and what needs an '
        'account', (tester) async {
      await pumpGuestTab(tester);

      final note = find.byType(GuestNote);
      expect(
        find.descendant(
          of: note,
          matching: find.text(en.guestNotePermission(en.sharePermissionRead)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: note,
          matching: find.text(
            '${en.guestNoteCanView} ${en.guestNoteNeedsAccount}',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets("a write share's note says the guest may change tasks", (
      tester,
    ) async {
      await pumpGuestTab(tester, permission: Permission.write);

      expect(
        find.text(en.guestNotePermission(en.sharePermissionWrite)),
        findsOneWidget,
      );
      expect(
        find.text('${en.guestNoteCanChange} ${en.guestNoteNeedsAccount}'),
        findsOneWidget,
      );
    });

    testWidgets('without a stored permission the note says only what needs '
        'an account', (tester) async {
      await pumpGuestTab(tester, permission: null);

      expect(
        find.descendant(
          of: find.byType(GuestNote),
          matching: find.text(en.guestNoteNeedsAccount),
        ),
        findsOneWidget,
      );
      expect(find.textContaining(en.guestNotePermission('')), findsNothing);
    });

    testWidgets('keeps the reminders, without the switch for the '
        "server's notifications", (tester) async {
      await pumpGuestTab(tester);

      await scrollTo(tester, find.text(en.notificationsReminders));
      expect(find.text(en.notificationsDueDates), findsOneWidget);
      expect(find.text(en.notificationsActivity), findsNothing);
    });

    testWidgets("Remove guest access asks in the guest's words, then forgets "
        'the guest and its secrets', (tester) async {
      final entry = await pumpGuestApp(tester, auth: auth, data: data);
      await openTab(tester, en.tabAccount);

      final remove = find.widgetWithText(OutlinedButton, en.guestRemove);
      await scrollTo(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();

      expect(find.text(en.guestRemoveDialogTitle), findsOneWidget);
      expect(
        find.text(en.guestRemoveDialogBody('Helper', host)),
        findsOneWidget,
      );
      await tester.tap(find.text(en.removeAccountDialogConfirm));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectServerScreen), findsOneWidget);
      expect((await auth.registry.load()).accounts, isEmpty);
      expect(
        auth.secureStore.values.keys,
        isNot(contains(LinkShareStore.hashKey(entry.id))),
      );
      expect(
        auth.secureStore.values.keys,
        isNot(contains(LinkShareStore.tokenKey(entry.id))),
      );
    });
  });

  group('a guest the server no longer accepts', () {
    testWidgets('is asked to open the link again, which brings it back', (
      tester,
    ) async {
      auth.linkShareGateway.serve(
        issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
        name: 'Helper',
      );
      await pumpGuestTab(tester, needsReauth: true);

      expect(find.byType(GuestReauthBanner), findsOneWidget);
      expect(find.text(en.guestReauthTitle), findsOneWidget);
      expect(find.text(en.guestReauthBody(host)), findsOneWidget);
      expect(find.text(en.reauthTitle), findsNothing);
      await tapOpenLinkAgain(tester);

      expect(auth.linkShareGateway.authentications, [(fakeShareHash, null)]);
      expect(find.byType(ReauthBanner), findsNothing);
      final guest = (await auth.registry.load()).activeAccount!.account;
      expect(guest.isLinkShare, isTrue);
      expect(guest.needsReauth, isFalse);
    });

    testWidgets("asks for the share's password, keeps the sheet on a wrong "
        'one and never stores it', (tester) async {
      auth.linkShareGateway.serve(
        issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
        password: 'right-one',
        name: 'Helper',
      );
      await pumpGuestTab(tester, needsReauth: true);

      await tapOpenLinkAgain(tester, asksPassword: true);

      // Held open for a frame, as a real request is.
      final held = auth.linkShareGateway.holdNextAuthentication();
      await submitPassword(tester, 'wrong-one');
      held.complete();
      await pumpFrames(tester, 5);
      expect(find.byType(SharePasswordSheet), findsOneWidget);
      expect(find.text(en.guestPasswordWrong), findsOneWidget);
      // Ready for the next try, the wrong one selected to type over.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 9),
      );

      await submitPassword(tester, 'right-one');
      await tester.pumpAndSettle();

      expect(find.byType(SharePasswordSheet), findsNothing);
      expect(find.byType(ReauthBanner), findsNothing);
      expect(auth.linkShareGateway.authentications, [
        (fakeShareHash, null),
        (fakeShareHash, 'wrong-one'),
        (fakeShareHash, 'right-one'),
      ]);
      expect(
        auth.secureStore.values.values,
        isNot(anyElement(contains('-one'))),
      );
    });

    testWidgets('closing the password sheet leaves the banner as it was', (
      tester,
    ) async {
      auth.linkShareGateway.serve(
        issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
        password: 'right-one',
      );
      await pumpGuestTab(tester, needsReauth: true);

      await tapOpenLinkAgain(tester, asksPassword: true);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(SharePasswordSheet), findsNothing);
      expect(find.byType(GuestReauthBanner), findsOneWidget);
      expect(find.byType(ConnectionErrorCard), findsNothing);
      expect(
        find.widgetWithText(FilledButton, en.guestOpenLinkAgain),
        findsOneWidget,
      );
    });

    testWidgets('a deleted link says so and keeps the banner', (tester) async {
      auth.linkShareGateway.onAuthenticate = (_, _) async =>
          throw const LinkShareGone(code: 3006);
      await pumpGuestTab(tester, needsReauth: true);

      await tapOpenLinkAgain(tester);

      expect(find.byType(GuestReauthBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ConnectionErrorCard),
          matching: find.text(en.guestLinkGoneTitle),
        ),
        findsOneWidget,
      );
      expect(
        (await auth.registry.load()).activeAccount!.account.needsReauth,
        isTrue,
      );
    });

    testWidgets('link sharing turned off on the server says so', (
      tester,
    ) async {
      auth.linkShareGateway.onAuthenticate = (_, _) async =>
          throw const LinkShareGone();
      await pumpGuestTab(tester, needsReauth: true);

      await tapOpenLinkAgain(tester);

      expect(
        find.descendant(
          of: find.byType(ConnectionErrorCard),
          matching: find.text(en.guestSharingOffSuggestion),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failure on the way is worded and the button works again', (
      tester,
    ) async {
      auth.linkShareGateway.onAuthenticate = (_, _) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await pumpGuestTab(tester, needsReauth: true);

      await tapOpenLinkAgain(tester);

      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      final button = find.widgetWithText(FilledButton, en.guestOpenLinkAgain);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('before its first sync, the first sync screen asks the '
        'same', (tester) async {
      data = SyncFakes(status: const SyncNeverRun());
      auth.linkShareGateway.serve(
        issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
      );
      await pumpGuestApp(tester, auth: auth, data: data, needsReauth: true);

      expect(find.byType(FirstSyncScreen), findsOneWidget);
      expect(find.byType(GuestReauthBanner), findsOneWidget);
      expect(find.text(en.reauthAction), findsNothing);
      // The first sync's progress follows, which never settles.
      final button = find.widgetWithText(FilledButton, en.guestOpenLinkAgain);
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await pumpFrames(tester, 10);

      expect(auth.linkShareGateway.authentications, hasLength(1));
      expect(find.byType(GuestReauthBanner), findsNothing);
    });

    testWidgets('its tile in the switcher says to open the link again', (
      tester,
    ) async {
      await pumpGuestApp(tester, auth: auth, data: data, needsReauth: true);

      await openSwitcher(tester);

      final tile = inSheet(find.byType(AccountTile));
      expect(
        find.descendant(of: tile, matching: find.text(en.guestOpenLinkAgain)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(en.accountBadgeSignInAgain),
        ),
        findsNothing,
      );
    });
  });

  group('the switcher', () {
    testWidgets('names a guest by its share and server, with a link for '
        'its avatar', (tester) async {
      await seedUser(
        auth,
        fullServer270(),
        userId: 7,
        username: 'alice',
        displayName: 'Alice Example',
      );
      await pumpGuestApp(tester, auth: auth, data: data);

      expect(
        tester.getSemantics(find.byType(AccountSwitcherButton)),
        isSemantics(label: en.guestSwitcherButton('Helper', host)),
      );
      await openSwitcher(tester);

      final guestTile = inSheet(
        find.ancestor(
          of: find.text('Helper'),
          matching: find.byType(AccountTile),
        ),
      );
      expect(
        find.descendant(of: guestTile, matching: find.byIcon(Icons.link)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: guestTile,
          matching: find.text(en.guestAccountSubtitle(host)),
        ),
        findsOneWidget,
      );
      expect(
        inSheet(find.text(en.accountSubtitle('alice', host))),
        findsOneWidget,
      );
    });

    testWidgets('removing a guest from the Accounts section asks in the '
        "guest's words", (tester) async {
      final alice = await seedUser(
        auth,
        fullServer270(),
        userId: 7,
        username: 'alice',
        displayName: 'Alice Example',
      );
      await auth.seedGuest(
        fullServer270(),
        token: issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
        activate: false,
      );
      await auth.registry.setActive(alice.id);
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: data,
        overrides: guestEntryOverrides(),
      );
      await openTab(tester, en.tabAccount);

      final menu = find.byTooltip(en.accountMoreActions('Helper'));
      await scrollTo(tester, menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.accountRemove));
      await tester.pumpAndSettle();

      expect(find.text(en.guestRemoveDialogTitle), findsOneWidget);
      expect(
        find.text(en.guestRemoveDialogBody('Helper', host)),
        findsOneWidget,
      );
      await tester.tap(find.text(en.removeAccountDialogConfirm));
      await tester.pumpAndSettle();

      expect(find.text(en.guestRemoved('Helper')), findsOneWidget);
      final accounts = (await auth.registry.load()).accounts;
      expect(accounts.map((entry) => entry.id), [alice.id]);
    });
  });
}
