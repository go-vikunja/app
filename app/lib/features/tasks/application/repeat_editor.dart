import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The units the web's repeat editor offers.
enum RepeatUnit {
  hours(Duration(hours: 1)),
  days(Duration(days: 1)),
  weeks(Duration(days: 7));

  new(this.length);

  final Duration length;
}

/// How the editor shows [RepeatMode] plus "no repeat".
enum RepeatEditorMode { none, every, monthly, fromCompletion }

/// The web's presets: every day, every week, every 30 days.
enum RepeatPreset {
  daily(1, RepeatUnit.days),
  weekly(1, RepeatUnit.weeks),
  thirtyDays(30, RepeatUnit.days);

  new(this.amount, this.unit);

  final int amount;
  final RepeatUnit unit;
}

/// The repeat section's state: [amount] and [unit] matter for
/// [RepeatEditorMode.every] and [RepeatEditorMode.fromCompletion] only, and
/// are kept while the mode is something else so that switching back
/// restores them.
@immutable
final class RepeatSetting {
  const new({required this.mode, required this.amount, required this.unit});

  /// The web's `secondsToPeriod` over the units the editor has: the largest
  /// of weeks, days and hours that divides evenly, else whole hours.
  factory fromTask(Task task) =>
      RepeatSetting.fromRepeat(task.repeatAfter, task.repeatMode);

  factory fromRepeat(Duration repeatAfter, RepeatMode repeatMode) {
    final mode = switch (repeatMode) {
      RepeatMode.monthly => RepeatEditorMode.monthly,
      RepeatMode.fromCurrentDate when repeatAfter > Duration.zero =>
        RepeatEditorMode.fromCompletion,
      RepeatMode.afterAmount when repeatAfter > Duration.zero =>
        RepeatEditorMode.every,
      _ => RepeatEditorMode.none,
    };
    if (repeatAfter <= Duration.zero) {
      return RepeatSetting(mode: mode, amount: 1, unit: RepeatUnit.days);
    }
    final seconds = repeatAfter.inSeconds;
    for (final unit in [RepeatUnit.weeks, RepeatUnit.days, RepeatUnit.hours]) {
      final length = unit.length.inSeconds;
      if (seconds % length == 0) {
        return RepeatSetting(mode: mode, amount: seconds ~/ length, unit: unit);
      }
    }
    final hours = (seconds / Duration.secondsPerHour).round();
    return RepeatSetting(
      mode: mode,
      amount: hours < 1 ? 1 : hours,
      unit: RepeatUnit.hours,
    );
  }

  static const none = RepeatSetting(
    mode: RepeatEditorMode.none,
    amount: 1,
    unit: RepeatUnit.days,
  );

  final RepeatEditorMode mode;
  final int amount;
  final RepeatUnit unit;

  bool get usesAmount =>
      mode == RepeatEditorMode.every || mode == RepeatEditorMode.fromCompletion;

  /// The web saves nothing for an amount of 0 in the modes that use one.
  bool get isValid => !usesAmount || amount > 0;

  RepeatSetting copyWith({
    RepeatEditorMode? mode,
    int? amount,
    RepeatUnit? unit,
  }) => RepeatSetting(
    mode: mode ?? this.mode,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
  );

  RepeatSetting withPreset(RepeatPreset preset) => RepeatSetting(
    mode: RepeatEditorMode.every,
    amount: preset.amount,
    unit: preset.unit,
  );

  Duration get repeatAfter => usesAmount ? unit.length * amount : Duration.zero;

  RepeatMode get repeatMode => switch (mode) {
    RepeatEditorMode.none || RepeatEditorMode.every => RepeatMode.afterAmount,
    RepeatEditorMode.monthly => RepeatMode.monthly,
    RepeatEditorMode.fromCompletion => RepeatMode.fromCurrentDate,
  };

  @override
  bool operator ==(Object other) =>
      other is RepeatSetting &&
      other.mode == mode &&
      other.amount == amount &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(mode, amount, unit);

  @override
  String toString() => 'RepeatSetting(${mode.name}, $amount ${unit.name})';
}
