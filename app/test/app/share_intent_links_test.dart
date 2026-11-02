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

  testWidgets('signed out, an invite goes to its check', (tester) async {
    invites.onCheck = (_) async => InvitePreview(name: 'Autumn helpers');
    data.shareSource.push(IncomingShare(text: inviteLink()));
    await pumpSignedOut(tester);

    expect(sheet, findsNothing);
    expect(find.byType(InviteCard), findsOneWidget);
    expect(find.text('Autumn helpers'), findsOneWidget);
    expect(invites.checkedTokens, [fakeInviteToken]);
    expect(data.shareSource.calls.last, 'clear');
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
