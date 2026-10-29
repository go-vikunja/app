import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/real_fonts.dart';

void main() {
  var robotoLoaded = false;
  setUpAll(() async => robotoLoaded = await loadRoboto());

  Future<void> pumpCustomForm(WidgetTester tester, Locale locale) async {
    usePhoneSurface(tester, logicalSize: const Size(320, 740));
    useLocale(tester, locale);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          displaySettingsProvider.overrideWithValue(const DisplaySettings()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: ReminderPicker(
              dates: (due: null, start: null, end: null),
              now: DateTime(2026, 10, 29, 9),
              editing: const TaskReminder(
                relativePeriod: Duration(days: -1),
                relativeTo: ReminderRelativeTo.dueDate,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in const [Locale('en'), Locale('de')]) {
    final l10n = locale.languageCode == 'de' ? de : en;

    testWidgets('the error under the reminder amount wraps instead of being '
        'cut on a 320 dp phone in ${locale.languageCode} at 200 %', (
      tester,
    ) async {
      if (!robotoLoaded) {
        markTestSkipped("the Flutter SDK's Roboto is needed to measure");
        return;
      }
      await pumpCustomForm(tester, locale);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      final error = tester.renderObject<RenderParagraph>(
        find.text(l10n.reminderAmountInvalid),
      );
      expect(error.didExceedMaxLines, isFalse);
      expect(
        error.getMaxIntrinsicWidth(double.infinity),
        greaterThan(error.size.width),
        reason: 'the error is longer than the field is wide',
      );
    });

    testWidgets('the reference chips for unset dates fit on a 320 dp phone '
        'in ${locale.languageCode} at 200 %', (tester) async {
      if (!robotoLoaded) {
        markTestSkipped("the Flutter SDK's Roboto is needed to measure");
        return;
      }
      await pumpCustomForm(tester, locale);

      for (final reference in [
        l10n.reminderRelativeToDueDate,
        l10n.reminderRelativeToStartDate,
        l10n.reminderRelativeToEndDate,
      ]) {
        final label = find.text(l10n.reminderRelativeToUnset(reference));
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: reference);
        expect(paragraph.debugHasOverflowShader, isFalse, reason: reference);
        expect(
          tester
              .getRect(
                find.ancestor(of: label, matching: find.byType(ChoiceChip)),
              )
              .right,
          lessThanOrEqualTo(320),
          reason: reference,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
