import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/day_range_picker.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import 'edit_page_harness.dart';

/// The week start and the time format of the web in the app's pickers.
void main() {
  final now = DateTime(2026, 10, 19, 12);

  Future<void> pumpOpener(
    WidgetTester tester, {
    required Locale locale,
    required void Function(BuildContext context) onOpen,
    bool device24Hour = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(alwaysUse24HourFormat: device24Hour),
          child: child!,
        ),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onOpen(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openDateTime(
    WidgetTester tester, {
    required DisplaySettings display,
    Locale locale = const Locale('en'),
    bool device24Hour = false,
  }) => pumpOpener(
    tester,
    locale: locale,
    device24Hour: device24Hour,
    onOpen: (context) => unawaited(
      pickDateTime(
        context,
        current: DateTime(2026, 10, 19, 9, 30),
        now: now,
        display: display,
      ),
    ),
  );

  /// The weekday letters of the calendar's header row, left to right.
  List<String> weekdayHeader(WidgetTester tester) {
    final letters = [
      for (final element
          in find
              .descendant(
                of: find.byType(CalendarDatePicker),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Text &&
                      RegExp(r'^[A-Z]$').hasMatch(widget.data!),
                ),
              )
              .evaluate())
        (tester.getTopLeft(find.byWidget(element.widget)), element.widget),
    ];
    final top = letters
        .map((letter) => letter.$1.dy)
        .reduce((a, b) => a < b ? a : b);
    final row = letters.where((letter) => letter.$1.dy == top).toList()
      ..sort((a, b) => a.$1.dx.compareTo(b.$1.dx));
    return [for (final (_, text) in row) (text as Text).data!];
  }

  int firstDayOfWeekInPicker(WidgetTester tester) =>
      MaterialLocalizations.of(tester.element(find.byType(CalendarDatePicker)))
          .firstDayOfWeekIndex;

  group('week start in the Material calendar', () {
    testWidgets("a week start the user picked replaces the locale's", (
      tester,
    ) async {
      await openDateTime(tester, display: const DisplaySettings(weekStart: 1));

      expect(firstDayOfWeekInPicker(tester), 1);
      expect(weekdayHeader(tester), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
    });

    testWidgets("Sunday, the server's default, keeps the German Monday", (
      tester,
    ) async {
      await openDateTime(
        tester,
        display: const DisplaySettings(),
        locale: const Locale('de'),
      );

      expect(firstDayOfWeekInPicker(tester), 1);
      expect(weekdayHeader(tester), ['M', 'D', 'M', 'D', 'F', 'S', 'S']);
    });

    testWidgets('Saturday in German', (tester) async {
      await openDateTime(
        tester,
        display: const DisplaySettings(weekStart: 6),
        locale: const Locale('de'),
      );

      expect(firstDayOfWeekInPicker(tester), 6);
      expect(weekdayHeader(tester), ['S', 'S', 'M', 'D', 'M', 'D', 'F']);
      // The rest of the dialog stays German.
      expect(find.text('Abbrechen'), findsOneWidget);
    });

    testWidgets("Upcoming's range picker starts the week alike", (
      tester,
    ) async {
      await pumpOpener(
        tester,
        locale: const Locale('en'),
        onOpen: (context) => unawaited(
          pickDayRange(
            context,
            first: now,
            last: now,
            now: now,
            firstDayOfWeekIndex: 3,
          ),
        ),
      );

      expect(firstDayOfWeekInPicker(tester), 3);
      expect(weekdayHeader(tester).first, 'W');
    });
  });

  group('the clock of the Material time picker', () {
    Future<void> toTimePicker(WidgetTester tester) async {
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
    }

    testWidgets('12 hours in German', (tester) async {
      await openDateTime(
        tester,
        display: const DisplaySettings(timeFormat: TimeFormat.twelveHour),
        locale: const Locale('de'),
      );
      await toTimePicker(tester);

      expect(find.text('AM'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
      expect(find.text('9'), findsWidgets);
    });

    testWidgets('24 hours in English', (tester) async {
      await openDateTime(
        tester,
        display: const DisplaySettings(timeFormat: TimeFormat.twentyFourHour),
      );
      await toTimePicker(tester);

      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
      expect(find.text('09'), findsWidgets);
    });

    testWidgets("never set, the locale's clock", (tester) async {
      await openDateTime(tester, display: const DisplaySettings());
      await toTimePicker(tester);

      expect(find.text('AM'), findsOneWidget);
    });

    testWidgets('picking in 12 hours returns the right instant', (
      tester,
    ) async {
      DateTime? picked;
      await pumpOpener(
        tester,
        locale: const Locale('de'),
        onOpen: (context) async => picked = await pickDateTime(
          context,
          current: DateTime(2026, 10, 19, 9, 30),
          now: now,
          display: const DisplaySettings(timeFormat: TimeFormat.twelveHour),
        ),
      );
      await toTimePicker(tester);
      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(picked, DateTime(2026, 10, 19, 21, 30));
    });
  });

  testWidgets('the Cupertino wheel follows the time format, else the device', (
    tester,
  ) async {
    Future<bool> wheelUses24Hours(
      DisplaySettings display, {
      Locale locale = const Locale('en'),
    }) async {
      await openDateTime(tester, display: display, locale: locale);
      final uses24Hours = tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .use24hFormat;
      await tester.tap(find.byType(CupertinoButton).first);
      await tester.pumpAndSettle();
      return uses24Hours;
    }

    expect(
      await wheelUses24Hours(
        const DisplaySettings(timeFormat: TimeFormat.twentyFourHour),
      ),
      isTrue,
    );
    expect(
      await wheelUses24Hours(
        const DisplaySettings(timeFormat: TimeFormat.twelveHour),
        locale: const Locale('de'),
      ),
      isFalse,
    );
    expect(await wheelUses24Hours(const DisplaySettings()), isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    "without a time format the wheel follows the device's 24-hour switch",
    (tester) async {
      await openDateTime(
        tester,
        display: const DisplaySettings(),
        device24Hour: true,
      );

      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .use24hFormat,
        isTrue,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets("the edit page's pickers take the account's settings", (
    tester,
  ) async {
    final data = SyncFakes(now: now)
      ..projects.all = [sampleProject(id: 1, title: 'Work')]
      ..tasks.all = [sampleTask(id: 1, title: 'Plan')]
      ..shared.settings = const UserSettings(
        weekStart: 5,
        timeFormat: TimeFormat.twentyFourHour,
      );
    await openEditPageWith(tester, data: data, taskId: 1, now: now);

    await tapVisible(tester, find.text(en.taskDetailDueDate));
    expect(firstDayOfWeekInPicker(tester), 5);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('AM'), findsNothing);
  });
}
