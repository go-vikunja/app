import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/application/color_palette.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    String value = '',
    String original = '',
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: ColorRow(value: value, original: original, onChanged: (_) {}),
      ),
    ),
  );

  /// The swatches' labels as a screen reader reads them, in order.
  List<String> swatchLabels(WidgetTester tester) => [
    for (final semantics in tester.widgetList<Semantics>(
      find.descendant(
        of: find.byType(ColorRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.button ?? false),
        ),
      ),
    ))
      semantics.properties.label!,
  ];

  testWidgets('the swatches of the palette are read by their names, a '
      'colour from outside it by its hex code', (tester) async {
    await pumpRow(tester, value: '008080', original: '008080');

    expect(swatchLabels(tester), [
      'No color',
      'Orange',
      'Sky blue',
      'Bluish green',
      'Yellow',
      'Blue',
      'Vermilion',
      'Reddish purple',
      'Color #008080',
    ]);
  });

  test('every colour of the palette has a name of its own', () {
    final names = [for (final hex in okabeItoColors) colorSwatchLabel(en, hex)];

    expect(names.toSet(), hasLength(okabeItoColors.length));
    for (final name in names) {
      expect(name, isNot(contains('#')));
    }
  });

  testWidgets('a named swatch reads as a selected button by its name only', (
    tester,
  ) async {
    await pumpRow(tester, value: '0072b2');

    expect(
      tester.getSemantics(find.bySemanticsLabel(en.colorNameBlue)),
      matchesSemantics(
        label: 'Blue',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp('#0072b2')), findsNothing);
  });
}
