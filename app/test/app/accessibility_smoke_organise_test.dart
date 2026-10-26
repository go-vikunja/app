import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_form_page.dart';
import 'package:vikunja_mobile/features/labels/presentation/labels_page.dart';
import 'package:vikunja_mobile/features/sharing/presentation/person_search_sheet.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/teams_page.dart';

import '../features/teams/organise_harness.dart';
import '../helpers/label_user_fakes.dart';
import '../helpers/pump_app.dart';

// The labels and teams screens of step 28 at 200 % text in dark mode on a
// small phone, in English and German. Layout overflows are reported as test
// failures, so reaching the end of each scenario without an exception is
// the assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

  void useWorstCase(WidgetTester tester, Locale locale) {
    useAccessibilityExtremes(tester);
    useLocale(tester, locale);
  }

  Future<void> scrollToEnd(WidgetTester tester, Finder scrollView) async {
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: scrollView, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    for (var i = 0; i < 80 && position.extentAfter > 0; i++) {
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  /// From the top of [page]'s list down to [finder].
  Future<void> scrollTo(WidgetTester tester, Type page, Finder finder) async {
    final scrollable = find
        .descendant(of: find.byType(page), matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 150, scrollable: scrollable);
    await tester.pumpAndSettle();
  }

  Finder dialogAction(String label) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(label));

  Future<void> closeDialog(WidgetTester tester, String label) async {
    await tester.tap(dialogAction(label));
    await tester.pumpAndSettle();
  }

  const longKim = User(
    id: 9,
    username: 'kim',
    name: 'Kimberly Musterfrau-Beispielhausen',
  );

  List<Label> longLabels() => [
    for (var i = 1; i <= 8; i++)
      ownLabel(
        i,
        'An own label with a rather long title number $i',
        hexColor: i.isEven ? 'ff006e' : '',
        html: '<p>A description long enough to wrap onto a second line</p>',
      ),
    for (var i = 20; i <= 25; i++)
      othersLabel(i, 'A label of somebody else, also long, $i', by: longKim),
  ];

  Team longTeam({required bool admin}) => sampleTeam(
    id: 5,
    name: 'A team with a name that goes on and on (Keycloak)',
    description:
        '<p>What this team is about, in a sentence long enough to wrap.</p>',
    isPublic: true,
    members: [
      TeamMember(user: alice, admin: admin),
      TeamMember(user: longKim, admin: !admin),
      const TeamMember(user: ben),
    ],
  );

  for (final locale in locales) {
    testWidgets('labels page with both sections, the search, a row menu and '
        'the delete question at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final harness = OrganiseHarness()
        ..labels = FakeLabelRepository(labels: longLabels());
      await harness.pump(tester, location: AppRoutes.labels, size: smallPhone);

      expect(find.byType(LabelsPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView).last);
      expect(tester.takeException(), isNull);

      await scrollTo(
        tester,
        LabelsPage,
        find.byTooltip(
          l10n.labelsOptionsFor(
            'An own label with a rather long title number 1',
          ),
        ),
      );
      await tester.tap(
        find.byTooltip(
          l10n.labelsOptionsFor(
            'An own label with a rather long title number 1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.labelsDelete).last);
      await tester.pumpAndSettle();
      expect(dialogAction(l10n.labelsDeleteBody), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeDialog(tester, l10n.cancel);
    });

    testWidgets('labels page empty and offline at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final harness = OrganiseHarness();
      await harness.pump(tester, location: AppRoutes.labels, size: smallPhone);
      harness.goOffline();
      await tester.pumpAndSettle();

      await scrollToEnd(tester, find.byType(CustomScrollView).last);
      expect(tester.takeException(), isNull);
    });

    testWidgets('label form, new with a colour error and editing with a '
        'description, at 200 % in dark mode (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final harness = OrganiseHarness()
        ..labels = FakeLabelRepository(labels: longLabels());
      await harness.pump(
        tester,
        location: AppRoutes.labelNew,
        size: smallPhone,
      );

      await tester.enterText(
        find.widgetWithText(TextField, l10n.labelsCustomColour),
        '12',
      );
      await tester.enterText(
        find.widgetWithText(TextField, l10n.labelsTitleLabel),
        'x' * 220,
      );
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(LabelFormPage));
      expect(tester.takeException(), isNull);

      await harness.push(tester, AppRoutes.labelEdit(1));
      await scrollToEnd(tester, find.byType(LabelFormPage).last);
      expect(find.text(l10n.labelsEditDescription), findsOneWidget);
      expect(tester.takeException(), isNull);

      await harness.push(tester, AppRoutes.labelEdit(20));
      await scrollToEnd(tester, find.byType(LabelFormPage).last);
      expect(tester.takeException(), isNull);
    });

    testWidgets('teams page with every badge, and the new team sheet at 200 % '
        'in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final harness = OrganiseHarness();
      harness.teams.teams = [
        longTeam(admin: true),
        sampleTeam(
          id: 6,
          name: 'Synced from the sign-in, with a long name too',
          isExternal: true,
          members: const [TeamMember(user: alice)],
        ),
      ];
      await harness.pump(tester, location: AppRoutes.teams, size: smallPhone);

      expect(find.byType(TeamsPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView).last);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, l10n.teamNameLabel),
        'A new team',
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.teamPublicHelp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('teams page empty at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final harness = OrganiseHarness();
      await harness.pump(tester, location: AppRoutes.teams, size: smallPhone);

      await scrollToEnd(tester, find.byType(ListView).last);
      expect(tester.takeException(), isNull);
    });

    testWidgets('team page as admin with a member menu, the add member sheet, '
        'the edit sheet and every question at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final harness = OrganiseHarness();
      harness.teams.teams = [longTeam(admin: true)];
      harness.users.everyone = [alice, longKim, ben];
      await harness.pump(tester, location: AppRoutes.team(5), size: smallPhone);

      expect(find.byType(TeamPage), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView).last);
      expect(tester.takeException(), isNull);

      final menu = find.byTooltip(
        l10n.teamMemberOptionsFor(longKim.displayName),
      );
      await scrollTo(tester, TeamPage, menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.teamRemoveMember).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await closeDialog(tester, l10n.cancel);

      await scrollTo(tester, TeamPage, find.text(l10n.teamAddMember));
      await tester.tap(find.text(l10n.teamAddMember));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, l10n.sharePeopleSearchField),
        'ben',
      );
      await tester.pump(PersonSearchSheet.debounce);
      await tester.pumpAndSettle();
      expect(find.text('Ben Ortiz'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.teamEdit));
      await tester.pumpAndSettle();
      expect(find.text(l10n.teamPublicLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await scrollTo(tester, TeamPage, find.text(l10n.teamDelete));
      await tester.tap(find.text(l10n.teamDelete));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await closeDialog(tester, l10n.cancel);

      await scrollTo(tester, TeamPage, find.text(l10n.teamLeave));
      await tester.tap(find.text(l10n.teamLeave));
      await tester.pumpAndSettle();
      // The only admin is asked to make someone else admin first.
      expect(dialogAction(l10n.teamOnlyAdminBody), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeDialog(tester, l10n.teamOk);
    });

    testWidgets('team page as a member, its leave question, and an external '
        'team at 200 % in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final harness = OrganiseHarness();
      harness.teams.teams = [
        longTeam(admin: false),
        sampleTeam(
          id: 6,
          name: 'Developers of everything (Keycloak)',
          isExternal: true,
          members: const [
            TeamMember(user: alice),
            TeamMember(user: ben),
          ],
        ),
      ];
      await harness.pump(tester, location: AppRoutes.team(5), size: smallPhone);

      await scrollToEnd(tester, find.byType(ListView).last);
      await tester.tap(find.text(l10n.teamLeave));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await closeDialog(tester, l10n.cancel);

      await harness.push(tester, AppRoutes.team(6));
      await scrollToEnd(tester, find.byType(ListView).last);
      expect(tester.takeException(), isNull);
    });
  }
}
