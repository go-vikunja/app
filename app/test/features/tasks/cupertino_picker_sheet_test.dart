import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/cupertino_picker_sheet.dart';

import '../../helpers/pump_app.dart';

/// iOS's largest accessibility text size (AX5), as the engine maps it.
const double _ax5 = 53 / 17;

void main() {
  final now = DateTime(2026, 10, 10, 12);

  Future<void> openSheet(
    WidgetTester tester, {
    required Locale locale,
    String? Function(AppLocalizations l10n)? title,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showCupertinoPickerSheet(
                  context,
                  // The test font's square glyphs make the German date
                  // columns too wide for 320 points; the header is the same
                  // in every mode.
                  mode: CupertinoDatePickerMode.time,
                  initial: now,
                  use24Hour: true,
                  title: title?.call(context.l10n),
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
  }

  testWidgets('at the default size the title sits between the buttons', (
    tester,
  ) async {
    usePhoneSurface(tester, logicalSize: const Size(375, 667));
    await openSheet(
      tester,
      locale: const Locale('en'),
      title: (l10n) => l10n.apiTokenFormExpiryPick,
    );

    final title = tester.getRect(find.text(en.apiTokenFormExpiryPick));
    final cancel = tester.getRect(find.text(en.pickerCancel));
    final done = tester.getRect(find.text(en.pickerDone));
    expect(title.center.dy, moreOrLessEquals(cancel.center.dy, epsilon: 1));
    expect(cancel.right, lessThanOrEqualTo(title.left));
    expect(title.right, lessThanOrEqualTo(done.left));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('at the largest iOS text size', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final size in const [Size(375, 667), Size(320, 568)]) {
        for (final withTitle in [true, false]) {
          final name =
              '${locale.languageCode}, ${size.width.toInt()} points, '
              '${withTitle ? 'with' : 'without'} a title';
          testWidgets('the sheet fits: $name', (tester) async {
            usePhoneSurface(tester, logicalSize: size);
            useLocale(tester, locale);
            tester.platformDispatcher.textScaleFactorTestValue = _ax5;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await openSheet(
              tester,
              locale: locale,
              title: withTitle ? (l10n) => l10n.apiTokenFormExpiryPick : null,
            );

            expect(tester.takeException(), isNull);
            final l10n = lookupAppLocalizations(locale);
            final cancel = find.text(l10n.pickerCancel);
            final done = find.text(l10n.pickerDone);
            final wheel = tester.getRect(find.byType(CupertinoDatePicker));
            expect(wheel.top, greaterThanOrEqualTo(0));
            expect(wheel.bottom, lessThanOrEqualTo(size.height));
            for (final button in [cancel, done]) {
              expect(
                tester.getRect(button).bottom,
                lessThanOrEqualTo(wheel.top),
              );
              expect(
                MediaQuery.textScalerOf(tester.element(button)).scale(10),
                10 * AppBarTextAction.maxTextScale,
              );
            }
            if (withTitle) {
              final title = find.text(l10n.apiTokenFormExpiryPick);
              expect(
                tester.getRect(title).bottom,
                lessThanOrEqualTo(tester.getRect(cancel).top),
              );
              expect(
                tester.getSemantics(title).getSemanticsData().headingLevel,
                1,
              );
            }

            await tester.tap(done);
            await tester.pumpAndSettle();
            expect(find.byType(CupertinoDatePicker), findsNothing);
          }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
        }
      }
    }
  });
}
