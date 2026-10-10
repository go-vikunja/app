import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/repeat_editor.dart';

void main() {
  group('RepeatSetting.fromRepeat', () {
    test('30 days are 2592000 seconds and show as 30 days', () {
      final setting = RepeatSetting.fromRepeat(
        const Duration(seconds: 2592000),
        RepeatMode.afterAmount,
      );
      expect(setting.mode, RepeatEditorMode.every);
      expect(setting.amount, 30);
      expect(setting.unit, RepeatUnit.days);
      expect(setting.repeatAfter, const Duration(seconds: 2592000));
    });

    test('1209600 seconds show as 2 weeks', () {
      final setting = RepeatSetting.fromRepeat(
        const Duration(seconds: 1209600),
        RepeatMode.afterAmount,
      );
      expect(setting.amount, 2);
      expect(setting.unit, RepeatUnit.weeks);
    });

    test('whole hours show as hours', () {
      final setting = RepeatSetting.fromRepeat(
        const Duration(hours: 36),
        RepeatMode.fromCurrentDate,
      );
      expect(setting.mode, RepeatEditorMode.fromCompletion);
      expect(setting.amount, 36);
      expect(setting.unit, RepeatUnit.hours);
      expect(setting.repeatMode, RepeatMode.fromCurrentDate);
    });

    test("a value below the editor's units is rounded to hours", () {
      final setting = RepeatSetting.fromRepeat(
        const Duration(minutes: 90),
        RepeatMode.afterAmount,
      );
      expect(setting.amount, 2);
      expect(setting.unit, RepeatUnit.hours);
    });

    test('no repeat is mode none with a day to start from', () {
      expect(
        RepeatSetting.fromRepeat(Duration.zero, RepeatMode.afterAmount),
        RepeatSetting.none,
      );
      expect(
        RepeatSetting.fromRepeat(Duration.zero, RepeatMode.fromCurrentDate),
        RepeatSetting.none,
      );
    });

    test('monthly ignores the seconds but keeps them for a switch back', () {
      final setting = RepeatSetting.fromRepeat(
        const Duration(days: 3),
        RepeatMode.monthly,
      );
      expect(setting.mode, RepeatEditorMode.monthly);
      expect(setting.repeatAfter, Duration.zero);
      expect(setting.repeatMode, RepeatMode.monthly);
      final every = setting.copyWith(mode: RepeatEditorMode.every);
      expect(every.repeatAfter, const Duration(days: 3));
    });
  });

  group('conversions', () {
    test('2 weeks are 1209600 seconds', () {
      const setting = RepeatSetting(
        mode: RepeatEditorMode.every,
        amount: 2,
        unit: RepeatUnit.weeks,
      );
      expect(setting.repeatAfter.inSeconds, 1209600);
      expect(setting.repeatMode, RepeatMode.afterAmount);
    });

    test('the presets are a day, a week and 30 days', () {
      expect(
        RepeatSetting.none.withPreset(RepeatPreset.daily).repeatAfter,
        const Duration(days: 1),
      );
      expect(
        RepeatSetting.none.withPreset(RepeatPreset.weekly).repeatAfter,
        const Duration(days: 7),
      );
      final thirty = RepeatSetting.none.withPreset(RepeatPreset.thirtyDays);
      expect(thirty.repeatAfter.inSeconds, 2592000);
      expect(thirty.mode, RepeatEditorMode.every);
    });

    test('none removes the repeat: zero seconds, default mode', () {
      expect(RepeatSetting.none.repeatAfter, Duration.zero);
      expect(RepeatSetting.none.repeatMode, RepeatMode.afterAmount);
    });
  });

  group('validation', () {
    test('an amount of 0 is invalid where an amount counts', () {
      const every = RepeatSetting(
        mode: RepeatEditorMode.every,
        amount: 0,
        unit: RepeatUnit.days,
      );
      expect(every.isValid, isFalse);
      expect(every.copyWith(mode: RepeatEditorMode.monthly).isValid, isTrue);
      expect(every.copyWith(mode: RepeatEditorMode.none).isValid, isTrue);
      expect(every.copyWith(amount: 1).isValid, isTrue);
    });
  });
}
