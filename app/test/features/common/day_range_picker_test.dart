import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/common/presentation/day_range_picker.dart';

import '../../helpers/pump_app.dart';

/// iOS's largest accessibility text size (AX5), as the engine maps it.
const double _ax5 = 53 / 17;

void main() {
  final now = DateTime(2026, 10, 10, 12);

  Future<void> openSheet(WidgetTester tester, Locale locale) async {
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
                pickDayRange(
                  context,
                  first: now,
                  last: now.add(const Duration(days: 6)),
                  now: now,
                  firstDayOfWeekIndex: 1,
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

  testWidgets('at the default size Cancel and Done share a line', (
    tester,
  ) async {
    usePhoneSurface(tester, logicalSize: const Size(375, 667));
    await openSheet(tester, const Locale('en'));

    final cancel = tester.getRect(find.text(en.pickerCancel));
    final done = tester.getRect(find.text(en.pickerDone));
    expect(done.center.dy, moreOrLessEquals(cancel.center.dy, epsilon: 1));
    expect(cancel.right, lessThan(done.left));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('at the largest iOS text size', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final size in const [Size(375, 667), Size(320, 568)]) {
        final name = '${locale.languageCode}, ${size.width.toInt()} points';
        testWidgets('the sheet fits: $name', (tester) async {
          usePhoneSurface(tester, logicalSize: size);
          useLocale(tester, locale);
          tester.platformDispatcher.textScaleFactorTestValue = _ax5;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await openSheet(tester, locale);

          expect(tester.takeException(), isNull);
          final l10n = lookupAppLocalizations(locale);
          bool onScreen(Rect rect) =>
              rect.left >= 0 &&
              rect.top >= 0 &&
              rect.right <= size.width &&
              rect.bottom <= size.height;
          final wheel = tester.getRect(find.byType(CupertinoDatePicker));
          expect(onScreen(wheel), isTrue);
          for (final button in [l10n.pickerCancel, l10n.pickerDone]) {
            final rect = tester.getRect(find.text(button));
            expect(onScreen(rect), isTrue, reason: button);
            expect(rect.bottom, lessThanOrEqualTo(wheel.top), reason: button);
            expect(
              MediaQuery.textScalerOf(tester.element(find.text(button)))
                  .scale(10),
              10 * AppBarTextAction.maxTextScale,
            );
          }
          final from = find.text(l10n.upcomingRangeFrom);
          expect(tester.getRect(from).bottom, lessThanOrEqualTo(wheel.top));

          await tester.tap(find.text(l10n.pickerDone));
          await tester.pumpAndSettle();
          expect(find.byType(CupertinoDatePicker), findsNothing);
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
      }
    }
  });
}
