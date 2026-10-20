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

  bool truncated(WidgetTester tester, String title) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(AppBar), matching: find.text(title)),
    );
    return paragraph.getMaxIntrinsicWidth(double.infinity) >
        paragraph.size.width + 0.5;
  }

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

        expect(truncated(tester, l10n.tabOverview), isFalse);
        await openTab(tester, l10n.tabUpcoming);
        expect(truncated(tester, l10n.tabUpcoming), isFalse);
        await openTab(tester, l10n.tabProjects);
        expect(truncated(tester, l10n.tabProjects), isFalse);
      });
    }
  }
}
