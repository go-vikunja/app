import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/link_share_account_id.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/invite_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/share_password_sheet.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/shared_link_sheet.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/guest_entry_fakes.dart';
import '../../../helpers/guest_fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';

final Finder _addressField = find.byType(TextFormField);
final Finder _continueButton = find.widgetWithText(
  FilledButton,
  en.connectContinue,
);

/// Text on screen that shows a secret, outside the field it was typed in.
Finder _shownSecret(String secret) => find.byWidgetPredicate(
  (widget) => switch (widget) {
    Text(:final data?) => data.contains(secret),
    Text(:final textSpan?) => textSpan.toPlainText().contains(secret),
    _ => false,
  },
);

void main() {
  const base = 'https://tasks.example.org/vikunja/';
  final server = fullServer270();
  final guestId = linkShareAccountIdFor(server.rootUri, 84);
  late AuthFakes auth;
  late SyncFakes data;
  late FakeServerConnector connector;
  late FakeInviteLinksPort invites;
  late FakeExternalLinkOpener opener;
  late LinkShareToken token;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
    data.projects.all = [sampleProject(id: 1378, title: 'Garden')];
    connector = FakeServerConnector.succeeding(server);
    invites = FakeInviteLinksPort();
    opener = FakeExternalLinkOpener();
    token = issueLinkShareToken(issuedAt: DateTime.now().toUtc());
  });

  Future<void> pump(WidgetTester tester) => pumpVikunjaApp(
    tester,
    connector: connector,
    auth: auth,
    sync: data,
    linkOpener: opener,
    overrides: guestEntryOverrides(invites: invites),
  );

  Future<void> submit(WidgetTester tester, String address) async {
    await tester.enterText(_addressField, address);
    await tester.tap(_continueButton);
    await tester.pump();
  }

  Finder inPasswordSheet(Finder finder) =>
      find.descendant(of: find.byType(SharePasswordSheet), matching: finder);

  Future<void> submitPassword(WidgetTester tester, String password) async {
    await tester.enterText(inPasswordSheet(find.byType(TextField)), password);
    await tester.pump();
    await tester.tap(inPasswordSheet(find.text(en.guestLinkOpen)));
    await tester.pumpAndSettle();
  }

  group('a pasted shared link', () {
    testWidgets("opens the project as a guest in the link's view, never "
        'showing its secret', (tester) async {
      final probe = Completer<ServerConnection>();
      connector.handler = (_) => probe.future;
      auth.linkShareGateway.serve(token);
      await pump(tester);

      await submit(tester, shareLink(viewId: 12));

      expect(
        find.text(en.guestConnectingTo('${base}share/xxxx…/auth')),
        findsOneWidget,
      );
      expect(_shownSecret(fakeShareHash), findsNothing);

      probe.complete(server);
      await tester.pumpAndSettle();

      expect(connector.inputs, [base]);
      expect(
        tester.widget<ProjectTasksScreen>(find.byType(ProjectTasksScreen)),
        isA<ProjectTasksScreen>()
            .having((screen) => screen.projectId, 'projectId', 1378)
            .having((screen) => screen.viewId, 'viewId', 12),
      );
      expect(find.text('Garden'), findsWidgets);
      final registry = await auth.registry.load();
      expect(registry.activeAccountId, guestId);
    });

    testWidgets('with a password asks for it, says when it is wrong and '
        'opens with the right one', (tester) async {
      auth.linkShareGateway.serve(token, password: 'tomato');
      await pump(tester);

      await submit(tester, shareLink());
      await tester.pumpAndSettle();

      expect(find.byType(SharePasswordSheet), findsOneWidget);
      expect(find.text(en.guestPasswordBody), findsOneWidget);
      expect(
        inPasswordSheet(find.text(en.guestPasswordSentTo('tasks.example.org'))),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(
        inPasswordSheet(find.byType(TextField)),
      );
      expect(field.obscureText, isTrue);
      expect(field.autofillHints, isNull);
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);

      // Held open for a frame, as a real request is.
      final held = auth.linkShareGateway.holdNextAuthentication();
      await tester.enterText(inPasswordSheet(find.byType(TextField)), 'potato');
      await tester.pump();
      await tester.tap(inPasswordSheet(find.text(en.guestLinkOpen)));
      await tester.pump();
      held.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SharePasswordSheet), findsOneWidget);
      expect(find.text(en.guestPasswordWrong), findsOneWidget);
      final retry = tester.widget<TextField>(
        inPasswordSheet(find.byType(TextField)),
      );
      expect(retry.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byTooltip(en.linkShareFormShowPassword));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(inPasswordSheet(find.byType(TextField)))
            .obscureText,
        isFalse,
      );

      await submitPassword(tester, 'tomato');

      expect(find.byType(SharePasswordSheet), findsNothing);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(auth.linkShareGateway.authentications.last, (
        fakeShareHash,
        'tomato',
      ));
    });

    testWidgets('added as an account, offers neither Cancel nor Close once '
        'its server has answered, until the guest is in', (tester) async {
      usePhoneSurface(tester);
      await auth.seedAccount(
        fullServer270(root: 'https://other.example.org'),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      auth.linkShareGateway.serve(token);
      final answer = auth.linkShareGateway.holdNextAuthentication();
      final storing = Completer<void>();
      auth.secureStore.beforeWrite = (key) async {
        if (key == LinkShareStore.hashKey(guestId)) await storing.future;
      };
      await pump(tester);
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.addAccount),
      );
      await tester.pumpAndSettle();

      await submit(tester, shareLink());
      expect(find.text(en.connectCancel), findsOneWidget);
      expect(find.byType(CloseButton), findsOneWidget);

      answer.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text(en.connectCancel), findsNothing);
      expect(find.byType(CloseButton), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ConnectServerScreen), findsOneWidget);

      storing.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ConnectServerScreen), findsNothing);
      expect((await auth.registry.load()).activeAccountId, guestId);
    });

    testWidgets('added as an account, closed before its server has answered, '
        'stores nothing even when the answer comes while the screen slides '
        'out', (tester) async {
      usePhoneSurface(tester);
      final other = await auth.seedAccount(
        fullServer270(root: 'https://other.example.org'),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      auth.linkShareGateway.serve(token);
      final answer = auth.linkShareGateway.holdNextAuthentication();
      await pump(tester);
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.addAccount),
      );
      await tester.pumpAndSettle();
      await submit(tester, shareLink());
      expect(auth.linkShareGateway.authentications, hasLength(1));

      await tester.tap(find.byType(CloseButton));
      await tester.pump();
      expect(find.byType(ConnectServerScreen), findsOneWidget);
      answer.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ConnectServerScreen), findsNothing);
      final registry = await auth.registry.load();
      expect(registry.find(guestId), isNull);
      expect(registry.activeAccountId, other.id);
      expect(
        auth.secureStore.values.keys.where((key) => key.contains(guestId)),
        isEmpty,
      );
    });

    testWidgets('added as an account while the guest is on this device but '
        "not in use, switches to it and says so after the switch's clean-up", (
      tester,
    ) async {
      usePhoneSurface(tester);
      await auth.seedGuest(server, token: token, activate: false);
      await auth.seedAccount(
        fullServer270(root: 'https://other.example.org'),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      auth.linkShareGateway.serve(token);
      await pump(tester);
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.addAccount),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_addressField, shareLink());
      await tester.ensureVisible(_continueButton);
      await tester.tap(_continueButton);
      await tester.pumpAndSettle();

      expect(find.byType(ConnectServerScreen), findsNothing);
      expect((await auth.registry.load()).activeAccountId, guestId);
      expect(find.text(en.guestAlreadyAdded), findsOneWidget);
    });

    testWidgets('closing the password sheet returns to the address', (
      tester,
    ) async {
      auth.linkShareGateway.serve(token, password: 'tomato');
      await pump(tester);
      await submit(tester, shareLink());
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(SharePasswordSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SharePasswordSheet), findsNothing);
      expect(_continueButton, findsOneWidget);
      expect((await auth.registry.load()).accounts, isEmpty);
    });

    testWidgets('without a view lands on the project as it is', (tester) async {
      auth.linkShareGateway.serve(token);
      await pump(tester);

      await submit(tester, shareLink());
      await tester.pumpAndSettle();

      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(
        data.listPreferences.saves.where((save) => save.startsWith('lastView')),
        isEmpty,
      );
    });

    testWidgets('opened again outside the guest entry stays where the user '
        'is', (tester) async {
      auth.linkShareGateway.serve(token);
      await auth.seedGuest(server, token: token);
      await pump(tester);

      await containerOf(tester).read(guestSignInProvider).reopen(guestId);
      await openTab(tester, en.tabUpcoming);

      expect(find.byType(ProjectTasksScreen), findsNothing);
      expect(find.byType(UpcomingScreen), findsOneWidget);
    });

    testWidgets('that is gone says so', (tester) async {
      auth.linkShareGateway.onAuthenticate = (_, _) async =>
          throw const LinkShareGone(code: 3006);
      await pump(tester);

      await submit(tester, shareLink());
      await tester.pumpAndSettle();

      expect(find.text(en.guestLinkGoneTitle), findsOneWidget);
      expect(
        find.text(en.guestLinkGoneExplanation('tasks.example.org')),
        findsOneWidget,
      );
    });

    testWidgets('whose address is only the web asks for the server and '
        'opens there', (tester) async {
      final apiServer = fullServer270(root: 'https://api.example.org');
      final linkProbe = Completer<ServerConnection>();
      connector.handler = (input) => input == 'api.example.org'
          ? Future.value(apiServer)
          : linkProbe.future;
      auth.linkShareGateway.serve(token);
      await pump(tester);

      // The field is disabled for a frame while the link's base is probed.
      await submit(tester, shareLink());
      linkProbe.completeError(
        NotAVikunjaServer(Uri.parse(base), statusCode: 200),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.guestServerNeededTitle), findsOneWidget);
      expect(
        find.text(en.guestServerNeededExplanation('tasks.example.org')),
        findsOneWidget,
      );
      // The link is no server address.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await submit(tester, 'api.example.org');
      await tester.pumpAndSettle();

      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(
        (await auth.registry.load()).find(
          linkShareAccountIdFor(apiServer.rootUri, 84),
        ),
        isNotNull,
      );
    });
  });

  group("with a stored server that names the link's host as its web", () {
    final claiming = accountPagesServer270(
      root: 'https://evil.example.net',
      frontendUrl: Uri.parse(base),
    );
    final apiServer = fullServer270(root: 'https://api.example.org');

    final claimLine = en.guestServerClaimed(
      'evil.example.net',
      'tasks.example.org',
    );

    /// A focused field first scrolls its caret into view, which can move
    /// Continue below the screen.
    Future<void> tapContinue(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.ensureVisible(_continueButton);
      await tester.pumpAndSettle();
      await tester.tap(_continueButton);
      await tester.pumpAndSettle();
    }

    /// Adds an account over the shell with the link, whose host has no API.
    Future<void> openLink(WidgetTester tester) async {
      usePhoneSurface(tester);
      await auth.seedAccount(
        claiming,
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      connector.handler = (input) async => switch (input) {
        'https://evil.example.net' => claiming,
        'api.example.org' => apiServer,
        _ => throw NotAVikunjaServer(Uri.parse(base), statusCode: 200),
      };
      await pump(tester);
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.addAccount),
      );
      await tester.pumpAndSettle();
      connector.inputs.clear();
      await tester.enterText(_addressField, shareLink());
      await tapContinue(tester);
    }

    testWidgets('fills it in, names both hosts, and sends it the link and '
        'the password only after Continue', (tester) async {
      auth.linkShareGateway.serve(token, password: 'tomato');
      await openLink(tester);

      expect(find.text(en.guestServerNeededTitle), findsOneWidget);
      expect(find.text(en.guestServerNeededSuggestion), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'https://evil.example.net');
      // No keyboard covers the line, and no Go on it sends the link unread.
      expect(field.focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text(claimLine).hitTestable(), findsOneWidget);
      expect(_continueButton.hitTestable(), findsOneWidget);
      expect(connector.inputs, [base]);
      expect(auth.linkShareGateway.authentications, isEmpty);

      await tester.tap(_continueButton);
      await tester.pumpAndSettle();

      expect(
        inPasswordSheet(find.text(en.guestPasswordSentTo('evil.example.net'))),
        findsOneWidget,
      );
      await submitPassword(tester, 'tomato');

      expect(connector.inputs, [base, 'https://evil.example.net']);
      expect(auth.linkShareGateway.authentications, [
        (fakeShareHash, null),
        (fakeShareHash, 'tomato'),
      ]);
      expect(
        auth.linkShareGateway.connections.map((c) => c.rootUri),
        everyElement(claiming.rootUri),
      );
    });

    testWidgets('another address entered instead gets the link', (
      tester,
    ) async {
      auth.linkShareGateway.serve(token);
      await openLink(tester);

      await tester.enterText(_addressField, 'api.example.org');
      await tester.pumpAndSettle();
      expect(find.text(claimLine), findsNothing);
      expect(find.text(en.guestServerNeededSuggestion), findsOneWidget);
      // The card changed its size, but the field being edited keeps the view.
      expect(_addressField.hitTestable(), findsOneWidget);

      await tapContinue(tester);

      expect(connector.inputs, [base, 'api.example.org']);
      expect(auth.linkShareGateway.connections.single, same(apiServer));
    });
  });

  testWidgets('trying the demo while a link waits for its server never '
      'sends the link there', (tester) async {
    connector.handler = (input) async => input == base
        ? throw NotAVikunjaServer(Uri.parse(base), statusCode: 200)
        : fullServer270(root: 'https://try.vikunja.io', demoMode: true);
    auth.linkShareGateway.serve(token);
    await pump(tester);
    await submit(tester, shareLink());
    await tester.pumpAndSettle();
    expect(find.text(en.guestServerNeededTitle), findsOneWidget);

    await tester.ensureVisible(find.text(en.connectTryDemo));
    await tester.tap(find.text(en.connectTryDemo));
    await tester.pumpAndSettle();

    expect(connector.inputs, [base, publicDemoAddress]);
    expect(auth.linkShareGateway.authentications, isEmpty);
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  group('"Open a shared link"', () {
    void useClipboard(WidgetTester tester, String? text) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? (text == null ? null : {'text': text})
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.ensureVisible(find.text(en.guestOpenSharedLink));
      await tester.tap(find.text(en.guestOpenSharedLink));
      await tester.pumpAndSettle();
    }

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(SharedLinkSheet), matching: finder);

    testWidgets('pastes the link and opens it', (tester) async {
      useClipboard(tester, '  ${shareLink()}\n');
      auth.linkShareGateway.serve(token);
      await pump(tester);

      await openSheet(tester);
      expect(find.text(en.guestLinkExplanation), findsOneWidget);
      await tester.tap(inSheet(find.text(en.guestLinkPaste)));
      await tester.pump();
      await tester.tap(inSheet(find.text(en.guestLinkOpen)));
      await tester.pumpAndSettle();

      expect(find.byType(SharedLinkSheet), findsNothing);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    testWidgets('refuses text that is no shared link and an empty '
        'clipboard', (tester) async {
      useClipboard(tester, null);
      await pump(tester);
      await openSheet(tester);

      await tester.tap(inSheet(find.text(en.guestLinkPaste)));
      await tester.pump();
      expect(find.text(en.guestLinkClipboardEmpty), findsOneWidget);

      await tester.enterText(
        inSheet(find.byType(TextField)),
        'https://tasks.example.org/projects/3',
      );
      await tester.pump();
      await tester.tap(inSheet(find.text(en.guestLinkOpen)));
      await tester.pump();

      expect(find.text(en.guestLinkInvalid), findsOneWidget);
      expect(find.byType(SharedLinkSheet), findsOneWidget);
      expect(connector.inputs, isEmpty);
    });
  });

  group('an invite', () {
    testWidgets('shows what it gives, opens in the browser and continues '
        'to sign-in', (tester) async {
      invites.onCheck = (_) async => InvitePreview(
        name: 'Autumn helpers',
        teams: const [
          InviteTeam(id: 1, name: 'Design'),
          InviteTeam(id: 2, name: 'Garden'),
        ],
        skipsEmailConfirmation: true,
      );
      await pump(tester);

      await submit(tester, inviteLink());
      await tester.pumpAndSettle();

      expect(find.byType(InviteCard), findsOneWidget);
      expect(find.text(en.inviteHeading('tasks.example.org')), findsOneWidget);
      expect(find.text('Autumn helpers'), findsOneWidget);
      expect(find.text(en.inviteTeams('Design, Garden')), findsOneWidget);
      expect(find.text(en.inviteNoEmailConfirmation), findsOneWidget);
      expect(_continueButton, findsNothing);
      expect(_shownSecret(fakeInviteToken), findsNothing);

      await tester.tap(find.text(en.inviteCreateAccount));
      await tester.pump();
      expect(opener.opened, [Uri.parse(inviteLink())]);

      await tester.tap(find.text(en.continueToSignIn));
      await tester.pumpAndSettle();
      expect(find.byType(ServerOverviewScreen), findsOneWidget);
    });

    testWidgets('being checked shows only its server', (tester) async {
      final probe = Completer<ServerConnection>();
      connector.handler = (_) => probe.future;
      await pump(tester);

      await submit(tester, inviteLink());

      expect(find.text(en.inviteConnectingTo('tasks.example.org')), findsOne);
      expect(_shownSecret(fakeInviteToken), findsNothing);
      final cancel = find.text(en.connectCancel);
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pump();
      probe.complete(server);
      await tester.pumpAndSettle();
      expect(invites.checkedTokens, isEmpty);
    });

    testWidgets('on a server that cannot check it is still offered', (
      tester,
    ) async {
      invites.onCheck = (_) async => throw const NotFound();
      await pump(tester);

      await submit(tester, inviteLink());
      await tester.pumpAndSettle();

      expect(find.text(en.inviteUnchecked), findsOneWidget);
      expect(find.text(en.inviteCreateAccount), findsOneWidget);
    });

    testWidgets('refused says so; editing the address clears it', (
      tester,
    ) async {
      invites.onCheck = (_) async => throw const NotFound(code: 2005);
      await pump(tester);

      await submit(tester, inviteLink());
      await tester.pumpAndSettle();

      expect(find.text(en.inviteInvalidTitle), findsOneWidget);
      expect(find.text(en.inviteInvalidExplanation), findsOneWidget);

      await tester.enterText(_addressField, 'tasks.example.org');
      await tester.pump();
      expect(find.text(en.inviteInvalidTitle), findsNothing);
    });

    testWidgets('the browser not opening says so', (tester) async {
      opener = FakeExternalLinkOpener(succeeds: false);
      invites.onCheck = (_) async => InvitePreview(name: '');
      await pump(tester);
      await submit(tester, inviteLink());
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.inviteCreateAccount));
      await tester.pump();

      expect(find.text(en.legalOpenFailed), findsOneWidget);
    });
  });
}
