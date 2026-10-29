import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/sharing/presentation/person_search_sheet.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_edit_sheet.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/teams_page.dart';

import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import 'organise_harness.dart';

void main() {
  late OrganiseHarness harness;

  setUp(() => harness = OrganiseHarness());

  Team design({
    List<TeamMember> members = const [
      TeamMember(user: alice, admin: true),
      TeamMember(user: kim),
    ],
    String description = '<p>We draw <strong>things</strong></p>',
    bool isExternal = false,
    String name = 'Design',
  }) => sampleTeam(
    id: 5,
    name: name,
    description: description,
    members: members,
    isExternal: isExternal,
  );

  /// The team's page over the teams page, so that it can close onto it.
  Future<void> openTeam(
    WidgetTester tester, {
    ServerConnection? connection,
    FakeEditorBridges? bridges,
  }) async {
    await harness.pump(
      tester,
      location: AppRoutes.teams,
      connection: connection,
      size: const Size(360, 1200),
      overrides: [?bridges?.override],
    );
    await harness.push(tester, AppRoutes.team(5));
  }

  Finder memberRow(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ListTile));

  Finder menuItem(String text) => find.ancestor(
    of: find.text(text).last,
    matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  );

  Finder dialogText(String text) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(text));

  Finder dialogTextContaining(String text) => find.descendant(
    of: find.byType(Dialog),
    matching: find.textContaining(text),
  );

  Future<void> openMemberMenu(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip(en.teamMemberOptionsFor(name)));
    await tester.pumpAndSettle();
  }

  group('as its admin', () {
    setUp(() => harness.teams.teams = [design()]);

    testWidgets('shows the team, its description and its members by name, '
        'the user marked', (tester) async {
      await openTeam(tester);

      expect(find.byType(TeamPage), findsOneWidget);
      expect(find.text('Design'), findsWidgets);
      expect(find.textContaining('We draw'), findsOneWidget);
      expect(find.text(en.teamMemberCount(2)), findsOneWidget);
      expect(find.text(en.teamMemberYou('Alice Example')), findsOneWidget);
      expect(
        find.descendant(
          of: memberRow(en.teamMemberYou('Alice Example')),
          matching: find.text(en.teamRoleAdmin),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: memberRow('Kim Lee'),
          matching: find.text(en.teamRoleMember),
        ),
        findsOneWidget,
      );
      // Never a menu on the user's own row.
      expect(
        find.byTooltip(en.teamMemberOptionsFor('Alice Example')),
        findsNothing,
      );
      expect(find.byTooltip(en.teamMemberOptionsFor('Kim Lee')), findsOne);
      expect(find.text(en.teamAddMember), findsOneWidget);
      expect(find.byTooltip(en.teamEdit), findsOneWidget);
      expect(find.text(en.teamDelete), findsOneWidget);
    });

    testWidgets('lists the members by name, an umlaut among its base letter '
        'and whatever the case', (tester) async {
      harness.teams.teams = [
        design(
          members: const [
            TeamMember(user: alice, admin: true),
            TeamMember(
              user: User(id: 21, username: 'z', name: 'Zahlung'),
            ),
            TeamMember(
              user: User(id: 22, username: 'ae', name: 'Ärger'),
            ),
            TeamMember(user: User(id: 23, username: 'apfel')),
          ],
        ),
      ];
      await openTeam(tester);

      final tops = [
        for (final name in const ['apfel', 'Ärger', 'Zahlung'])
          tester.getTopLeft(find.text(name)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
    });

    testWidgets('makes a member admin and back', (tester) async {
      await openTeam(tester);

      await openMemberMenu(tester, 'Kim Lee');
      await tester.tap(menuItem(en.teamMakeAdmin));
      await tester.pumpAndSettle();

      expect(harness.teams.calls, contains('toggleAdmin 5 kim'));
      expect(find.text(en.teamMadeAdmin('Kim Lee')), findsOneWidget);
      expect(
        find.descendant(
          of: memberRow('Kim Lee'),
          matching: find.text(en.teamRoleAdmin),
        ),
        findsOneWidget,
      );

      await openMemberMenu(tester, 'Kim Lee');
      await tester.tap(menuItem(en.teamMakeMember));
      await tester.pumpAndSettle();
      expect(find.text(en.teamMadeMember('Kim Lee')), findsOneWidget);
    });

    testWidgets('removes a member after a question that lists what the '
        'server deletes along', (tester) async {
      await openTeam(tester);

      await openMemberMenu(tester, 'Kim Lee');
      await tester.tap(menuItem(en.teamRemoveMember));
      await tester.pumpAndSettle();

      expect(dialogText(en.teamRemoveTitle('Kim Lee')), findsOneWidget);
      expect(dialogTextContaining(en.shareCleanupOthersIntro), findsOneWidget);
      expect(
        dialogTextContaining(en.shareCleanupOthersWebhooks),
        findsOneWidget,
      );
      await tester.tap(dialogText(en.teamRemoveConfirm));
      await tester.pumpAndSettle();

      expect(harness.teams.calls, contains('removeMember 5 kim'));
      expect(find.text(en.teamMemberRemoved('Kim Lee')), findsOneWidget);
      expect(memberRow('Kim Lee'), findsNothing);
    });

    testWidgets('on a server before 2.7 the question names only the loss of '
        'access', (tester) async {
      await openTeam(tester, connection: oauthServer230());

      await openMemberMenu(tester, 'Kim Lee');
      await tester.tap(menuItem(en.teamRemoveMember));
      await tester.pumpAndSettle();

      expect(dialogText(en.teamRemoveBody('Kim Lee')), findsOneWidget);
      expect(
        dialogTextContaining(en.shareCleanupOthersAssignments),
        findsNothing,
      );
    });

    testWidgets('adds a member found by username, leaving out the members', (
      tester,
    ) async {
      await openTeam(tester);

      await tester.tap(find.text(en.teamAddMember));
      await tester.pumpAndSettle();
      expect(find.byType(PersonSearchSheet), findsOneWidget);
      expect(find.text(en.sharePeopleSearchHint), findsOneWidget);
      final field = find.widgetWithText(TextField, en.sharePeopleSearchField);

      await tester.enterText(field, 'kim');
      await tester.pump(PersonSearchSheet.debounce);
      await tester.pumpAndSettle();
      expect(find.text(en.sharePeopleNoResults), findsOneWidget);

      await tester.enterText(field, 'ben');
      await tester.pump(PersonSearchSheet.debounce);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben Ortiz'));
      await tester.pumpAndSettle();

      expect(harness.users.globalSearches, ['kim', 'ben']);
      expect(harness.teams.calls, contains('addMember 5 ben'));
      expect(find.text(en.teamMemberAdded('Ben Ortiz')), findsOneWidget);
      expect(memberRow('Ben Ortiz'), findsOneWidget);
    });

    testWidgets('the search asks the server once the typing paused, and the '
        'latest query wins', (tester) async {
      final answers = <String, Completer<void>>{};
      harness.users.beforeAnswer = (query) =>
          (answers[query] = Completer()).future;
      await openTeam(tester);
      await tester.tap(find.text(en.teamAddMember));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, en.sharePeopleSearchField);

      await tester.enterText(field, 'b');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'ben');
      await tester.pump(PersonSearchSheet.debounce);
      expect(harness.users.globalSearches, ['ben']);

      await tester.enterText(field, 'kim lee');
      await tester.pump(PersonSearchSheet.debounce);
      answers['kim lee']!.complete();
      await tester.pump();
      answers['ben']!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Ben Ortiz'), findsNothing);
      expect(find.text(en.sharePeopleNoResults), findsOneWidget);
    });

    testWidgets('someone already in the team is said so', (tester) async {
      harness.teams.failures['addMember'] = const DomainError(409, code: 6005);
      await openTeam(tester);
      await tester.tap(find.text(en.teamAddMember));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, en.sharePeopleSearchField),
        'ben',
      );
      await tester.pump(PersonSearchSheet.debounce);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben Ortiz'));
      await tester.pumpAndSettle();

      expect(find.text(en.teamAlreadyMember), findsOneWidget);
    });

    testWidgets('edits the name in a sheet and shows the team as stored', (
      tester,
    ) async {
      await openTeam(tester);

      await tester.tap(find.byTooltip(en.teamEdit));
      await tester.pumpAndSettle();
      expect(find.byType(TeamEditSheet), findsOneWidget);
      expect(find.text(en.teamPublicLabel), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, en.teamNameLabel),
        'Design team',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, en.teamSave));
      await tester.pumpAndSettle();

      expect(
        harness.teams.calls,
        contains('update 5 ${const TeamChanges(name: 'Design team')}'),
      );
      expect(find.byType(TeamEditSheet), findsNothing);
      expect(find.text(en.teamSaved), findsOneWidget);
      expect(find.text('Design team'), findsWidgets);
    });

    testWidgets('the description opens the editor with the team and is '
        'saved online; an emptied one is written as the empty paragraph', (
      tester,
    ) async {
      final bridges = FakeEditorBridges();
      await openTeam(tester, bridges: bridges);

      await tester.tap(find.text(en.teamEditDescription));
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(currentLocation(tester), AppRoutes.teamDescription(5));
      expect(bridges.last.init!.html, '<p>We draw <strong>things</strong></p>');

      bridges.last.edit('<p></p>');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, en.taskEditSave));
      await tester.pumpAndSettle();

      expect(
        harness.teams.calls,
        contains('update 5 ${const TeamChanges(description: '<p></p>')}'),
      );
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(find.text(en.descriptionEditorSaved), findsOneWidget);
      expect(find.textContaining('We draw'), findsNothing);
      expect(find.text(en.teamAddDescription), findsOneWidget);
    });

    testWidgets("the editor survives losing the push's team", (tester) async {
      final bridges = FakeEditorBridges();
      await openTeam(tester, bridges: bridges);
      final router = containerOf(tester).read(appRouterProvider);
      unawaited(
        router.push(
          AppRoutes.teamDescription(5),
          extra: const TeamDescriptionTarget(
            teamId: 5,
            description: '<p>A</p>',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bridges.last.init!.html, '<p>A</p>');

      // Without the target the location goes back to the team's page.
      router.go(AppRoutes.teamDescription(6));
      await tester.pumpAndSettle();
      expect(currentLocation(tester), AppRoutes.team(6));
    });

    testWidgets('deletes the team after a question that lists what the '
        'server deletes along, and closes', (tester) async {
      await openTeam(tester);

      await tester.tap(find.text(en.teamDelete));
      await tester.pumpAndSettle();
      expect(dialogText(en.teamDeleteTitle('Design')), findsOneWidget);
      expect(dialogTextContaining(en.shareCleanupOthersIntro), findsOneWidget);
      await tester.tap(dialogText(en.teamDelete));
      await tester.pumpAndSettle();

      expect(harness.teams.calls, contains('delete 5'));
      expect(find.byType(TeamPage), findsNothing);
      expect(find.byType(TeamsPage), findsOneWidget);
      expect(find.text(en.teamDeleted), findsOneWidget);
    });

    testWidgets('as the only admin, leaving asks to make someone else admin '
        'first', (tester) async {
      await openTeam(tester);

      await tester.tap(find.text(en.teamLeave));
      await tester.pumpAndSettle();

      expect(dialogText(en.teamOnlyAdminTitle), findsOneWidget);
      await tester.tap(dialogText(en.teamOk));
      await tester.pumpAndSettle();
      expect(harness.teams.calls, isNot(contains('leave 5')));
      expect(find.byType(TeamPage), findsOneWidget);
    });

    testWidgets('as the last member, leaving offers to delete the team', (
      tester,
    ) async {
      harness.teams.teams = [
        design(members: const [TeamMember(user: alice, admin: true)]),
      ];
      await openTeam(tester);

      await tester.tap(find.text(en.teamLeave));
      await tester.pumpAndSettle();
      expect(dialogText(en.teamLastMemberTitle), findsOneWidget);
      await tester.tap(dialogText(en.teamDelete));
      await tester.pumpAndSettle();
      expect(dialogText(en.teamDeleteTitle('Design')), findsOneWidget);
      await tester.tap(dialogText(en.teamDelete));
      await tester.pumpAndSettle();

      expect(harness.teams.calls, contains('delete 5'));
      expect(find.byType(TeamPage), findsNothing);
    });

    testWidgets('a toggle for someone no longer in the team says so', (
      tester,
    ) async {
      harness.teams.failures['toggleAdmin'] = const TeamMemberMissing();
      await openTeam(tester);

      await openMemberMenu(tester, 'Kim Lee');
      await tester.tap(menuItem(en.teamMakeAdmin));
      await tester.pumpAndSettle();

      expect(find.text(en.teamNotMember), findsOneWidget);
    });
  });

  group('as a member', () {
    setUp(
      () => harness.teams.teams = [
        design(
          members: const [
            TeamMember(user: alice),
            TeamMember(user: kim, admin: true),
          ],
        ),
      ],
    );

    testWidgets('changes nothing but can leave', (tester) async {
      await openTeam(tester);

      expect(find.byTooltip(en.teamMemberOptionsFor('Kim Lee')), findsNothing);
      expect(find.text(en.teamAddMember), findsNothing);
      expect(find.byTooltip(en.teamEdit), findsNothing);
      expect(find.text(en.teamEditDescription), findsNothing);
      expect(find.text(en.teamDelete), findsNothing);
      expect(find.text(en.teamLeave), findsOneWidget);
    });

    testWidgets('leaving asks first, listing what the server deletes along, '
        'then closes the page, which reads the teams again, and syncs', (
      tester,
    ) async {
      await harness.pump(tester, location: AppRoutes.teams);
      await tester.tap(find.text('Design'));
      await tester.pumpAndSettle();
      final syncs = harness.data.engine.refreshAfterWriteCalls;

      await tester.tap(find.text(en.teamLeave));
      await tester.pumpAndSettle();
      expect(dialogText(en.teamLeaveTitle('Design')), findsOneWidget);
      expect(dialogTextContaining(en.shareCleanupSelfIntro), findsOneWidget);
      expect(
        dialogTextContaining(en.shareCleanupSelfAssignments),
        findsOneWidget,
      );
      await tester.tap(dialogText(en.teamLeaveConfirm));
      await tester.pumpAndSettle();

      expect(harness.teams.calls, contains('leave 5'));
      expect(find.byType(TeamPage), findsNothing);
      expect(find.byType(TeamsPage), findsOneWidget);
      expect(find.text(en.teamLeft), findsOneWidget);
      expect(harness.data.engine.refreshAfterWriteCalls, greaterThan(syncs));
      expect(find.text('Design'), findsNothing);
    });

    testWidgets('a cancelled leave changes nothing', (tester) async {
      await openTeam(tester);

      await tester.tap(find.text(en.teamLeave));
      await tester.pumpAndSettle();
      await tester.tap(dialogText(en.cancel));
      await tester.pumpAndSettle();

      expect(harness.teams.calls, isNot(contains('leave 5')));
      expect(find.byType(TeamPage), findsOneWidget);
    });
  });

  testWidgets('an external team is managed by its provider: no leaving, no '
      'editing, a note', (tester) async {
    harness.teams.teams = [
      design(name: 'Developers (Keycloak)', isExternal: true),
    ];
    await openTeam(tester);

    expect(
      find.widgetWithText(ListNote, en.teamExternalNote('Keycloak')),
      findsOneWidget,
    );
    expect(find.text(en.teamLeave), findsNothing);
    expect(find.text(en.teamAddMember), findsNothing);
    expect(find.byTooltip(en.teamEdit), findsNothing);
    expect(find.text(en.teamEditDescription), findsNothing);
    await openMemberMenu(tester, 'Kim Lee');
    expect(menuItem(en.teamMakeAdmin), findsOneWidget);
    expect(find.text(en.teamRemoveMember), findsNothing);
  });

  testWidgets('a team left or deleted elsewhere is not available once read '
      'again', (tester) async {
    harness.teams.teams = [design()];
    await openTeam(tester);

    harness.teams.teams = [];
    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(find.text(en.teamGoneTitle), findsOneWidget);
    expect(find.text('Kim Lee'), findsNothing);
  });

  testWidgets('a team the user is not in shows that it is not available', (
    tester,
  ) async {
    await openTeam(tester);

    expect(find.text(en.teamGoneTitle), findsOneWidget);
  });

  testWidgets('a read that gets through after a failed sync is online: the '
      'changes and the people search are on', (tester) async {
    harness.teams.teams = [design()];
    await harness.pump(
      tester,
      location: AppRoutes.teams,
      size: const Size(360, 1200),
    );
    harness.goOffline();
    await tester.pumpAndSettle();
    await harness.push(tester, AppRoutes.team(5));

    expect(find.byType(OfflineNotice), findsNothing);
    final leave = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, en.teamLeave),
    );
    expect(leave.onPressed, isNotNull);
    expect(
      tester.widget<ListTile>(memberRow(en.teamAddMember)).enabled,
      isTrue,
    );

    await tester.tap(find.text(en.teamAddMember));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, en.sharePeopleSearchField),
          )
          .enabled,
      isTrue,
    );
    expect(find.text(en.sharePeopleSearchOffline), findsNothing);
  });

  testWidgets('offline the changes are off and the read team stays', (
    tester,
  ) async {
    harness.teams.teams = [design()];
    await openTeam(tester);
    harness.goOffline();
    await tester.pumpAndSettle();

    expect(find.text('Kim Lee'), findsOneWidget);
    final leave = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, en.teamLeave),
    );
    expect(leave.onPressed, isNull);
    expect(
      tester.widget<ListTile>(memberRow(en.teamAddMember)).enabled,
      isFalse,
    );
  });
}
