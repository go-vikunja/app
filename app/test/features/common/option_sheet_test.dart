import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';

void main() {
  late Future<int?> picked;

  Future<void> open(WidgetTester tester, List<SheetOption<int>> options) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => picked = showOptionSheet<int>(
                context,
                title: 'Due date',
                options: options,
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

  ListTile tile(WidgetTester tester, String label) =>
      tester.widget<ListTile>(find.widgetWithText(ListTile, label));

  testWidgets('an option with a subtitle shows it under its label and reads '
      'it by its own label; one without has none', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, const [
      SheetOption(
        value: 1,
        label: 'Today',
        subtitle: '10/10/2026 12:00',
        subtitleSemanticsLabel: 'Saturday, October 10, 2026 at 12:00',
        selected: true,
      ),
      SheetOption(value: 2, label: 'Tomorrow', subtitle: '11/10/2026 12:00'),
      SheetOption(value: 3, label: 'Pick date…'),
    ]);

    final today = tester.getRect(find.text('Today'));
    final todaySubtitle = tester.getRect(find.text('10/10/2026 12:00'));
    expect(todaySubtitle.top, greaterThanOrEqualTo(today.bottom));
    expect(
      find.bySemanticsLabel(
        RegExp('^Today\nSaturday, October 10, 2026 at 12:00\$'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('10/10/2026')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('^Tomorrow\n11/10/2026 12:00\$')),
      findsOneWidget,
    );
    expect(tile(tester, 'Pick date…').subtitle, isNull);
    expect(tile(tester, 'Today').selected, isTrue);
    expect(tile(tester, 'Tomorrow').selected, isFalse);

    await tester.tap(find.text('11/10/2026 12:00'));
    await tester.pumpAndSettle();
    expect(await picked, 2);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the subtitle shows in the iOS sheet too', (tester) async {
    await open(tester, const [
      SheetOption(value: 1, label: 'Today', subtitle: '10/10/2026 12:00'),
      SheetOption(value: 2, label: 'Pick date…'),
    ]);

    expect(tile(tester, 'Today').subtitle, isA<Text>());
    expect(tile(tester, 'Pick date…').subtitle, isNull);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(await picked, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
