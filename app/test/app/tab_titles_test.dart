import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/pump_app.dart';
import '../helpers/real_fonts.dart';
import '../helpers/sample_data.dart';
import '../helpers/sync_fakes.dart';

void main() {
  var robotoLoaded = false;
  setUpAll(() async => robotoLoaded = await loadRoboto());

  RenderParagraph paragraphIn(WidgetTester tester, Type bar, String text) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byType(bar), matching: find.text(text)),
      );

  bool truncated(WidgetTester tester, String title) {
    final paragraph = paragraphIn(tester, AppBar, title);
    return paragraph.getMaxIntrinsicWidth(double.infinity) >
        paragraph.size.width + 0.5;
  }

  int lineCount(RenderParagraph paragraph) => {
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: paragraph.text.toPlainText().length,
      ),
    ))
      box.top,
  }.length;

  for (final locale in const [Locale('en'), Locale('de')]) {
    for (final scale in const [1.0, 1.15]) {
      testWidgets('the tab titles fit beside their actions on a 360 dp phone '
          'in ${locale.languageCode} at ${(scale * 100).round()} %', (
        tester,
      ) async {
        if (!robotoLoaded) {
          markTestSkipped("the Flutter SDK's Roboto is needed to measure");
          return;
        }
        usePhoneSurface(tester);
        useLocale(tester, locale);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l10n = locale.languageCode == 'de' ? de : en;
        final now = DateTime(2026, 10, 10, 12);
        final data = SyncFakes(now: now);
        data.projects.all = [sampleProject(id: 1, title: 'Work')];
        await pumpSignedInApp(tester, sync: data, now: now);

        // The Overview has a search bar and a greeting instead of a title.
        await openTab(tester, l10n.tabUpcoming);
        expect(truncated(tester, l10n.tabUpcoming), isFalse);
        await openTab(tester, l10n.tabProjects);
        expect(truncated(tester, l10n.tabProjects), isFalse);
      });
    }

    for (final width in const [360.0, 320.0]) {
      testWidgets('every navigation label stays on one line, selected or not, '
          'on a ${width.round()} dp phone in ${locale.languageCode} at '
          '200 %', (tester) async {
        if (!robotoLoaded) {
          markTestSkipped("the Flutter SDK's Roboto is needed to measure");
          return;
        }
        usePhoneSurface(tester, logicalSize: Size(width, 740));
        useLocale(tester, locale);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l10n = locale.languageCode == 'de' ? de : en;
        final now = DateTime(2026, 10, 10, 12);
        await pumpSignedInApp(
          tester,
          sync: SyncFakes(now: now),
          now: now,
        );

        final labels = [
          l10n.tabOverview,
          l10n.tabUpcoming,
          l10n.tabProjects,
          l10n.tabAccount,
        ];
        for (final selected in labels) {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(selected),
            ),
          );
          await tester.pumpAndSettle();
          for (final label in labels) {
            expect(
              lineCount(paragraphIn(tester, NavigationBar, label)),
              1,
              reason: '$label with $selected selected',
            );
          }
        }
      });
    }
  }
}
