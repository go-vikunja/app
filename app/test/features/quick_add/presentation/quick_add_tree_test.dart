import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart';
import 'composer_harness.dart';

void main() {
  late ComposerHarness harness;

  setUp(() => harness = ComposerHarness());

  Finder addButton(int count) =>
      find.widgetWithText(FilledButton, en.newTaskAddMany(count));

  Finder projectChip(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ActionChip));

  testWidgets('indented lines show how many become subtasks', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Trip\n  Book flights\n  Pack');

    expect(find.text(en.newTaskTreeCountOnly(3, 2)), findsOneWidget);
    expect(find.text(en.newTaskLineCountOnly(3)), findsNothing);
    expect(addButton(3), findsOneWidget);
  });

  testWidgets('the tree note leads the first line chips', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Trip *urgent\n\t- Book flights');

    expect(find.text(en.newTaskTreeCount(2, 1)), findsOneWidget);
    expect(find.text('urgent'), findsOneWidget);
  });

  testWidgets('deeper levels count as subtasks too', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Trip\n  Flights\n    Compare prices\nGroceries');

    expect(find.text(en.newTaskTreeCountOnly(4, 2)), findsOneWidget);
    expect(addButton(4), findsOneWidget);
  });

  testWidgets('a list without indentation keeps the plain note', (
    tester,
  ) async {
    await harness.open(tester);
    await typeLine(tester, '- Milk\n- Eggs');

    expect(find.text(en.newTaskLineCountOnly(2)), findsOneWidget);
    expect(find.textContaining('subtask'), findsNothing);
  });

  testWidgets('a subtask without a project goes with its parent, so the '
      'project chip shows the parent project', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Launch +Work\n  Prepare slides');

    expect(tester.widget<ActionChip>(projectChip('Work')).onPressed, isNull);

    await tester.tap(addButton(2));
    await tester.pumpAndSettle();
    expect(
      harness.service.submits.single.text,
      'Launch +Work\n  Prepare slides',
    );
  });
}
