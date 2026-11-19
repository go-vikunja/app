import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_header.dart';

import '../../helpers/real_fonts.dart';

void main() {
  var robotoLoaded = false;
  setUpAll(() async => robotoLoaded = await loadRoboto());

  // Monday Oct 19 to Sunday Oct 25, 2026.
  const range = GanttRange(
    from: CalendarDate(2026, 10, 19),
    to: CalendarDate(2026, 10, 25),
  );

  /// Each day's texts, its weekday and, where shown, its number.
  Future<List<List<String>>> dayTexts(
    WidgetTester tester, {
    required Locale locale,
    required double dayWidth,
  }) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final days = TimelineDays(range: range, dayWidth: dayWidth);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: controller,
            child: TimelineHeader(
              days: days,
              today: const CalendarDate(2026, 10, 21),
              horizontal: controller,
              viewportWidth: days.width,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return [
      for (var day = 19; day <= 25; day++)
        [
          for (final text in tester.widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey(day - 19)),
              matching: find.byType(Text),
            ),
          ))
            text.data!,
        ],
    ];
  }

  Future<List<String>> weekdaysShown(
    WidgetTester tester, {
    required Locale locale,
    required double dayWidth,
  }) async => [
    for (final texts in await dayTexts(
      tester,
      locale: locale,
      dayWidth: dayWidth,
    ))
      texts.first,
  ];

  /// The narrowest day width, to a hundredth, at which [shows] holds of the
  /// days' texts; it holds at every wider one.
  Future<double> narrowestDayShowing(
    WidgetTester tester,
    bool Function(List<List<String>> days) shows,
  ) async {
    var (narrow, wide) = (8.0, 80.0);
    while (wide - narrow > 0.01) {
      final middle = (narrow + wide) / 2;
      final days = await dayTexts(
        tester,
        locale: const Locale('en'),
        dayWidth: middle,
      );
      if (shows(days)) {
        wide = middle;
      } else {
        narrow = middle;
      }
    }
    return wide;
  }

  void useBoldText(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  testWidgets('the days show their short weekday names where the widest of '
      'them fits, in English and German', (tester) async {
    if (!robotoLoaded) {
      markTestSkipped("the Flutter SDK's Roboto is needed to measure");
      return;
    }
    expect(
      await weekdaysShown(tester, locale: const Locale('en'), dayWidth: 36),
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    );
    expect(
      await weekdaysShown(tester, locale: const Locale('de'), dayWidth: 36),
      ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    );
  });

  testWidgets("German keeps its short names at a width where English's "
      'no longer fit', (tester) async {
    if (!robotoLoaded) {
      markTestSkipped("the Flutter SDK's Roboto is needed to measure");
      return;
    }
    expect(
      await weekdaysShown(tester, locale: const Locale('en'), dayWidth: 24),
      ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    );
    expect(
      await weekdaysShown(tester, locale: const Locale('de'), dayWidth: 24),
      ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    );
  });

  testWidgets('the narrowest days show one letter in both languages', (
    tester,
  ) async {
    if (!robotoLoaded) {
      markTestSkipped("the Flutter SDK's Roboto is needed to measure");
      return;
    }
    expect(
      await weekdaysShown(tester, locale: const Locale('en'), dayWidth: 20),
      ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    );
    expect(
      await weekdaysShown(tester, locale: const Locale('de'), dayWidth: 20),
      ['M', 'D', 'M', 'D', 'F', 'S', 'S'],
    );
  });

  testWidgets('with Bold Text the weekdays shorten at a wider day, as they '
      'are measured bold', (tester) async {
    if (!robotoLoaded) {
      markTestSkipped("the Flutter SDK's Roboto is needed to measure");
      return;
    }
    bool shortNames(List<List<String>> days) => days.first.first == 'Mon';
    final plain = await narrowestDayShowing(tester, shortNames);
    useBoldText(tester);
    final bold = await narrowestDayShowing(tester, shortNames);

    expect(bold, greaterThan(plain));
    expect(
      await weekdaysShown(tester, locale: const Locale('en'), dayWidth: plain),
      ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    );
  });

  testWidgets('with Bold Text at 150 % every day keeps its number only where '
      'the bold numbers fit', (tester) async {
    if (!robotoLoaded) {
      markTestSkipped("the Flutter SDK's Roboto is needed to measure");
      return;
    }
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    bool everyNumber(List<List<String>> days) =>
        days.every((texts) => texts.length == 2);
    final plain = await narrowestDayShowing(tester, everyNumber);
    useBoldText(tester);
    final bold = await narrowestDayShowing(tester, everyNumber);

    expect(bold, greaterThan(plain));
    final days = await dayTexts(
      tester,
      locale: const Locale('en'),
      dayWidth: plain,
    );
    expect([for (final texts in days) texts.length], [2, 1, 2, 1, 2, 1, 2]);
  });
}
