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

  Future<List<String>> weekdaysShown(
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
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(ValueKey(day - 19)),
                    matching: find.byType(Text),
                  )
                  .first,
            )
            .data!,
    ];
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
}
