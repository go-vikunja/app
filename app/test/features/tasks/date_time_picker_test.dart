import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';

void main() {
  // A Monday morning: the breakpoint time is 12:00.
  final now = DateTime(2026, 10, 19, 10, 15);
  const twentyFour = DisplaySettings(timeFormat: TimeFormat.twentyFourHour);

  Future<List<DateTime?>> open(
    WidgetTester tester, {
    DateTime? current,
    DisplaySettings display = twentyFour,
  }) async {
    final picked = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked.add(
                await pickDateTime(
                  context,
                  current: current,
                  now: now,
                  display: display,
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

  Future<void> pickDay(WidgetTester tester, String day) async {
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  }

  Future<void> confirmTime(WidgetTester tester) async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel in the time dialog keeps the day just picked, at the '
      'time the clock started from', (tester) async {
    final picked = await open(tester, current: DateTime(2026, 10, 21, 9, 30));

    await pickDay(tester, '24');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsNothing);
    expect(picked, [DateTime(2026, 10, 24, 9, 30)]);
  });

  testWidgets('Cancel in the time dialog of a date without a time keeps the '
      "day at the user's default due time", (tester) async {
    final picked = await open(
      tester,
      display: const DisplaySettings(
        timeFormat: TimeFormat.twentyFourHour,
        defaultDueTime: ClockTime(17, 45),
      ),
    );

    await pickDay(tester, '24');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, [DateTime(2026, 10, 24, 17, 45)]);
  });

  testWidgets('Cancel in the time dialog after picking today never keeps a '
      'time that has passed: 23:59 instead (QA-8)', (tester) async {
    final picked = await open(tester, current: DateTime(2026, 10, 21, 9, 30));

    await pickDay(tester, '19');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, [DateTime(2026, 10, 19, 23, 59)]);
  });

  testWidgets('Cancel in the time dialog after picking today, without a '
      'date, turns a passed default due time into 23:59 (QA-8)', (
    tester,
  ) async {
    final picked = await open(
      tester,
      display: const DisplaySettings(
        timeFormat: TimeFormat.twentyFourHour,
        defaultDueTime: ClockTime(9, 0),
      ),
    );

    await pickDay(tester, '19');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, [DateTime(2026, 10, 19, 23, 59)]);
  });

  testWidgets('Cancel in the time dialog after picking today keeps a time '
      'still ahead', (tester) async {
    final picked = await open(tester, current: DateTime(2026, 10, 21, 17));

    await pickDay(tester, '19');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picked, [DateTime(2026, 10, 19, 17)]);
  });

  testWidgets('Cancel in the date dialog backs out of the whole pick', (
    tester,
  ) async {
    final picked = await open(tester, current: DateTime(2026, 10, 21, 9, 30));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(picked, [null]);
  });

  testWidgets('the picked date at the time confirmed', (tester) async {
    final picked = await open(tester, current: DateTime(2026, 10, 21, 9, 30));

    await pickDay(tester, '24');
    await confirmTime(tester);

    expect(picked, [DateTime(2026, 10, 24, 9, 30)]);
  });

  testWidgets("without a date, the time starts at the user's default due "
      'time', (tester) async {
    final picked = await open(
      tester,
      display: const DisplaySettings(
        timeFormat: TimeFormat.twentyFourHour,
        defaultDueTime: ClockTime(17, 45),
      ),
    );

    await pickDay(tester, '24');
    await confirmTime(tester);

    expect(picked, [DateTime(2026, 10, 24, 17, 45)]);
  });

  testWidgets('without a date or a default due time, the time starts at '
      'the breakpoint', (tester) async {
    final picked = await open(tester);

    await pickDay(tester, '24');
    await confirmTime(tester);

    expect(picked, [DateTime(2026, 10, 24, 12)]);
  });

  testWidgets('a default due time that has passed today still starts the '
      'time on another day: no 23:59 there', (tester) async {
    final picked = await open(
      tester,
      display: const DisplaySettings(
        timeFormat: TimeFormat.twentyFourHour,
        defaultDueTime: ClockTime(9, 0),
      ),
    );

    await pickDay(tester, '24');
    await confirmTime(tester);

    expect(picked, [DateTime(2026, 10, 24, 9)]);
  });

  for (final (name, stored) in [
    ('before 2000', DateTime(1999, 3, 14, 9, 30)),
    ('past the usual last year', DateTime(now.year + 100, 6, 1, 8)),
  ]) {
    testWidgets('a stored date $name opens on its own day and OK keeps it', (
      tester,
    ) async {
      final picked = await open(tester, current: stored);

      expect(tester.takeException(), isNull);
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.initialDate, DateUtils.dateOnly(stored));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await confirmTime(tester);

      expect(picked, [stored]);
    });
  }
}
