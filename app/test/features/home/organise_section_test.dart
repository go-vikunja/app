import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/labels/presentation/labels_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/teams_page.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../teams/organise_harness.dart';

void main() {
  late OrganiseHarness harness;

  setUp(() {
    harness = OrganiseHarness()
      ..labels = FakeLabelRepository(
        labels: [ownLabel(1, 'Urgent'), othersLabel(2, 'Shared')],
      );
  });

  Future<void> openAccountTab(WidgetTester tester) async {
    await harness.pump(tester, size: const Size(360, 1400));
    await openTab(tester, en.tabAccount);
  }

  Finder tile(String title) => find.widgetWithText(ListTile, title);

  testWidgets('organises labels, with how many there are, and teams between '
      'the account settings and the accounts', (tester) async {
    await openAccountTab(tester);

    final heading = find.widgetWithText(
      ListSectionHeader,
      en.accountOrganiseHeading,
    );
    expect(heading, findsOneWidget);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(top(tile(en.accountSettingsEntry)), lessThan(top(heading)));
    expect(top(heading), lessThan(top(tile(en.accountLabelsEntry))));
    expect(
      top(tile(en.accountTeamsEntry)),
      lessThan(top(find.widgetWithText(ListSectionHeader, en.accountsHeading))),
    );
    expect(
      find.descendant(
        of: tile(en.accountLabelsEntry),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(en.labelsCount(2))), findsOneWidget);
  });

  testWidgets('labels open the labels page', (tester) async {
    await openAccountTab(tester);

    await tester.tap(tile(en.accountLabelsEntry));
    await tester.pumpAndSettle();

    expect(find.byType(LabelsPage), findsOneWidget);
    expect(currentLocation(tester), AppRoutes.labels);
  });

  testWidgets('teams open the teams page', (tester) async {
    await openAccountTab(tester);

    await tester.tap(tile(en.accountTeamsEntry));
    await tester.pumpAndSettle();

    expect(find.byType(TeamsPage), findsOneWidget);
    expect(currentLocation(tester), AppRoutes.teams);
  });
}
