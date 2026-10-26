import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_views_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_form_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
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
        views: defaultViews(1, firstViewId: 10),
      ),
      sampleProject(
        id: 2,
        title: 'Home',
        views: [sampleListView(id: 20, projectId: 2)],
      ),
    ];
  });

  Future<void> pumpViews(WidgetTester tester, int projectId) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    final router = containerOf(tester).read(appRouterProvider)
      ..go(AppRoutes.project(projectId));
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.projectViews(projectId)));
    await tester.pumpAndSettle();
  }

  List<String> rowTitles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(ProjectViewsPage),
        matching: find.byType(ListTile),
      ),
    ))
      (tile.title! as Text).data!,
  ];

  Future<void> openView(WidgetTester tester, String view) async {
    await tester.tap(find.widgetWithText(ListTile, view).first);
    await tester.pumpAndSettle();
  }

  Future<void> openOptions(WidgetTester tester, String view) async {
    await tester.tap(find.byTooltip(en.projectViewOptionsFor(view)));
    await tester.pumpAndSettle();
  }

  /// The item, not its label, which the menu keeps from taking taps.
  Future<void> chooseItem(WidgetTester tester, String label) async {
    await tester.tap(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder sheetField(String label) => find.descendant(
    of: find.byType(ViewFormSheet),
    matching: find.widgetWithText(TextField, label),
  );

  Future<void> submit(WidgetTester tester, String action) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ViewFormSheet),
        matching: find.widgetWithText(TextButton, action),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every view in order with its translated title and '
      'kind, none of them marked as shown on the web only', (tester) async {
    useLocale(tester, const Locale('de'));
    final de = lookupAppLocalizations(const Locale('de'));
    await pumpViews(tester, 1);

    expect(rowTitles(tester), [
      de.projectViewList,
      de.projectViewGantt,
      de.projectViewTable,
      de.projectViewKanban,
    ]);
    expect(find.text(de.projectViewsIntro('Work')), findsOneWidget);
    expect(find.textContaining('nur im Web'), findsNothing);
  });

  testWidgets('a new list view hides done tasks like the web unless told '
      'otherwise, and goes last', (tester) async {
    await pumpViews(tester, 1);

    await tester.tap(find.byTooltip(en.projectViewNew));
    await tester.pumpAndSettle();
    expect(find.byType(ViewFormSheet), findsOneWidget);
    await tester.enterText(sheetField(en.projectTitleLabel), ' Open work ');
    await tester.pump();
    await submit(tester, en.projectCreate);

    expect(data.views.calls, ['createView 1 Open work']);
    final draft = data.views.drafts.single;
    expect(draft.kind, ProjectViewKind.list);
    expect(draft.filter?.filter, 'done = false');
    expect(draft.bucketConfigurationMode, isNull);
    expect(find.byType(ViewFormSheet), findsNothing);
    expect(rowTitles(tester).last, 'Open work');
  });

  testWidgets('a new board with columns from filters says those are set up '
      'on the web', (tester) async {
    await pumpViews(tester, 1);

    await tester.tap(find.byTooltip(en.projectViewNew));
    await tester.pumpAndSettle();
    await tester.enterText(sheetField(en.projectTitleLabel), 'Triage');
    await tester.tap(find.text(en.projectViewKindLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.projectViewKanban).last);
    await tester.pumpAndSettle();
    expect(find.text(en.projectViewShowDone), findsNothing);
    // Not the list's default, which would hide the board's done column.
    expect(
      tester.widget<TextField>(sheetField(en.filterLabel)).controller!.text,
      '',
    );
    await tester.tap(find.text(en.projectViewColumnsLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.projectViewColumnsFilter).last);
    await tester.pumpAndSettle();
    expect(find.text(en.projectViewFilterColumnsOnWeb), findsOneWidget);
    await tester.enterText(sheetField(en.filterLabel), 'priority >= 3');
    await tester.pump();
    await submit(tester, en.projectCreate);

    final draft = data.views.drafts.single;
    expect(draft.kind, ProjectViewKind.kanban);
    expect(draft.bucketConfigurationMode, BucketConfigurationMode.filter);
    expect(draft.filter?.filter, 'priority >= 3');
  });

  testWidgets("editing a list view shows the web's default filter as the "
      'switch; showing done tasks drops it', (tester) async {
    await pumpViews(tester, 1);

    await openView(tester, en.projectViewList);
    expect(find.text(en.projectViewEditTitle), findsOneWidget);
    expect(
      tester
          .widget<TextField>(sheetField(en.projectTitleLabel))
          .controller!
          .text,
      'List',
    );
    expect(
      tester.widget<TextField>(sheetField(en.filterLabel)).controller!.text,
      '',
    );
    await tester.tap(find.text(en.projectViewShowDone));
    await tester.pumpAndSettle();
    await submit(tester, en.projectSave);

    expect(data.views.calls, ['updateView 1 10 List']);
    expect(data.views.drafts.single.filter, isNull);
  });

  testWidgets('a view whose filter was left alone keeps it as it was', (
    tester,
  ) async {
    await pumpViews(tester, 1);

    await openView(tester, en.projectViewList);
    await tester.enterText(sheetField(en.projectTitleLabel), 'Open');
    await tester.pump();
    await submit(tester, en.projectSave);

    final original = data.projects.find(1)!.views.first;
    expect(data.views.drafts.single.title, 'Open');
    expect(data.views.drafts.single.filter, same(original.filter));
  });

  testWidgets('a filter the server refuses is explained at its field, '
      'announced, and the sheet stays', (tester) async {
    const message = "The filter expression 'priority >= 3' is invalid";
    data.views.failures['updateView'] = const DomainError(
      400,
      code: 4024,
      message: message,
    );
    await pumpViews(tester, 1);

    await openView(tester, en.projectViewKanban);
    await tester.enterText(sheetField(en.filterLabel), 'priority >= 3');
    await tester.pump();
    await submit(tester, en.projectSave);

    expect(find.byType(ViewFormSheet), findsOneWidget);
    expect(find.text(en.projectViewFilterInvalid(message)), findsOneWidget);
    expect(data.views.drafts.single.filter?.filter, 'priority >= 3');
    expect(
      tester.takeAnnouncements(),
      contains(
        isAccessibilityAnnouncement(en.projectViewFilterInvalid(message)),
      ),
    );
  });

  testWidgets('dragged shut while saving, the view is still announced once '
      'made, and a refusal comes in a snackbar', (tester) async {
    var answer = Completer<void>();
    data.views.beforeCall = (_) => answer.future;
    await pumpViews(tester, 1);

    Future<void> createAndDragShut(String title) async {
      await tester.tap(find.byTooltip(en.projectViewNew));
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(en.projectTitleLabel), title);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(ViewFormSheet),
          matching: find.widgetWithText(TextButton, en.projectCreate),
        ),
      );
      await tester.pump();
      await tester.fling(
        find.text(en.projectViewNew).last,
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ViewFormSheet), findsNothing);
    }

    await createAndDragShut('Open work');
    tester.takeAnnouncements();
    answer.complete();
    await tester.pumpAndSettle();
    expect(rowTitles(tester).last, 'Open work');
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.projectViewCreated),
    ]);

    answer = Completer<void>();
    data.views.failures['createView'] = const Forbidden();
    await createAndDragShut('Triage');
    answer.complete();
    await tester.pumpAndSettle();
    expect(find.text(en.projectViewsAdminOnly), findsOneWidget);
  });

  testWidgets('Move up and Move down reorder the views where they can go', (
    tester,
  ) async {
    await pumpViews(tester, 1);

    await openOptions(tester, en.projectViewList);
    expect(find.text(en.moveUp), findsNothing);
    expect(find.text(en.moveDown), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await openOptions(tester, en.projectViewGantt);
    await chooseItem(tester, en.moveUp);

    expect(data.views.calls, ['moveView 1 11 to 0']);
    expect(rowTitles(tester).take(2), [
      en.projectViewGantt,
      en.projectViewList,
    ]);

    await openOptions(tester, en.projectViewKanban);
    expect(find.text(en.moveDown), findsNothing);
  });

  testWidgets('Delete asks first, then removes the view', (tester) async {
    await pumpViews(tester, 1);

    await openOptions(tester, en.projectViewTable);
    await chooseItem(tester, en.projectViewDelete);
    expect(
      find.text(en.projectViewDeleteTitle(en.projectViewTable)),
      findsOneWidget,
    );
    expect(find.text(en.projectViewDeleteBody), findsOneWidget);
    await tester.tap(find.text(en.projectViewDelete).last);
    await tester.pumpAndSettle();

    expect(data.views.calls, ['deleteView 1 12']);
    expect(rowTitles(tester), [
      en.projectViewList,
      en.projectViewGantt,
      en.projectViewKanban,
    ]);
  });

  testWidgets('the last view cannot be deleted, and the menu says why', (
    tester,
  ) async {
    await pumpViews(tester, 2);

    await openOptions(tester, en.projectViewList);

    final delete = tester.widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text(en.projectViewDelete),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    expect(delete.enabled, isFalse);
    expect(find.text(en.projectViewLastOne), findsOneWidget);
  });

  testWidgets('only admins may change views, which a refusal says', (
    tester,
  ) async {
    data.views.failures['moveView'] = const Forbidden();
    await pumpViews(tester, 1);

    await openOptions(tester, en.projectViewList);
    await chooseItem(tester, en.moveDown);

    expect(find.text(en.projectViewsAdminOnly), findsOneWidget);
    expect(rowTitles(tester).first, en.projectViewList);
  });

  testWidgets('while a change is on its way the view shows progress and no '
      'other change starts', (tester) async {
    final answer = Completer<void>();
    data.views.beforeCall = (_) => answer.future;
    await pumpViews(tester, 1);

    await openOptions(tester, en.projectViewList);
    await tester.tap(
      find.ancestor(
        of: find.text(en.moveDown),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    answer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
