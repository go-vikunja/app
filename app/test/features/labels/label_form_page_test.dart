import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_form_page.dart';
import 'package:vikunja_mobile/features/labels/presentation/labels_page.dart';
import 'package:vikunja_mobile/features/tasks/application/color_palette.dart';

import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../teams/organise_harness.dart';

void main() {
  late OrganiseHarness harness;

  setUp(() => harness = OrganiseHarness());

  Finder titleField() => find.widgetWithText(TextField, en.labelsTitleLabel);
  Finder hexField() => find.widgetWithText(TextField, en.labelsCustomColour);
  Finder action(String label) => find.widgetWithText(TextButton, label);

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<TextButton>(button).onPressed != null;

  /// The form over the labels page, so that it can close onto it.
  Future<void> openForm(WidgetTester tester, String location) async {
    await harness.pump(tester, location: AppRoutes.labels);
    await harness.push(tester, location);
  }

  group('a new label', () {
    testWidgets('starts with a colour of the palette and creates the label '
        'with the trimmed title', (tester) async {
      await openForm(tester, AppRoutes.labelNew);

      expect(find.text(en.labelsNew), findsOneWidget);
      expect(find.text(en.labelsDescriptionAfterCreate), findsOneWidget);
      final startColor = tester.widget<TextField>(hexField()).controller!.text;
      expect(okabeItoColors, contains(startColor));
      expect(enabled(tester, action(en.labelsCreate)), isFalse);

      await tester.enterText(titleField(), '  Errands  ');
      await tester.pump();
      await tester.tap(action(en.labelsCreate));
      await tester.pumpAndSettle();

      final created = harness.labels.created.single;
      expect(created.title, 'Errands');
      expect(created.hexColor, startColor);
      expect(find.byType(LabelFormPage), findsNothing);
      expect(find.byType(LabelsPage), findsOneWidget);
      expect(find.text(en.labelsCreated), findsOneWidget);
      expect(find.text('Errands'), findsOneWidget);
    });

    testWidgets('offers the seven colours of the Okabe–Ito palette', (
      tester,
    ) async {
      await openForm(tester, AppRoutes.labelNew);

      for (final hex in okabeItoColors) {
        expect(
          find.bySemanticsLabel(en.taskEditColourSemantics('#$hex')),
          findsOneWidget,
        );
      }
      expect(
        find.bySemanticsLabel(en.taskEditColourSemantics('#3a86ff')),
        findsNothing,
      );
    });

    testWidgets('a cleared title says it is needed and cannot be saved', (
      tester,
    ) async {
      await openForm(tester, AppRoutes.labelNew);

      await tester.enterText(titleField(), 'x');
      await tester.enterText(titleField(), '   ');
      await tester.pump();

      expect(find.text(en.labelsTitleRequired), findsOneWidget);
      expect(enabled(tester, action(en.labelsCreate)), isFalse);
    });

    testWidgets('a custom colour of three digits is sent as six, an invalid '
        'one blocks saving, and no colour sends none', (tester) async {
      await openForm(tester, AppRoutes.labelNew);
      await tester.enterText(titleField(), 'Errands');

      await tester.enterText(hexField(), '12');
      await tester.pump();
      expect(find.text(en.labelsCustomColourInvalid), findsOneWidget);
      expect(enabled(tester, action(en.labelsCreate)), isFalse);

      await tester.enterText(hexField(), '#AbC');
      await tester.pump();
      expect(find.text(en.labelsCustomColourInvalid), findsNothing);
      // The typed colour is offered as a swatch and chosen.
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(en.taskEditColourSemantics('#aabbcc')),
        ),
        matchesSemantics(
          label: en.taskEditColourSemantics('#aabbcc'),
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(action(en.labelsCreate));
      await tester.pumpAndSettle();
      expect(harness.labels.created.single.hexColor, 'aabbcc');
    });

    testWidgets('no colour is sent as none', (tester) async {
      await openForm(tester, AppRoutes.labelNew);
      await tester.enterText(titleField(), 'Errands');

      await tester.tap(find.bySemanticsLabel(en.taskEditNoColour));
      await tester.pump();
      expect(tester.widget<TextField>(hexField()).controller!.text, isEmpty);
      await tester.tap(action(en.labelsCreate));
      await tester.pumpAndSettle();

      expect(harness.labels.created.single.hexColor, isEmpty);
    });

    testWidgets('offline it stays open and says a connection is needed', (
      tester,
    ) async {
      harness.labels.createFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await openForm(tester, AppRoutes.labelNew);
      await tester.enterText(titleField(), 'Errands');
      await tester.pump();

      await tester.tap(action(en.labelsCreate));
      await tester.pumpAndSettle();

      expect(find.byType(LabelFormPage), findsOneWidget);
      expect(find.text(en.labelsNewOffline), findsOneWidget);
    });

    testWidgets('the counter shows near the limit, in code points', (
      tester,
    ) async {
      await openForm(tester, AppRoutes.labelNew);

      await tester.enterText(titleField(), 'a' * 150);
      await tester.pump();
      expect(find.text('150/250'), findsNothing);

      await tester.enterText(titleField(), '${'a' * 208}😀');
      await tester.pump();
      expect(find.text('209/250'), findsOneWidget);
    });

    testWidgets('leaving with a typed title asks first', (tester) async {
      await openForm(tester, AppRoutes.labelNew);
      await tester.enterText(titleField(), 'Errands');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(en.labelsDiscardBody), findsOneWidget);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(find.byType(LabelFormPage), findsNothing);
      expect(harness.labels.created, isEmpty);
    });
  });

  group('an own label', () {
    setUp(
      () => harness.labels = FakeLabelRepository(
        labels: [
          ownLabel(
            1,
            'Urgent',
            hexColor: 'ff006e',
            html: '<p>Do these <strong>first</strong></p>',
          ),
        ],
      ),
    );

    testWidgets('opens with its values and sends only what changed', (
      tester,
    ) async {
      await openForm(tester, AppRoutes.labelEdit(1));

      expect(find.text(en.labelsEditTitle), findsOneWidget);
      expect(tester.widget<TextField>(titleField()).controller!.text, 'Urgent');
      expect(find.textContaining('Do these'), findsOneWidget);
      expect(enabled(tester, action(en.labelsSave)), isFalse);

      await tester.enterText(titleField(), 'Very urgent');
      await tester.pump();
      await tester.tap(action(en.labelsSave));
      await tester.pumpAndSettle();

      expect(harness.labels.updates, [
        (1, const LabelChanges(title: 'Very urgent')),
      ]);
      expect(find.byType(LabelFormPage), findsNothing);
      expect(find.text(en.labelsSaved), findsOneWidget);
    });

    testWidgets('a colour change alone sends only the colour', (tester) async {
      await openForm(tester, AppRoutes.labelEdit(1));

      await tester.tap(
        find.bySemanticsLabel(en.taskEditColourSemantics('#0072b2')),
      );
      await tester.pump();
      await tester.tap(action(en.labelsSave));
      await tester.pumpAndSettle();

      expect(harness.labels.updates, [
        (1, const LabelChanges(hexColor: '0072b2')),
      ]);
    });

    testWidgets('a colour from outside the palette stays chosen', (
      tester,
    ) async {
      await openForm(tester, AppRoutes.labelEdit(1));

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(en.taskEditColourSemantics('#ff006e')),
        ),
        isSemantics(
          label: en.taskEditColourSemantics('#ff006e'),
          isSelected: true,
        ),
      );
      expect(enabled(tester, action(en.labelsSave)), isFalse);
    });

    testWidgets('a colour from outside the palette can be chosen again '
        'after trying another', (tester) async {
      await openForm(tester, AppRoutes.labelEdit(1));

      await tester.tap(
        find.bySemanticsLabel(en.taskEditColourSemantics('#e69f00')),
      );
      await tester.pump();
      expect(enabled(tester, action(en.labelsSave)), isTrue);
      await tester.tap(
        find.bySemanticsLabel(en.taskEditColourSemantics('#ff006e')),
      );
      await tester.pump();

      expect(enabled(tester, action(en.labelsSave)), isFalse);
    });

    testWidgets('a label gone on the server closes the page and says so', (
      tester,
    ) async {
      harness.labels.changeFailure = const NotFound(code: 8002);
      await openForm(tester, AppRoutes.labelEdit(1));
      await tester.enterText(titleField(), 'Very urgent');
      await tester.pump();

      await tester.tap(action(en.labelsSave));
      await tester.pumpAndSettle();

      expect(find.byType(LabelFormPage), findsNothing);
      expect(find.text(en.labelsGone), findsOneWidget);
    });

    for (final (name, failure, text) in [
      ('not the creator', const Forbidden(), en.labelsNotCreator),
      ('invalid', const ValidationFailed(code: 2002), en.labelsInvalid),
      (
        'offline',
        const NetworkFailure(NetworkProblem.unreachable),
        en.labelsNeedsConnection,
      ),
    ]) {
      testWidgets('a refusal ($name) keeps the page open and says why', (
        tester,
      ) async {
        harness.labels.changeFailure = failure;
        await openForm(tester, AppRoutes.labelEdit(1));
        await tester.enterText(titleField(), 'Very urgent');
        await tester.pump();

        await tester.tap(action(en.labelsSave));
        await tester.pumpAndSettle();

        expect(find.byType(LabelFormPage), findsOneWidget);
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('its description opens the editor for the label', (
      tester,
    ) async {
      final bridges = FakeEditorBridges();
      await harness.pump(
        tester,
        location: AppRoutes.labelEdit(1),
        overrides: [bridges.override],
      );

      await tester.tap(find.text(en.labelsEditDescription));
      await tester.pumpAndSettle();

      expect(find.byType(DescriptionEditorPage), findsOneWidget);
      expect(currentLocation(tester), AppRoutes.labelDescription(1));
      expect(bridges.last.init!.html, '<p>Do these <strong>first</strong></p>');
    });

    testWidgets('a label deleted meanwhile shows that it is gone', (
      tester,
    ) async {
      await openForm(tester, AppRoutes.labelEdit(1));

      await harness.labels.delete(1);
      await tester.pumpAndSettle();

      expect(find.text(en.labelsGoneTitle), findsOneWidget);
    });
  });

  testWidgets("another person's label cannot be changed here", (tester) async {
    harness.labels = FakeLabelRepository(labels: [othersLabel(2, 'Shared')]);
    await openForm(tester, AppRoutes.labelEdit(2));

    expect(
      find.widgetWithText(ListNote, en.labelsDescriptionCreatorOnly),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(titleField()).enabled, isFalse);
    expect(action(en.labelsSave), findsNothing);
  });
}
