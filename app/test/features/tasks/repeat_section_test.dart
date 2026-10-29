import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/application/repeat_editor.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/repeat_section.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/real_fonts.dart';

void main() {
  var robotoLoaded = false;
  setUpAll(() async => robotoLoaded = await loadRoboto());

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('the error under the amount wraps instead of being cut on a '
        '320 dp phone in ${locale.languageCode} at 200 %', (tester) async {
      if (!robotoLoaded) {
        markTestSkipped("the Flutter SDK's Roboto is needed to measure");
        return;
      }
      usePhoneSurface(tester, logicalSize: const Size(320, 740));
      useLocale(tester, locale);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final l10n = locale.languageCode == 'de' ? de : en;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RepeatSection(
                  value: const RepeatSetting(
                    mode: RepeatEditorMode.every,
                    amount: 0,
                    unit: RepeatUnit.days,
                  ),
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final error = tester.renderObject<RenderParagraph>(
        find.text(l10n.repeatAmountInvalid),
      );
      expect(error.didExceedMaxLines, isFalse);
      expect(
        error.getMaxIntrinsicWidth(double.infinity),
        greaterThan(error.size.width),
        reason: 'the error is longer than the field is wide',
      );
    });
  }
}
