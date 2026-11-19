import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_days.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_row.dart';

import '../../helpers/real_fonts.dart';
import '../../helpers/sample_data.dart';

void main() {
  var robotoLoaded = false;
  setUpAll(() async => robotoLoaded = await loadRoboto());

  const title = 'Quarterly budget review with the finance team';
  const range = GanttRange(
    from: CalendarDate(2026, 10, 19),
    to: CalendarDate(2026, 10, 30),
  );
  const barDays = 5;
  final row = GanttRow(
    task: sampleTask(id: 1, title: title),
    bar: const GanttBar(
      kind: GanttBarKind.scheduled,
      first: CalendarDate(2026, 10, 20),
      days: barDays,
      column: 1,
    ),
  );

  Widget app(Widget Function(BuildContext context) build) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Builder(builder: build),
      ),
    ),
  );

  double widthOf(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// A day width at which the title fits inside the bar, with the gaps on
  /// both sides of it, in regular type but not in bold.
  Future<double> dayWidthFittingRegularOnly(WidgetTester tester) async {
    late TextStyle style;
    await tester.pumpWidget(
      app((context) {
        style = TimelineRowMetrics.titleStyleOf(context);
        return const SizedBox();
      }),
    );
    final regular = widthOf(style);
    final bold = widthOf(
      style.merge(const TextStyle(fontWeight: FontWeight.bold)),
    );
    expect(bold, greaterThan(regular + 1));
    const gaps = 2 * TimelineRowMetrics.labelGap;
    return ((regular + bold) / 2 + gaps) / barDays;
  }

  Future<void> pumpRow(WidgetTester tester, double dayWidth) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final days = TimelineDays(range: range, dayWidth: dayWidth);
    await tester.pumpWidget(
      app(
        (context) => TimelineRow(
          row: row,
          days: days,
          horizontal: controller,
          viewportWidth: days.width,
          metrics: TimelineRowMetrics.of(context),
          semanticsLabel: title,
          groupSpans: const [],
          onTap: () {},
        ),
      ),
    );
  }

  double barRight(double dayWidth) => (1 + barDays) * dayWidth;

  testWidgets('without Bold Text a title that fits stays inside its bar', (
    tester,
  ) async {
    if (!robotoLoaded) {
      markTestSkipped("the Flutter SDK's Roboto is needed to measure");
      return;
    }
    final dayWidth = await dayWidthFittingRegularOnly(tester);
    await pumpRow(tester, dayWidth);

    expect(
      tester.getRect(find.text(title)).right,
      lessThan(barRight(dayWidth)),
    );
    expect(
      tester.renderObject<RenderParagraph>(find.text(title)).didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('with Bold Text a title that fits its bar only in regular '
      'type goes beside the bar in full, not cut inside it', (tester) async {
    if (!robotoLoaded) {
      markTestSkipped("the Flutter SDK's Roboto is needed to measure");
      return;
    }
    final dayWidth = await dayWidthFittingRegularOnly(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpRow(tester, dayWidth);

    expect(
      tester.getRect(find.text(title)).left,
      greaterThanOrEqualTo(barRight(dayWidth)),
    );
    expect(
      tester.renderObject<RenderParagraph>(find.text(title)).didExceedMaxLines,
      isFalse,
    );
  });
}
