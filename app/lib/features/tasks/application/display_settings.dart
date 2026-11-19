import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';

part 'display_settings.g.dart';

/// The user's web settings for showing and picking dates and times; null
/// fields were never set, so the app's own formats and times apply.
@immutable
final class DisplaySettings {
  const new({
    this.dateDisplay,
    this.timeFormat,
    this.weekStart = 0,
    this.defaultDueTime,
  });

  factory from(UserSettings settings) => DisplaySettings(
    dateDisplay: settings.dateDisplay,
    timeFormat: settings.timeFormat,
    weekStart: settings.weekStart,
    defaultDueTime: settings.defaultDueTime,
  );

  final DateDisplay? dateDisplay;
  final TimeFormat? timeFormat;

  /// 0 = Sunday … 6 = Saturday.
  final int weekStart;

  /// The time a date picked without one takes; null for the breakpoint.
  final ClockTime? defaultDueTime;

  /// The first column of a calendar grid, as `MaterialLocalizations`
  /// counts it; null for the device locale's. The server's default 0 cannot
  /// be told from a Sunday the user picked, so only 1–6 count.
  int? get firstDayOfWeekIndex =>
      weekStart >= 1 && weekStart <= 6 ? weekStart : null;

  /// Null for the device's choice.
  bool? get use24HourFormat => switch (timeFormat) {
    TimeFormat.twentyFourHour => true,
    TimeFormat.twelveHour => false,
    null => null,
  };

  @override
  bool operator ==(Object other) =>
      other is DisplaySettings &&
      other.dateDisplay == dateDisplay &&
      other.timeFormat == timeFormat &&
      other.weekStart == weekStart &&
      other.defaultDueTime == defaultDueTime;

  @override
  int get hashCode =>
      Object.hash(dateDisplay, timeFormat, weekStart, defaultDueTime);
}

@riverpod
DisplaySettings displaySettings(Ref ref) => ref.watch(
  userSettingsProvider.select(
    (settings) => switch (settings.value) {
      final value? => DisplaySettings.from(value),
      null => const DisplaySettings(),
    },
  ),
);
