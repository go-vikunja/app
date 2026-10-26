import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_form_page.dart';
import 'package:vikunja_mobile/features/labels/presentation/labels_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../teams/organise_harness.dart';

void main() {
  late OrganiseHarness harness;

  setUp(() => harness = OrganiseHarness());

  Finder header(String title) => find.widgetWithText(ListSectionHeader, title);

  Finder menuItem(String text) => find.ancestor(
    of: find.text(text).last,
    matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  );

  Finder dialogText(String text) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(text));

  Future<void> openMenuItem(
    WidgetTester tester,
    String label,
    String item,
  ) async {
    await tester.tap(find.byTooltip(en.labelsOptionsFor(label)));
    await tester.pumpAndSettle();
    await tester.tap(menuItem(item));
    await tester.pumpAndSettle();
  }

  group('lists', () {
    late List<Label> stored;

    setUp(() {
      stored = [
        ownLabel(1, 'Urgent', html: '<p>Do these first</p><p>Then rest</p>'),
        othersLabel(2, 'Shared'),
        ownLabel(3, 'Admin', hexColor: 'ff006e'),
      ];
    });

    testWidgets('own labels and the others apart, the first line of a '
        "description and who made another's", (tester) async {
      harness.labels = FakeLabelRepository(labels: stored);
      await harness.pump(tester, location: AppRoutes.labels);

      expect(find.byType(LabelsPage), findsOneWidget);
      expect(header(en.labelsOwnSection), findsOneWidget);
      expect(header(en.labelsOthersSection), findsOneWidget);
      expect(find.text('Do these first'), findsOneWidget);
      expect(find.text('Then rest'), findsNothing);
      expect(find.text(en.labelsCreatedBy('Kim Lee')), findsOneWidget);
      // Own labels by title, then the others.
      final titles = [
        for (final title in ['Admin', 'Urgent', 'Shared'])
          tester.getTopLeft(find.text(title)).dy,
      ];
      expect(titles, orderedEquals([...titles]..sort()));
      expect(find.byTooltip(en.labelsOptionsFor('Urgent')), findsOneWidget);
      expect(find.byTooltip(en.labelsOptionsFor('Shared')), findsNothing);
      // Few labels need no search.
      expect(find.widgetWithText(TextField, en.labelsSearch), findsNothing);
    });

    testWidgets('without labels of others there is no such section', (
      tester,
    ) async {
      harness.labels = FakeLabelRepository(labels: [ownLabel(1, 'Urgent')]);
      await harness.pump(tester, location: AppRoutes.labels);

      expect(header(en.labelsOwnSection), findsOneWidget);
      expect(header(en.labelsOthersSection), findsNothing);
    });

    testWidgets('the list starts right below the app bar under a status bar', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 600);
      addTearDown(tester.view.resetPadding);
      harness.labels = FakeLabelRepository(labels: stored);
      await harness.pump(tester, location: AppRoutes.labels);

      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      final firstHeader = tester.getTopLeft(header(en.labelsOwnSection)).dy;
      expect(firstHeader - appBarBottom, lessThan(40));
    });

    testWidgets('a label opens its open tasks', (tester) async {
      harness.labels = FakeLabelRepository(labels: stored);
      await harness.pump(tester, location: AppRoutes.labels);

      await tester.tap(find.text('Shared'));
      await tester.pumpAndSettle();

      expect(find.byType(LabelTasksScreen), findsOneWidget);
      expect(currentLocation(tester), AppRoutes.labelTasks(2));
    });

    testWidgets('more than twelve labels can be searched here', (tester) async {
      harness.labels = FakeLabelRepository(
        labels: [
          for (var i = 1; i <= 13; i++) ownLabel(i, 'Label $i'),
          othersLabel(20, 'Zebra'),
        ],
      );
      await harness.pump(tester, location: AppRoutes.labels);

      final search = find.widgetWithText(TextField, en.labelsSearch);
      expect(search, findsOneWidget);
      await tester.enterText(search, 'zeb');
      await tester.pumpAndSettle();

      expect(find.text('Zebra'), findsOneWidget);
      expect(find.text('Label 1'), findsNothing);
      expect(header(en.labelsOwnSection), findsNothing);

      await tester.enterText(search, 'nothing like it');
      await tester.pumpAndSettle();
      expect(
        find.text(en.labelsSearchEmpty('nothing like it')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip(en.clearSearch));
      await tester.pumpAndSettle();
      expect(find.text('Label 1'), findsOneWidget);
    });

    testWidgets('pulling down syncs', (tester) async {
      harness.labels = FakeLabelRepository(labels: stored);
      await harness.pump(tester, location: AppRoutes.labels);
      final before = harness.data.engine.refreshCalls;

      await pullToRefresh(tester, find.byType(ListView).last);

      expect(harness.data.engine.refreshCalls, before + 1);
    });
  });

  group('deleting', () {
    setUp(
      () => harness.labels = FakeLabelRepository(
        labels: [ownLabel(1, 'Urgent'), ownLabel(3, 'Admin')],
      ),
    );

    testWidgets('asks first and says what it does, then deletes', (
      tester,
    ) async {
      await harness.pump(tester, location: AppRoutes.labels);

      await openMenuItem(tester, 'Urgent', en.labelsDelete);
      expect(dialogText(en.labelsDeleteTitle('Urgent')), findsOneWidget);
      expect(dialogText(en.labelsDeleteBody), findsOneWidget);
      await tester.tap(dialogText(en.cancel));
      await tester.pumpAndSettle();
      expect(harness.labels.deletes, isEmpty);

      await openMenuItem(tester, 'Urgent', en.labelsDelete);
      await tester.tap(dialogText(en.labelsDelete));
      await tester.pumpAndSettle();

      expect(harness.labels.deletes, [1]);
      expect(find.text(en.labelsDeleted), findsOneWidget);
      expect(find.text('Urgent'), findsNothing);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('a refusal keeps the label and says why', (tester) async {
      harness.labels.changeFailure = const Forbidden();
      await harness.pump(tester, location: AppRoutes.labels);

      await openMenuItem(tester, 'Urgent', en.labelsDelete);
      await tester.tap(dialogText(en.labelsDelete));
      await tester.pumpAndSettle();

      expect(find.text(en.labelsNotCreator), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
    });

    testWidgets('offline it says a connection is needed', (tester) async {
      harness.labels.changeFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await harness.pump(tester, location: AppRoutes.labels);

      await openMenuItem(tester, 'Urgent', en.labelsDelete);
      await tester.tap(dialogText(en.labelsDelete));
      await tester.pumpAndSettle();

      expect(find.text(en.labelsNeedsConnection), findsOneWidget);
    });

    testWidgets('while offline Delete is off with the reason, before any '
        'confirmation; Edit stays', (tester) async {
      await harness.pump(tester, location: AppRoutes.labels);
      harness.goOffline();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(en.labelsOptionsFor('Urgent')));
      await tester.pumpAndSettle();
      final delete = tester.widget<PopupMenuItem<Object?>>(
        menuItem(en.labelsDelete),
      );
      expect(delete.enabled, isFalse);
      expect(find.text(en.labelsNeedsConnection), findsOneWidget);
      expect(
        tester.widget<PopupMenuItem<Object?>>(menuItem(en.labelsEdit)).enabled,
        isTrue,
      );

      await tester.tap(menuItem(en.labelsDelete), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(dialogText(en.labelsDeleteTitle('Urgent')), findsNothing);
      expect(harness.labels.deletes, isEmpty);
    });
  });

  testWidgets('edit opens the form for that label', (tester) async {
    harness.labels = FakeLabelRepository(labels: [ownLabel(1, 'Urgent')]);
    await harness.pump(tester, location: AppRoutes.labels);

    await openMenuItem(tester, 'Urgent', en.labelsEdit);

    expect(find.byType(LabelFormPage), findsOneWidget);
    expect(currentLocation(tester), AppRoutes.labelEdit(1));
  });

  testWidgets('without labels it says so and offers a new one', (tester) async {
    await harness.pump(tester, location: AppRoutes.labels);

    expect(find.text(en.labelsEmptyTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, en.labelsNew));
    await tester.pumpAndSettle();

    expect(find.byType(LabelFormPage), findsOneWidget);
    expect(currentLocation(tester), AppRoutes.labelNew);
  });

  testWidgets('the new label button opens the form', (tester) async {
    harness.labels = FakeLabelRepository(labels: [ownLabel(1, 'Urgent')]);
    await harness.pump(tester, location: AppRoutes.labels);

    await tester.tap(find.widgetWithText(FloatingActionButton, en.labelsNew));
    await tester.pumpAndSettle();

    expect(find.byType(LabelFormPage), findsOneWidget);
  });

  testWidgets('offline the new label button is off with the reason and the '
      'saved labels show under a notice', (tester) async {
    harness.labels = FakeLabelRepository(labels: [ownLabel(1, 'Urgent')]);
    await harness.pump(tester, location: AppRoutes.labels);
    harness.goOffline();
    await tester.pumpAndSettle();

    expect(find.byType(OfflineNotice), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.onPressed, isNull);
    expect(button.tooltip, en.labelsNewOffline);
  });
}
