import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';

import '../../helpers/pump_app.dart';

/// The arguments of the call whose `(` is at [open], without those of the
/// calls and literals nested in it.
String _topLevelArguments(String source, int open) {
  final own = StringBuffer();
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if ('([{'.contains(char)) depth++;
    if (')]}'.contains(char)) depth--;
    if (depth == 0) break;
    if (depth == 1) own.write(char);
  }
  return own.toString();
}

void main() {
  test('every Material bottom sheet names its barrier through '
      'sheetBarrierLabel', () {
    final calls = RegExp(r'\bshowModalBottomSheet\s*(<.*?>)?\(');
    final missing = <String>[];
    var found = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final call in calls.allMatches(source)) {
        found++;
        if (!_topLevelArguments(
          source,
          call.end - 1,
        ).contains(RegExp(r'barrierLabel:\s*sheetBarrierLabel\b'))) {
          missing.add('${file.path} at ${call.start}');
        }
      }
    }
    expect(found, greaterThan(0));
    expect(missing, isEmpty);
  });

  Future<void> openOptionSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOptionSheet<int>(
                context,
                title: 'Priority',
                options: const [SheetOption(value: 1, label: 'High')],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String? barrierLabel(WidgetTester tester) => tester
      .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier).last)
      .semanticsLabel;

  testWidgets('a screen reader hears the barrier beside a sheet as '
      '"Dismiss", not as the scrim', (tester) async {
    await openOptionSheet(tester);

    final material = MaterialLocalizations.of(
      tester.element(find.text('High')),
    );
    expect(barrierLabel(tester), material.modalBarrierDismissLabel);
    expect(barrierLabel(tester), 'Dismiss');
    expect(find.bySemanticsLabel(material.scrimLabel), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('in German as "Schließen", not "Gitter"', (tester) async {
    useLocale(tester, const Locale('de'));
    await openOptionSheet(tester);

    expect(barrierLabel(tester), 'Schließen');
    expect(find.bySemanticsLabel('Gitter'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
