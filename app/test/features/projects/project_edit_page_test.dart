import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_edit_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';

import '../../helpers/announcer_region.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work',
        identifier: 'WORK',
        hexColor: '1973ff',
        position: 1,
      ),
      sampleProject(id: 3, title: 'Reports', parent: 1),
      sampleProject(id: 4, title: 'Q1', parent: 3),
      sampleProject(id: 2, title: 'Home', position: 2),
      sampleProject(id: 5, title: 'Old', archived: true),
      sampleProject(id: 6, title: 'Inbox', position: 3),
    ];
  });

  /// Opens the page over the project's screen, as its menu does.
  Future<void> pumpEdit(
    WidgetTester tester,
    int projectId, {
    ServerConnection? connection,
  }) async {
    await pumpSignedInApp(tester, sync: data, now: now, connection: connection);
    final router = containerOf(tester).read(appRouterProvider)
      ..go(AppRoutes.project(projectId));
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.projectEdit(projectId)));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  TextEditingController controllerOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!;

  TextButton saveButton(WidgetTester tester, AppLocalizations l10n) => tester
      .widget<TextButton>(find.widgetWithText(TextButton, l10n.projectSave));

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(en.projectSave));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the stored title, identifier and colour, and saves '
      'nothing until something changes', (tester) async {
    useLocale(tester, const Locale('de'));
    final de = lookupAppLocalizations(const Locale('de'));
    await pumpEdit(tester, 6);

    expect(find.byType(ProjectEditPage), findsOneWidget);
    // The server's title, not its German display name.
    expect(controllerOf(tester, de.projectTitleLabel).text, 'Inbox');
    expect(saveButton(tester, de).onPressed, isNull);
    expect(find.text(de.projectParentTopLevel), findsOneWidget);
  });

  testWidgets('Save sends only what changed, then closes and says so', (
    tester,
  ) async {
    await pumpEdit(tester, 1);
    expect(controllerOf(tester, en.projectIdentifierLabel).text, 'WORK');

    await tester.enterText(field(en.projectTitleLabel), ' Work stuff ');
    await tester.enterText(field(en.projectIdentifierLabel), 'ws');
    await tester.pump();
    expect(controllerOf(tester, en.projectIdentifierLabel).text, 'WS');
    await save(tester);

    expect(data.projects.updates, [
      (1, const ProjectChanges(title: 'Work stuff', identifier: 'WS')),
    ]);
    expect(find.byType(ProjectEditPage), findsNothing);
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Work stuff'), findsOneWidget);
    expect(find.text(en.projectEditSaved), findsOneWidget);
  });

  testWidgets('the identifier takes at most 10 characters, upper-case, and '
      'can be cleared', (tester) async {
    await pumpEdit(tester, 1);

    await tester.enterText(field(en.projectIdentifierLabel), 'abcdefghijkl');
    await tester.pump();
    expect(controllerOf(tester, en.projectIdentifierLabel).text, 'ABCDEFGHIJ');

    await tester.enterText(field(en.projectIdentifierLabel), '');
    await tester.pump();
    // Seven characters on screen, but twelve code points for the server.
    await tester.enterText(field(en.projectIdentifierLabel), 'ab${'👍🏽' * 5}');
    await tester.pump();
    expect(
      controllerOf(tester, en.projectIdentifierLabel).text,
      'AB${'👍🏽' * 4}',
    );

    await tester.enterText(field(en.projectIdentifierLabel), '');
    await tester.pump();
    await save(tester);
    expect(data.projects.updates, [(1, const ProjectChanges(identifier: ''))]);
  });

  testWidgets('a stored title over the limit, as a duplicate can have, is '
      'explained at its field and blocks saving until shortened', (
    tester,
  ) async {
    final long = '${'a' * 245} - duplicate';
    data.projects.all = [
      ...data.projects.all,
      sampleProject(id: 9, title: long, position: 9),
    ];
    await pumpEdit(tester, 9);

    expect(find.text(en.projectTitleTooLong), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel(en.taskEditColourSemantics('#0072b2')),
    );
    await tester.pump();
    expect(saveButton(tester, en).onPressed, isNull);

    await tester.enterText(field(en.projectTitleLabel), 'a' * 250);
    await tester.pump();
    expect(find.text(en.projectTitleTooLong), findsNothing);
    await save(tester);
    expect(data.projects.updates.single.$1, 9);
    expect(data.projects.updates.single.$2.title, 'a' * 250);
  });

  testWidgets('an identifier in use is explained at its field and the page '
      'stays', (tester) async {
    data.projects.failures['updateProject'] = const DomainError(
      400,
      code: 3007,
    );
    await pumpEdit(tester, 1);

    await tester.enterText(field(en.projectIdentifierLabel), 'HOME');
    await tester.pump();
    await save(tester);

    expect(find.byType(ProjectEditPage), findsOneWidget);
    expect(find.text(en.projectIdentifierTaken), findsOneWidget);
    expect(saveButton(tester, en).onPressed, isNotNull);

    await tester.enterText(field(en.projectIdentifierLabel), 'HOME2');
    await tester.pumpAndSettle();
    expect(find.text(en.projectIdentifierTaken), findsNothing);
  });

  testWidgets('an identifier in use is announced where the platform '
      'announces', (tester) async {
    data.projects.failures['updateProject'] = const DomainError(
      400,
      code: 3007,
    );
    await pumpEdit(tester, 1);
    await tester.enterText(field(en.projectIdentifierLabel), 'HOME');
    await tester.pump();
    await save(tester);

    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.projectIdentifierTaken),
    ]);
  });

  testWidgets('without platform announcements, as on Android, the '
      "identifier error is said by the field's live region alone", (
    tester,
  ) async {
    useLiveRegionAnnouncements(tester);
    data.projects.failures['updateProject'] = const DomainError(
      400,
      code: 3007,
    );
    await pumpEdit(tester, 1);
    await tester.enterText(field(en.projectIdentifierLabel), 'HOME');
    await tester.pump();
    await save(tester);

    expect(tester.takeAnnouncements(), isEmpty);
    expect(announcerRegion(tester)?.label, '');
    final error = tester
        .getSemantics(find.text(en.projectIdentifierTaken))
        .getSemanticsData();
    expect(error.flagsCollection.isLiveRegion, isTrue);
    expect(error.label, contains(en.projectIdentifierTaken));
  });

  testWidgets('on a server with the bin an identifier in use also says that '
      'a project in the bin keeps its identifier, at the field and aloud', (
    tester,
  ) async {
    data.projects.failures['updateProject'] = const DomainError(
      400,
      code: 3007,
    );
    await pumpEdit(tester, 1, connection: fullServer280());
    await tester.enterText(field(en.projectIdentifierLabel), 'HOME');
    await tester.pump();
    await save(tester);

    expect(find.byType(ProjectEditPage), findsOneWidget);
    expect(find.text(en.projectIdentifierTakenTrash), findsOneWidget);
    expect(find.text(en.projectIdentifierTaken), findsNothing);
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.projectIdentifierTakenTrash),
    ]);

    await tester.enterText(field(en.projectIdentifierLabel), 'HOME2');
    await tester.pumpAndSettle();
    expect(find.text(en.projectIdentifierTakenTrash), findsNothing);
  });

  testWidgets('the parent picker leaves out the project, its subprojects and '
      'archived projects', (tester) async {
    await pumpEdit(tester, 1);

    await tester.tap(find.text(en.projectParentLabel));
    await tester.pumpAndSettle();
    final picker = find.ancestor(
      of: find.text(en.projectParentTopLevel).last,
      matching: find.byType(ListView),
    );
    List<String> titles() => [
      for (final tile in tester.widgetList<ListTile>(
        find.descendant(of: picker, matching: find.byType(ListTile)),
      ))
        (tile.title! as Text).data!,
    ];
    expect(titles(), [en.projectParentTopLevel, 'Home', 'Inbox']);

    await tester.tap(find.descendant(of: picker, matching: find.text('Home')));
    await tester.pumpAndSettle();
    await save(tester);

    expect(data.projects.updates, [
      (1, const ProjectChanges(parentProjectId: 2)),
    ]);
  });

  testWidgets('a colour from outside the palette stays chosen and can be '
      'cleared', (tester) async {
    await pumpEdit(tester, 1);

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(en.taskEditColourSemantics('#1973ff')),
      ),
      isSemantics(isSelected: true),
    );
    await tester.tap(find.bySemanticsLabel(en.taskEditNoColour));
    await tester.pump();
    await save(tester);

    expect(data.projects.updates, [(1, const ProjectChanges(hexColor: ''))]);
  });

  testWidgets('a colour from outside the palette can be chosen again after '
      'trying another', (tester) async {
    await pumpEdit(tester, 1);

    await tester.tap(
      find.bySemanticsLabel(en.taskEditColourSemantics('#e69f00')),
    );
    await tester.pump();
    expect(saveButton(tester, en).onPressed, isNotNull);
    await tester.tap(
      find.bySemanticsLabel(en.taskEditColourSemantics('#1973ff')),
    );
    await tester.pump();

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(en.taskEditColourSemantics('#1973ff')),
      ),
      isSemantics(isSelected: true),
    );
    expect(saveButton(tester, en).onPressed, isNull);
  });

  testWidgets('a title of only spaces cannot be saved', (tester) async {
    await pumpEdit(tester, 1);

    await tester.enterText(field(en.projectTitleLabel), '  ');
    await tester.pump();

    expect(find.text(en.projectTitleRequired), findsOneWidget);
    expect(saveButton(tester, en).onPressed, isNull);
  });

  testWidgets('a refusal stays on the page and says why', (tester) async {
    data.projects.failure = const Forbidden();
    await pumpEdit(tester, 1);

    await tester.enterText(field(en.projectTitleLabel), 'Work stuff');
    await tester.pump();
    await save(tester);
    expect(find.byType(ProjectEditPage), findsOneWidget);
    expect(find.text(en.projectChangeForbidden), findsOneWidget);

    await tester.tap(find.text(en.projectParentLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await save(tester);
    expect(find.text(en.projectMoveAdminOnly), findsOneWidget);
  });

  testWidgets('leaving with changes asks first', (tester) async {
    await pumpEdit(tester, 1);
    await tester.enterText(field(en.projectTitleLabel), 'Work stuff');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(en.projectEditDiscardBody), findsOneWidget);
    await tester.tap(find.text(en.taskEditKeepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectEditPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskEditDiscard));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectEditPage), findsNothing);
    expect(data.projects.calls, isEmpty);
  });

  testWidgets('a project that is gone says so', (tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester).read(appRouterProvider).go(AppRoutes.projectEdit(99));
    await tester.pumpAndSettle();

    expect(find.text(en.projectGoneTitle), findsOneWidget);
  });
}
