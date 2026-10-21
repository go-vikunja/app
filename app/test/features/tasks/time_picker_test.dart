import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/time_picker.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<List<TimeOfDay?>> open(
    WidgetTester tester, {
    required DisplaySettings display,
    Locale locale = const Locale('en'),
    String? title,
  }) async {
    final picked = <TimeOfDay?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked.add(
                await pickTimeOfDay(
                  context,
                  initial: const TimeOfDay(hour: 9, minute: 0),
                  display: display,
                  title: title,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('a time typed in the Material picker, 24 hours as set', (
    tester,
  ) async {
    final picked = await open(
      tester,
      display: const DisplaySettings(timeFormat: TimeFormat.twentyFourHour),
      title: 'Time of the summary',
    );

    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('Time of the summary'), findsOneWidget);
    expect(find.text('AM'), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '18');
    await tester.enterText(fields.at(1), '45');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked, [const TimeOfDay(hour: 18, minute: 45)]);
  });

  testWidgets('12 hours as set, also in German', (tester) async {
    await open(
      tester,
      display: const DisplaySettings(timeFormat: TimeFormat.twelveHour),
      locale: const Locale('de'),
    );

    expect(find.text('AM'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
  });

  testWidgets('cancelled, nothing', (tester) async {
    final picked = await open(tester, display: const DisplaySettings());

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, [null]);
  });

  testWidgets('a time-only wheel on iOS', (tester) async {
    final picked = await open(
      tester,
      display: const DisplaySettings(timeFormat: TimeFormat.twentyFourHour),
      title: 'Time of the summary',
    );

    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.mode, CupertinoDatePickerMode.time);
    expect(wheel.use24hFormat, isTrue);
    expect(find.text('Time of the summary'), findsOneWidget);
    await tester.tap(find.text(en.pickerDone));
    await tester.pumpAndSettle();

    expect(picked, [const TimeOfDay(hour: 9, minute: 0)]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
