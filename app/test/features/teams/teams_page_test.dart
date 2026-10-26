import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/teams/presentation/new_team_sheet.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_badges.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/teams_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import 'organise_harness.dart';

void main() {
  late OrganiseHarness harness;

  setUp(() => harness = OrganiseHarness());

  Finder rowOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ListTile));

  Finder badgeIn(String team, String badge) => find.descendant(
    of: rowOf(team),
    matching: find.widgetWithText(TeamBadge, badge),
  );

  group('the list', () {
    setUp(
      () => harness.teams.teams = [
        sampleTeam(
          id: 1,
          name: 'Design',
          isPublic: true,
          members: const [
            TeamMember(user: alice, admin: true),
            TeamMember(user: kim),
          ],
        ),
        sampleTeam(
          id: 2,
          name: 'Developers (Keycloak)',
          isExternal: true,
          members: const [TeamMember(user: alice)],
        ),
        sampleTeam(
          id: 3,
          name: 'Ops',
          isExternal: true,
          isPublic: true,
          members: const [
            TeamMember(user: alice),
            TeamMember(user: kim, admin: true),
            TeamMember(user: ben),
          ],
        ),
      ],
    );

    testWidgets('shows each team with its members and what sets it apart', (
      tester,
    ) async {
      await harness.pump(tester, location: AppRoutes.teams);

      expect(find.byType(TeamsPage), findsOneWidget);
      expect(harness.teams.calls, ['list']);
      expect(
        find.descendant(
          of: rowOf('Design'),
          matching: find.text(en.teamMemberCount(2)),
        ),
        findsOneWidget,
      );
      expect(badgeIn('Design', en.teamAdminBadge), findsOneWidget);
      expect(badgeIn('Design', en.teamPublicBadge), findsOneWidget);
      expect(
        badgeIn('Developers (Keycloak)', en.teamManagedBy('Keycloak')),
        findsOneWidget,
      );
      expect(badgeIn('Developers (Keycloak)', en.teamAdminBadge), findsNothing);
      expect(badgeIn('Ops', en.teamManagedExternally), findsOneWidget);
      // The initials leave the provider out.
      expect(find.text('D'), findsWidgets);
    });

    testWidgets('the list starts right below the app bar under a status bar', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 600);
      addTearDown(tester.view.resetPadding);
      await harness.pump(tester, location: AppRoutes.teams);

      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      final firstCard = tester.getTopLeft(find.byType(SectionCard).first).dy;
      expect(firstCard - appBarBottom, lessThan(40));
    });

    testWidgets('without public teams on the server no team is public', (
      tester,
    ) async {
      await harness.pump(
        tester,
        location: AppRoutes.teams,
        connection: v1OnlyServer270(),
      );

      expect(badgeIn('Design', en.teamPublicBadge), findsNothing);
      expect(badgeIn('Ops', en.teamPublicBadge), findsNothing);
    });

    testWidgets('a team opens its page, and the list is read again after', (
      tester,
    ) async {
      await harness.pump(tester, location: AppRoutes.teams);

      await tester.tap(find.text('Design'));
      await tester.pumpAndSettle();
      expect(find.byType(TeamPage), findsOneWidget);
      expect(currentLocation(tester), AppRoutes.team(1));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(harness.teams.calls, ['list', 'read 1', 'list']);
    });

    testWidgets('pulling down reads the teams again', (tester) async {
      await harness.pump(tester, location: AppRoutes.teams);

      await pullToRefresh(tester, find.byType(ListView).last);

      expect(harness.teams.calls, ['list', 'list']);
    });
  });

  testWidgets('without teams it says so and offers a new one', (tester) async {
    await harness.pump(tester, location: AppRoutes.teams);

    expect(find.text(en.teamsEmptyTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, en.teamsNew));
    await tester.pumpAndSettle();

    expect(find.byType(NewTeamSheet), findsOneWidget);
  });

  group('a new team', () {
    Finder nameField() => find.widgetWithText(TextField, en.teamNameLabel);
    Finder createButton() => find.widgetWithText(TextButton, en.teamCreate);

    testWidgets('is created with its name and whether it is public, then '
        'opens', (tester) async {
      harness.teams.nextTeamId = 12;
      await harness.pump(tester, location: AppRoutes.teams);

      await tester.tap(find.widgetWithText(FloatingActionButton, en.teamsNew));
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(createButton()).onPressed, isNull);
      expect(find.text(en.teamPublicHelp), findsOneWidget);

      await tester.enterText(nameField(), '  Garden club  ');
      await tester.tap(find.text(en.teamPublicLabel));
      await tester.pump();
      await tester.tap(createButton());
      await tester.pumpAndSettle();

      final created = harness.teams.teams.single;
      expect(created.name, 'Garden club');
      expect(created.isPublic, isTrue);
      expect(find.byType(NewTeamSheet), findsNothing);
      expect(find.byType(TeamPage), findsOneWidget);
      expect(currentLocation(tester), AppRoutes.team(12));
      expect(find.text(en.teamCreated), findsOneWidget);
    });

    testWidgets('without public teams on the server there is no switch', (
      tester,
    ) async {
      await harness.pump(
        tester,
        location: AppRoutes.teams,
        connection: v1OnlyServer270(),
      );

      await tester.tap(find.widgetWithText(FloatingActionButton, en.teamsNew));
      await tester.pumpAndSettle();

      expect(find.text(en.teamPublicLabel), findsNothing);
      await tester.enterText(nameField(), 'Garden club');
      await tester.pump();
      await tester.tap(createButton());
      await tester.pumpAndSettle();
      expect(harness.teams.teams.single.isPublic, isFalse);
    });

    testWidgets('a cleared name says it is needed', (tester) async {
      await harness.pump(tester, location: AppRoutes.teams);
      await tester.tap(find.widgetWithText(FloatingActionButton, en.teamsNew));
      await tester.pumpAndSettle();

      await tester.enterText(nameField(), 'x');
      await tester.enterText(nameField(), ' ');
      await tester.pump();

      expect(find.text(en.teamNameRequired), findsOneWidget);
      expect(tester.widget<TextButton>(createButton()).onPressed, isNull);
    });

    testWidgets('a refusal stays in the sheet and says why', (tester) async {
      harness.teams.failures['create'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await harness.pump(tester, location: AppRoutes.teams);
      await tester.tap(find.widgetWithText(FloatingActionButton, en.teamsNew));
      await tester.pumpAndSettle();

      await tester.enterText(nameField(), 'Garden club');
      await tester.pump();
      await tester.tap(createButton());
      await tester.pumpAndSettle();

      expect(find.byType(NewTeamSheet), findsOneWidget);
      expect(find.text(en.teamsNewOffline), findsOneWidget);
    });
  });

  testWidgets('offline it says so, and the new team button is off with the '
      'reason', (tester) async {
    harness.teams.failure = const NetworkFailure(NetworkProblem.unreachable);
    await harness.pump(tester, location: AppRoutes.teams);
    harness.goOffline();
    await tester.pumpAndSettle();

    expect(find.byType(OfflineNotice), findsOneWidget);
    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.onPressed, isNull);
    expect(button.tooltip, en.teamsNewOffline);
  });

  testWidgets('a read that gets through after a failed sync shows the page '
      'online', (tester) async {
    harness.teams.failure = const NetworkFailure(NetworkProblem.unreachable);
    await harness.pump(tester, location: AppRoutes.teams);
    harness.goOffline();
    await tester.pumpAndSettle();
    expect(find.byType(OfflineNotice), findsOneWidget);

    harness.teams
      ..failure = null
      ..teams = [sampleTeam(id: 1, name: 'Design')];
    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(OfflineNotice), findsNothing);
    expect(find.text('Design'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a failed read offers to try again, and the teams show once it '
      'works', (tester) async {
    harness.teams.failure = const ServerFailure(502);
    await harness.pump(tester, location: AppRoutes.teams);

    expect(find.byType(DataFailureCard), findsOneWidget);
    harness.teams
      ..failure = null
      ..teams = [sampleTeam(id: 1, name: 'Design')];
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(find.text('Design'), findsOneWidget);
  });
}
