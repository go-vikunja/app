import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_share_form_sheet.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_share_sheet.dart';
import 'package:vikunja_mobile/features/sharing/presentation/project_share_page.dart';
import 'package:vikunja_mobile/features/sharing/presentation/qr_code_view.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/team_sharing_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 26, 12);
  const me = User(id: 7, username: 'alice', name: 'Alice');
  const owner = User(id: 2, username: 'olga', name: 'Olga Owner');
  const ben = User(id: 3, username: 'ben', name: 'Ben Brown');
  const kim = User(id: 4, username: 'kim', name: 'Kim Kowalski');
  late SyncFakes data;

  Project project({Permission? permission = Permission.admin}) => Project(
    id: 1,
    title: 'Work',
    owner: owner,
    views: [
      sampleListView(id: 10, projectId: 1),
      sampleKanbanView(id: 13, projectId: 1),
    ],
    maxPermission: permission,
  );

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [project()];
    data.sharing
      ..people = [ben, kim, owner, me]
      ..ownerUsername = owner.username
      ..teamNames = {
        30: (name: 'Design', memberCount: 4),
        31: (name: 'Support', memberCount: 2),
      }
      ..projects[1] = FakeProjectShares(
        users: [
          const ProjectUserShare(user: me, permission: Permission.admin),
          const ProjectUserShare(user: ben, permission: Permission.read),
        ],
        teams: [
          const ProjectTeamShare(
            teamId: 30,
            teamName: 'Design',
            memberCount: 4,
            permission: Permission.write,
          ),
          const ProjectTeamShare(teamId: 99, permission: Permission.read),
        ],
        links: [
          LinkShare(
            id: 5,
            hash: fakeLinkShareHash(5),
            permission: Permission.read,
            name: 'Family',
            passwordProtected: true,
            sharedBy: owner,
          ),
        ],
      );
    data.users.everyone = [me, owner, ben, kim];
    data.teams.teams = [
      Team(
        id: 30,
        name: 'Design',
        members: const [TeamMember(user: me)],
      ),
      Team(
        id: 31,
        name: 'Support',
        members: const [
          TeamMember(user: me),
          TeamMember(user: kim),
        ],
      ),
    ];
  });

  Future<void> pumpSharePage(WidgetTester tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    final router = containerOf(tester).read(appRouterProvider)
      ..go(AppRoutes.project(1));
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.projectShare(1)));
    await tester.pumpAndSettle();
  }

  Finder sheetText(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  Finder dialogText(String text) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(text));

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProjectSharePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  group('an admin', () {
    testWidgets('the page starts right below the app bar under a status bar', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 600);
      addTearDown(tester.view.resetPadding);
      await pumpSharePage(tester);

      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      final firstCard = tester.getTopLeft(find.byType(SectionCard).first).dy;
      expect(firstCard - appBarBottom, lessThan(80));
    });

    testWidgets('sees people, teams and links with what each may do', (
      tester,
    ) async {
      await pumpSharePage(tester);

      expect(find.text(en.sharePageTitle('Work')), findsOneWidget);
      expect(find.text(en.shareUserIsYou('Alice')), findsOneWidget);
      expect(find.text('Ben Brown'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, en.sharePermissionRead),
        findsWidgets,
      );
      expect(find.text('Design'), findsOneWidget);
      expect(
        find.text('${en.sharePermissionWrite} · ${en.shareTeamMemberCount(4)}'),
        findsOneWidget,
      );
      expect(find.text(en.shareHiddenTeam), findsOneWidget);
      expect(find.text(en.shareReadOnlyNote), findsNothing);
      await scrollTo(tester, find.text(en.linkShareCreate));
      expect(find.text('Family'), findsOneWidget);
      expect(
        find.text(
          '${en.sharePermissionRead} · ${en.linkSharePasswordProtected}',
        ),
        findsOneWidget,
      );
      expect(find.text(en.linkShareCreatedBy('Olga Owner')), findsOneWidget);
      expect(find.text(en.linkShareView('List')), findsOneWidget);
      // The hash only ever shows inside the link's URL.
      expect(find.textContaining(fakeLinkShareHash(5)), findsNothing);
    });

    testWidgets('adds a person found by username with the chosen '
        'permission, never offering who has access', (tester) async {
      await pumpSharePage(tester);

      await tester.tap(find.text(en.shareAddPerson));
      await tester.pumpAndSettle();
      expect(sheetText(en.sharePeopleSearchHint), findsOneWidget);

      for (final query in ['alice', 'olga', 'ben']) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(sheetText(en.sharePeopleNoResults), findsOneWidget);
      }
      await tester.enterText(find.byType(TextField), 'KIM');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(sheetText('Kim Kowalski'));
      await tester.pumpAndSettle();

      expect(sheetText(en.sharePermissionFor('Kim Kowalski')), findsOneWidget);
      await tester.tap(sheetText(en.sharePermissionWrite));
      await tester.pumpAndSettle();

      expect(data.sharing.calls, contains('shareWithUser 1 kim write'));
      expect(find.text(en.shareAdded('Kim Kowalski')), findsOneWidget);
      expect(find.text('Kim Kowalski'), findsOneWidget);
    });

    testWidgets("changes a person's permission from the row", (tester) async {
      await pumpSharePage(tester);

      await tester.tap(find.text('Ben Brown'));
      await tester.pumpAndSettle();
      expect(sheetText(en.shareAccessFor('Ben Brown')), findsOneWidget);
      await tester.tap(sheetText(en.sharePermissionAdmin));
      await tester.pumpAndSettle();

      expect(data.sharing.calls, contains('setUserPermission 1 ben admin'));
      expect(find.text(en.sharePermissionChanged('Ben Brown')), findsOneWidget);
    });

    testWidgets('removes a person after a confirmation that lists what the '
        'server cleans up', (tester) async {
      await pumpSharePage(tester);

      await tester.tap(find.text('Ben Brown'));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.shareRemove));
      await tester.pumpAndSettle();

      expect(dialogText(en.shareRemoveTitle('Ben Brown')), findsOneWidget);
      final body = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(Dialog),
              matching: find.textContaining(
                en.shareRemovePersonBody('Ben Brown'),
              ),
            ),
          )
          .data!;
      expect(body, contains('• ${en.shareCleanupOthersAssignments}'));
      expect(body, contains('• ${en.shareCleanupOthersWebhooks}'));
      await tester.tap(dialogText(en.shareRemove));
      await tester.pumpAndSettle();

      expect(data.sharing.calls, contains('removeUserShare 1 ben'));
      expect(find.text('Ben Brown'), findsNothing);
    });

    testWidgets("removing the user's own share speaks to them", (tester) async {
      await pumpSharePage(tester);

      await tester.tap(find.text(en.shareUserIsYou('Alice')));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.shareRemove));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining(en.shareCleanupSelfAssignments),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lowering their own share asks first, saying what they may '
        'lose', (tester) async {
      await pumpSharePage(tester);

      Future<void> chooseWrite() async {
        await tester.tap(find.text(en.shareUserIsYou('Alice')));
        await tester.pumpAndSettle();
        await tester.tap(sheetText(en.sharePermissionWrite));
        await tester.pumpAndSettle();
      }

      await chooseWrite();
      expect(dialogText(en.shareLowerOwnAccessTitle), findsOneWidget);
      expect(dialogText(en.shareLowerOwnAccessAdminBody), findsOneWidget);
      await tester.tap(dialogText(en.cancel));
      await tester.pumpAndSettle();
      expect(
        data.sharing.calls,
        isNot(contains('setUserPermission 1 alice write')),
      );

      await chooseWrite();
      await tester.tap(dialogText(en.shareLowerOwnAccessConfirm));
      await tester.pumpAndSettle();
      expect(data.sharing.calls, contains('setUserPermission 1 alice write'));
    });

    testWidgets('removing their own share ends on having no access, not on a '
        'deleted project', (tester) async {
      await pumpSharePage(tester);

      await tester.tap(find.text(en.shareUserIsYou('Alice')));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.shareRemove));
      await tester.pumpAndSettle();
      await tester.tap(dialogText(en.shareRemove));
      await tester.pumpAndSettle();
      expect(data.sharing.calls, contains('removeUserShare 1 alice'));
      expect(find.text(en.shareRemovedSelf), findsOneWidget);

      // The sync the removal starts takes the project away.
      data.projects.all = [];
      await tester.pumpAndSettle();

      expect(find.text(en.shareNoAccessTitle), findsOneWidget);
      expect(find.text(en.projectGoneTitle), findsNothing);
    });

    testWidgets('a team synced from a sign-in provider shows its initials '
        'without the provider, in the list and when adding', (tester) async {
      data.sharing.projects[1]!.teams = [
        ...data.sharing.projects[1]!.teams,
        const ProjectTeamShare(
          teamId: 32,
          teamName: 'Ops (Keycloak)',
          memberCount: 3,
          permission: Permission.read,
        ),
      ];
      data.teams.teams = [
        ...data.teams.teams,
        Team(
          id: 33,
          name: 'Developers (Keycloak)',
          isExternal: true,
          members: const [TeamMember(user: me)],
        ),
      ];
      await pumpSharePage(tester);

      Finder initials(String row) => find.descendant(
        of: find.widgetWithText(ListTile, row),
        matching: find.byType(CircleAvatar),
      );
      expect(
        find.descendant(
          of: initials('Ops (Keycloak)'),
          matching: find.text('O'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(en.shareAddTeam));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: initials('Developers (Keycloak)'),
          matching: find.text('D'),
        ),
        findsOneWidget,
      );
      expect(find.text('D('), findsNothing);
    });

    testWidgets("each link's share button and row say which link they are "
        'for', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSharePage(tester);
      await scrollTo(tester, find.text(en.linkShareCreate));

      expect(find.byTooltip(en.linkShareShareNamed('Family')), findsOneWidget);
      expect(find.byTooltip(en.linkShareShare), findsNothing);
      expect(
        tester.getSemantics(find.text('Family')),
        isSemantics(onTapHint: en.linkShareRowHint),
      );
      expect(
        tester.getSemantics(find.text('Ben Brown')),
        isSemantics(onTapHint: en.shareChangeAccessHint),
      );
      semantics.dispose();
    });

    testWidgets('the app bar reads the shares again', (tester) async {
      await pumpSharePage(tester);
      final before = data.sharing.calls
          .where((call) => call == 'userShares 1')
          .length;

      await tester.tap(find.byTooltip(en.refresh));
      await tester.pumpAndSettle();

      expect(
        data.sharing.calls.where((call) => call == 'userShares 1'),
        hasLength(before + 1),
      );
    });

    testWidgets('changes a team the server hides by its id', (tester) async {
      await pumpSharePage(tester);

      await tester.tap(find.text(en.shareHiddenTeam));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.sharePermissionWrite));
      await tester.pumpAndSettle();

      expect(data.sharing.calls, contains('setTeamPermission 1 99 write'));
    });

    testWidgets('adds one of their teams that has no access yet', (
      tester,
    ) async {
      await pumpSharePage(tester);

      await tester.tap(find.text(en.shareAddTeam));
      await tester.pumpAndSettle();
      expect(sheetText('Design'), findsNothing);
      await tester.tap(sheetText('Support'));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.sharePermissionRead));
      await tester.pumpAndSettle();

      expect(data.sharing.calls, contains('shareWithTeam 1 31 read'));
      expect(find.text('Support'), findsOneWidget);
    });

    testWidgets('creates a link with a password, then shares, copies and '
        'shows it as a QR code; the hash is never logged', (tester) async {
      final records = <String>[];
      final subscription = Logger.root.onRecord.listen(
        (record) => records.add('${record.message} ${record.error}'),
      );
      addTearDown(subscription.cancel);
      await pumpSharePage(tester);

      await scrollTo(tester, find.text(en.linkShareCreate));
      await tester.tap(find.text(en.linkShareCreate));
      await tester.pumpAndSettle();
      expect(find.byType(LinkShareFormSheet), findsOneWidget);
      await tester.tap(sheetText(en.linkShareFormPermission));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.sharePermissionWrite).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, en.linkShareFormName),
        'Guests',
      );
      await tester.enterText(
        find.widgetWithText(TextField, en.linkShareFormPassword),
        'secret-pass',
      );
      await tester.tap(sheetText(en.linkShareFormSubmit));
      await tester.pumpAndSettle();

      expect(data.sharing.createdLinks.single.permission, Permission.write);
      expect(data.sharing.createdLinks.single.name, 'Guests');
      expect(data.sharing.createdLinks.single.password, 'secret-pass');
      expect(find.byType(LinkShareSheet), findsOneWidget);
      expect(sheetText(en.linkShareCreated), findsOneWidget);
      final hash = fakeLinkShareHash(6);
      final url = 'https://tasks.example.org/vikunja/share/$hash/auth?view=10';

      await tester.tap(sheetText(en.linkShareCopy));
      await tester.pumpAndSettle();
      expect(data.clipboard.copied, [url]);

      await tester.tap(sheetText(en.linkShareShare));
      await tester.pumpAndSettle();
      expect(data.linkShares.shared.single.url.toString(), url);
      expect(
        data.linkShares.shared.single.subject,
        en.linkShareSubject('Work'),
      );

      await tester.tap(sheetText(en.linkShareQr));
      await tester.pumpAndSettle();
      expect(find.byType(QrCodeView), findsOneWidget);
      expect(find.bySemanticsLabel(en.linkShareQrSemantics), findsOneWidget);
      expect(find.text(url), findsOneWidget);

      expect(records.where((record) => record.contains(hash)), isEmpty);
      expect(
        records.where((record) => record.contains('secret-pass')),
        isEmpty,
      );
    });

    testWidgets('picks the view a link opens for the row and the sheet', (
      tester,
    ) async {
      await pumpSharePage(tester);

      await scrollTo(tester, find.text('Family'));
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.linkShareViewTitle));
      await tester.pumpAndSettle();
      await tester.tap(sheetText('Kanban').last);
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.linkShareCopy));
      await tester.pumpAndSettle();

      expect(
        data.clipboard.copied.single,
        'https://tasks.example.org/vikunja/share/${fakeLinkShareHash(5)}/auth'
        '?view=13',
      );
      await tester.tap(sheetText(en.pickerDone));
      await tester.pumpAndSettle();
      expect(find.text(en.linkShareView('Kanban')), findsOneWidget);
    });

    testWidgets('deletes a link after saying who loses access', (tester) async {
      await pumpSharePage(tester);

      await scrollTo(tester, find.text('Family'));
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.linkShareDelete));
      await tester.pumpAndSettle();
      expect(dialogText(en.linkShareDeleteTitle('Family')), findsOneWidget);
      expect(dialogText(en.linkShareDeleteBody), findsOneWidget);
      await tester.tap(dialogText(en.linkShareDelete));
      await tester.pumpAndSettle();

      expect(data.sharing.calls, contains('deleteLinkShare 1 5'));
      expect(find.text('Family'), findsNothing);
      expect(find.text(en.linkShareDeleted), findsOneWidget);
    });

    testWidgets('says that link sharing is off when the server has no link '
        'routes', (tester) async {
      data.sharing.linkSharingEnabled = false;
      await pumpSharePage(tester);

      await scrollTo(tester, find.text(en.shareFailureLinkSharingOff));
      expect(find.text(en.linkShareCreate), findsNothing);
    });

    testWidgets('says why a change was refused', (tester) async {
      await pumpSharePage(tester);
      data.sharing.failures['setUserPermission'] = const Forbidden();

      await tester.tap(find.text('Ben Brown'));
      await tester.pumpAndSettle();
      await tester.tap(sheetText(en.sharePermissionWrite));
      await tester.pumpAndSettle();

      expect(find.text(en.shareFailureForbidden), findsOneWidget);
    });
  });

  group('someone who is not admin', () {
    testWidgets('sees the people and teams only, and why', (tester) async {
      data.projects.all = [project(permission: Permission.write)];
      await pumpSharePage(tester);

      expect(find.text(en.shareReadOnlyNote), findsOneWidget);
      expect(find.text('Ben Brown'), findsOneWidget);
      expect(find.text(en.shareAddPerson), findsNothing);
      expect(find.text(en.shareAddTeam), findsNothing);
      expect(find.text(en.shareLinksSection), findsNothing);
      expect(data.sharing.calls, isNot(contains('linkShares 1')));

      await tester.tap(find.text('Ben Brown'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  testWidgets('offline, says so and reads again once back', (tester) async {
    data.sharing.failure = const NetworkFailure(NetworkProblem.unreachable);
    await pumpSharePage(tester);

    expect(find.byType(OfflineNotice), findsOneWidget);
    data.sharing.failure = null;
    await pullToRefresh(tester, find.byType(ListView).last);

    expect(find.byType(OfflineNotice), findsNothing);
    expect(find.text('Ben Brown'), findsOneWidget);
  });

  testWidgets('the project menu opens the share page', (tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.shareMenuItem));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectSharePage), findsOneWidget);
  });
}
