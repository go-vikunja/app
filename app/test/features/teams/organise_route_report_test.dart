import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_form_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_page.dart';

import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/route_report.dart';
import 'organise_harness.dart';

// go_router decodes the route list anew (flutter/flutter#128122); the
// pages that wait for one they pushed must still get its result.
void main() {
  late OrganiseHarness harness;
  late FakeEditorBridges bridges;

  setUp(() {
    harness = OrganiseHarness();
    bridges = FakeEditorBridges();
  });

  Future<void> saveEdit(WidgetTester tester, String html) async {
    bridges.last.edit(html);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, en.taskEditSave));
    await tester.pumpAndSettle();
  }

  testWidgets("a label's description saved after the app was opened again "
      'still says so on the form', (tester) async {
    harness.labels = FakeLabelRepository(
      labels: [ownLabel(1, 'Urgent', html: '<p>Old</p>')],
    );
    await harness.pump(
      tester,
      location: AppRoutes.labelEdit(1),
      overrides: [bridges.override],
    );
    await tester.tap(find.text(en.labelsEditDescription));
    await tester.pumpAndSettle();

    await reportRouteFromPlatform(tester);
    await saveEdit(tester, '<p>New</p>');

    expect(find.byType(DescriptionEditorPage), findsNothing);
    expect(find.byType(LabelFormPage), findsOneWidget);
    expect(find.text(en.descriptionEditorSaved), findsOneWidget);
  });

  testWidgets("a team's description editor keeps its team when the app is "
      'opened again, and the team page reads the saved one', (tester) async {
    harness.teams.teams = [
      sampleTeam(id: 5, name: 'Design', description: '<p>Old</p>'),
    ];
    await harness.pump(
      tester,
      location: AppRoutes.team(5),
      overrides: [bridges.override],
    );
    await tester.tap(find.text(en.teamEditDescription));
    await tester.pumpAndSettle();

    await reportRouteFromPlatform(tester);
    expect(find.byType(DescriptionEditorPage), findsOneWidget);
    expect(currentLocation(tester), AppRoutes.teamDescription(5));
    await saveEdit(tester, '<p>New</p>');

    expect(
      harness.teams.calls,
      contains('update 5 ${const TeamChanges(description: '<p>New</p>')}'),
    );
    expect(find.byType(TeamPage), findsOneWidget);
    expect(find.text(en.descriptionEditorSaved), findsOneWidget);
    expect(find.textContaining('New'), findsOneWidget);
  });

  // The helper's canary: when a plain push's future survives the report,
  // the helper no longer causes the re-decode (or go_router fixed it), and
  // the tests here prove nothing.
  testWidgets("the report drops a plain push's future", (tester) async {
    harness.teams.teams = [sampleTeam(id: 5, name: 'Design')];
    await harness.pump(tester, location: AppRoutes.teams);
    final router = containerOf(tester).read(appRouterProvider);

    Future<bool> popped({required bool reported}) async {
      var done = false;
      unawaited(router.push<void>(AppRoutes.team(5)).then((_) => done = true));
      await tester.pumpAndSettle();
      if (reported) await reportRouteFromPlatform(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      return done;
    }

    expect(await popped(reported: false), isTrue);
    expect(await popped(reported: true), isFalse);
  });

  testWidgets('the teams page reads the list again after a team page that '
      'was open while the app was opened again', (tester) async {
    harness.teams.teams = [sampleTeam(id: 5, name: 'Design')];
    await harness.pump(tester, location: AppRoutes.teams);
    await tester.tap(find.text('Design'));
    await tester.pumpAndSettle();

    await reportRouteFromPlatform(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(harness.teams.calls, ['list', 'read 5', 'list']);
  });
}
