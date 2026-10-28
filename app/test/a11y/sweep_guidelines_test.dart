import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'sweep_guidelines.dart';

Future<void> _pump(WidgetTester tester, Widget body) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [body]),
      ),
    ),
  ),
);

Future<Evaluation> _evaluate(
  WidgetTester tester,
  AccessibilityGuideline guideline,
) async => await guideline.evaluate(tester);

void main() {
  testWidgets('a header needs a heading level', (tester) async {
    await _pump(tester, Semantics(header: true, child: const Text('Today')));
    expect((await _evaluate(tester, headingLevelGuideline)).passed, isFalse);

    await _pump(
      tester,
      Semantics(header: true, headingLevel: 2, child: const Text('Today')),
    );
    expect((await _evaluate(tester, headingLevelGuideline)).passed, isTrue);
  });

  testWidgets('a heading is no button; custom actions do not count', (
    tester,
  ) async {
    await _pump(
      tester,
      Semantics(
        header: true,
        headingLevel: 2,
        button: true,
        onTap: () {},
        child: const Text('Accounts'),
      ),
    );
    final merged = await _evaluate(tester, headingNotControlGuideline);
    expect(merged.passed, isFalse);
    expect(merged.reason, contains('"Accounts"'));

    await _pump(
      tester,
      Column(
        children: [
          Semantics(header: true, headingLevel: 2, child: const Text('To do')),
          TextButton(onPressed: () {}, child: const Text('Add account')),
        ],
      ),
    );
    expect(
      (await _evaluate(tester, headingNotControlGuideline)).passed,
      isTrue,
    );

    await _pump(
      tester,
      Semantics(
        header: true,
        headingLevel: 2,
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Move column right'): () {},
        },
        child: const Text('To do'),
      ),
    );
    expect(
      (await _evaluate(tester, headingNotControlGuideline)).passed,
      isTrue,
    );
  });

  testWidgets('an image needs a label', (tester) async {
    await _pump(
      tester,
      Semantics(image: true, child: const SizedBox.square(dimension: 40)),
    );
    expect((await _evaluate(tester, imageLabelGuideline)).passed, isFalse);

    await _pump(
      tester,
      Semantics(
        image: true,
        label: 'Avatar of Kim',
        child: const SizedBox.square(dimension: 40),
      ),
    );
    expect((await _evaluate(tester, imageLabelGuideline)).passed, isTrue);
  });

  testWidgets('custom actions of one node read differently', (tester) async {
    await _pump(
      tester,
      Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Move up'): () {},
          const CustomSemanticsAction(label: 'move  up'): () {},
        },
        child: const Text('Row'),
      ),
    );
    expect((await _evaluate(tester, actionLabelGuideline)).passed, isFalse);

    await _pump(
      tester,
      Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Move up'): () {},
          const CustomSemanticsAction(label: 'Move down'): () {},
        },
        child: const Text('Row'),
      ),
    );
    expect((await _evaluate(tester, actionLabelGuideline)).passed, isTrue);
  });

  testWidgets('two controls of one name need different labelled ancestors '
      'or headings', (tester) async {
    Widget delete() => IconButton(
      onPressed: () {},
      tooltip: 'Delete',
      icon: const Icon(Icons.delete),
    );
    await _pump(tester, Row(children: [delete(), delete()]));
    final repeated = await _evaluate(tester, distinctTapLabelGuideline);
    expect(repeated.passed, isFalse);
    expect(repeated.reason, contains('2 controls read as "Delete"'));

    await _pump(
      tester,
      Row(
        children: [
          for (final row in ['Call the plumber', 'Buy seeds'])
            Semantics(container: true, label: row, child: delete()),
        ],
      ),
    );
    expect((await _evaluate(tester, distinctTapLabelGuideline)).passed, isTrue);

    Widget section(String title) => Column(
      children: [
        Semantics(header: true, headingLevel: 2, child: Text(title)),
        delete(),
      ],
    );
    await _pump(
      tester,
      Column(children: [section('Certificate'), section('Headers')]),
    );
    expect((await _evaluate(tester, distinctTapLabelGuideline)).passed, isTrue);

    await _pump(tester, Column(children: [section('Certificate'), delete()]));
    final sameHeading = await _evaluate(tester, distinctTapLabelGuideline);
    expect(sameHeading.passed, isFalse);
    expect(sameHeading.reason, contains('under "Certificate"'));
  });

  testWidgets("iOS keeps the segmented control's native height, and nothing "
      'else below 44 pt', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 300,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: 0,
          onValueChanged: (_) {},
          children: const {0: Text('Light'), 1: Text('Dark')},
        ),
      ),
    );
    expect((await _evaluate(tester, iOSTapTargetGuideline)).passed, isFalse);
    expect(
      (await _evaluate(tester, sweepIOSTapTargetGuideline)).passed,
      isTrue,
    );

    await _pump(
      tester,
      Semantics(
        button: true,
        label: 'Small',
        onTap: () {},
        child: const SizedBox(width: 120, height: 30),
      ),
    );
    expect(
      (await _evaluate(tester, sweepIOSTapTargetGuideline)).passed,
      isFalse,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets("Android keeps the date picker's day cells below 48 dp", (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(360, 740) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 10, 10),
                  firstDate: DateTime(2026),
                  lastDate: DateTime(2027),
                ),
                child: const Text('Pick'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    expect(
      (await _evaluate(tester, androidTapTargetGuideline)).passed,
      isFalse,
    );
    expect(
      (await _evaluate(tester, sweepAndroidTapTargetGuideline)).passed,
      isTrue,
    );
  });
}
