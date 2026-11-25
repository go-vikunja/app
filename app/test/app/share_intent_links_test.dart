import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/link_share_account_id.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/invite_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/share/presentation/open_shared_link_sheet.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/guest_entry_fakes.dart';
import '../helpers/guest_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';

void main() {
  final server = fullServer270();
  final guestId = linkShareAccountIdFor(server.rootUri, 84);
  late AuthFakes auth;
  late SyncFakes data;
  late FakeInviteLinksPort invites;
  late LinkShareToken token;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
    data.projects.all = [sampleProject(id: 1378, title: 'Garden')];
    invites = FakeInviteLinksPort();
    token = issueLinkShareToken(issuedAt: DateTime.now().toUtc());
    auth.linkShareGateway.serve(token);
  });

  final sheet = find.byType(OpenSharedLinkSheet);

  Finder inSheet(Finder finder) => find.descendant(of: sheet, matching: finder);

  Future<void> pumpSignedOut(WidgetTester tester) => pumpVikunjaApp(
    tester,
    auth: auth,
    sync: data,
    connector: FakeServerConnector.succeeding(server),
    overrides: guestEntryOverrides(invites: invites),
  );

  Future<AuthFakes> pumpSignedIn(WidgetTester tester) => pumpSignedInApp(
    tester,
    auth: auth,
    sync: data,
    overrides: [...guestEntryOverrides(invites: invites)],
  );

  final apiServer = fullServer270(root: 'https://api.example.org');

  /// Signed in on another server, opens a shared link whose host has no API.
  Future<void> pumpSignedInWithWebOnlyLink(WidgetTester tester) async {
    usePhoneSurface(tester);
    final other = fullServer270(root: 'https://other.example.org');
    await auth.seedAccount(
      other,
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      connector: FakeServerConnector(
        (input) async => switch (input) {
          'api.example.org' => apiServer,
          'https://other.example.org' => other,
          _ => throw NotAVikunjaServer(
            Uri.parse('https://tasks.example.org/vikunja/'),
            statusCode: 200,
          ),
        },
      ),
      overrides: guestEntryOverrides(invites: invites),
    );
    data.shareSource.push(IncomingShare(text: shareLink()));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text(en.guestShareOpen)));
    await tester.pumpAndSettle();
  }

  testWidgets("signed out, a shared project's link opens as a guest", (
    tester,
  ) async {
    data.shareSource.push(IncomingShare(text: 'Our plan: ${shareLink()}'));
    await pumpSignedOut(tester);

    expect(sheet, findsOneWidget);
    expect(
      inSheet(find.text(en.guestShareBody('tasks.example.org'))),
      findsOneWidget,
    );
    expect(inSheet(find.text(en.guestShareNewTask)), findsNothing);
    expect(find.text(en.shareSignedOut), findsNothing);

    await tester.tap(inSheet(find.text(en.guestShareOpen)));
    await tester.pumpAndSettle();

    expect(data.shareSource.calls, ['pending', 'clear']);
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect((await auth.registry.load()).activeAccountId, guestId);
  });

  testWidgets('closing the question drops the share', (tester) async {
    data.shareSource.push(IncomingShare(text: shareLink()));
    await pumpSignedOut(tester);

    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(data.shareSource.calls.last, 'clear');
    expect(auth.linkShareGateway.authentications, isEmpty);
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });

  testWidgets('signed in, the link can still become a task', (tester) async {
    await pumpSignedIn(tester);
    data.shareSource.push(
      IncomingShare(subject: 'Garden plan', text: shareLink()),
    );
    await tester.pumpAndSettle();

    await tester.tap(inSheet(find.text(en.guestShareNewTask)));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(find.byType(ShareSheet), findsOneWidget);
    expect(auth.linkShareGateway.authentications, isEmpty);
  });

  testWidgets('signed in, the guest is added beside the account', (
    tester,
  ) async {
    final user = await pumpSignedIn(tester);
    final userId = (await user.registry.load()).activeAccountId;
    data.shareSource.push(IncomingShare(text: shareLink(viewId: 4)));
    await tester.pumpAndSettle();

    await tester.tap(inSheet(find.text(en.guestShareOpen)));
    await tester.pumpAndSettle();

    final registry = await auth.registry.load();
    expect(registry.activeAccountId, guestId);
    expect(registry.find(userId), isNotNull);
    expect(
      tester.widget<ProjectTasksScreen>(find.byType(ProjectTasksScreen)),
      isA<ProjectTasksScreen>()
          .having((screen) => screen.projectId, 'projectId', 1378)
          .having((screen) => screen.viewId, 'viewId', 4),
    );
  });

  testWidgets('signed in over a typed New task sheet, a newer share during '
      "the link's question asks again, without saying the user kept editing", (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(NewTaskSheet),
        matching: find.byType(TextField),
      ),
      'Buy milk',
    );
    await tester.pumpAndSettle();
    data.shareSource.push(IncomingShare(text: shareLink()));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text(en.guestShareOpen)));
    await tester.pumpAndSettle();
    expect(find.text(en.newTaskDiscardTitle), findsOneWidget);

    data.shareSource.push(const IncomingShare(text: 'Second'));
    await tester.pumpAndSettle();

    expect(find.text(en.newTaskDiscardTitle), findsOneWidget);
    expect(find.text(en.shareKeptEditing), findsNothing);
    expect(find.widgetWithText(TextField, 'Buy milk'), findsOneWidget);
    expect(find.byType(ConnectServerScreen), findsNothing);
    expect(auth.linkShareGateway.authentications, isEmpty);
  });

  testWidgets('signed in, a link whose host is no Vikunja server asks which '
      'server it is, in view and without the keyboard', (tester) async {
    await pumpSignedInWithWebOnlyLink(tester);
    // A phone's keyboard takes 300 dp while it shows.
    tester.view.viewInsets = FakeViewPadding(
      bottom: tester.testTextInput.isVisible ? 900 : 0,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.text(en.guestServerNeededTitle).hitTestable(), findsOneWidget);
    expect(
      find.text(en.guestServerNeededSuggestion).hitTestable(),
      findsOneWidget,
    );
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
    expect(auth.linkShareGateway.authentications, isEmpty);
    expect(data.shareSource.calls.last, 'clear');
  });

  testWidgets('signed in, that link opens as a guest beside the account at '
      'the address given for it', (tester) async {
    await pumpSignedInWithWebOnlyLink(tester);
    final userId = (await auth.registry.load()).activeAccountId;

    final field = find.byType(TextFormField);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'api.example.org');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    final registry = await auth.registry.load();
    expect(
      registry.activeAccountId,
      linkShareAccountIdFor(apiServer.rootUri, 84),
    );
    expect(registry.find(userId), isNotNull);
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
  });

  group('an invite', () {
    late FakeServerConnector connector;

    Future<void> pumpSignedOutCounting(WidgetTester tester) {
      connector = FakeServerConnector.succeeding(server);
      return pumpVikunjaApp(
        tester,
        auth: auth,
        sync: data,
        connector: connector,
        overrides: guestEntryOverrides(invites: invites),
      );
    }

    Future<void> pumpSignedInCounting(WidgetTester tester) async {
      connector = FakeServerConnector.succeeding(server);
      await auth.seedAccount(
        fullServer270(root: 'https://other.example.org'),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: data,
        connector: connector,
        overrides: guestEntryOverrides(invites: invites),
      );
    }

    testWidgets('signed out, asks first and contacts no server; Open goes to '
        'its check', (tester) async {
      invites.onCheck = (_) async => InvitePreview(name: 'Autumn helpers');
      data.shareSource.push(IncomingShare(text: inviteLink()));
      await pumpSignedOutCounting(tester);

      expect(sheet, findsOneWidget);
      expect(inSheet(find.text(en.inviteShareTitle)), findsOneWidget);
      expect(
        inSheet(find.text(en.inviteShareBody('tasks.example.org'))),
        findsOneWidget,
      );
      expect(inSheet(find.text(en.guestShareNewTask)), findsNothing);
      expect(find.byType(InviteCard), findsNothing);
      expect(connector.inputs, isEmpty);
      expect(invites.checkedTokens, isEmpty);
      expect(data.shareSource.calls, ['pending']);

      await tester.tap(inSheet(find.text(en.inviteShareOpen)));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(find.byType(InviteCard), findsOneWidget);
      expect(find.text('Autumn helpers'), findsOneWidget);
      expect(invites.checkedTokens, [fakeInviteToken]);
      expect(data.shareSource.calls.last, 'clear');
    });

    testWidgets('closing the question drops the share and checks nothing', (
      tester,
    ) async {
      data.shareSource.push(IncomingShare(text: inviteLink()));
      await pumpSignedOutCounting(tester);

      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(data.shareSource.calls.last, 'clear');
      expect(connector.inputs, isEmpty);
      expect(invites.checkedTokens, isEmpty);
      expect(find.byType(InviteCard), findsNothing);
    });

    testWidgets('signed in, one among other words can still become a task, '
        'and nothing closed meanwhile', (tester) async {
      await pumpSignedInCounting(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      data.shareSource.push(
        IncomingShare(text: 'Join our board: ${inviteLink()}'),
      );
      await tester.pumpAndSettle();

      expect(sheet, findsOneWidget);
      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(invites.checkedTokens, isEmpty);
      expect(connector.inputs, isEmpty);

      await tester.tap(inSheet(find.text(en.guestShareNewTask)));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find
                  .descendant(
                    of: find.byType(ShareSheet),
                    matching: find.byType(TextField),
                  )
                  .first,
            )
            .controller!
            .text,
        startsWith('Join our board:'),
      );
      expect(invites.checkedTokens, isEmpty);
      expect(find.byType(InviteCard), findsNothing);
    });

    testWidgets('signed in, Open checks it for another account', (
      tester,
    ) async {
      invites.onCheck = (_) async => InvitePreview(name: 'Autumn helpers');
      await pumpSignedInCounting(tester);
      data.shareSource.push(IncomingShare(text: inviteLink()));
      await tester.pumpAndSettle();

      await tester.tap(inSheet(find.text(en.inviteShareOpen)));
      await tester.pumpAndSettle();

      expect(find.byType(InviteCard), findsOneWidget);
      expect(invites.checkedTokens, [fakeInviteToken]);
      expect(connector.inputs, isNotEmpty);
      expect(data.shareSource.calls.last, 'clear');
    });
  });

  testWidgets('a share with files is never taken for a link', (tester) async {
    await pumpSignedIn(tester);
    data.shareSource.push(
      IncomingShare(
        text: shareLink(),
        files: const [
          SharedFile(uri: 'content://files.example/1', displayName: 'a.pdf'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(find.byType(ShareSheet), findsOneWidget);
  });
}
