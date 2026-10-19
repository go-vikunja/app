import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// Instants as the user set dates and times up on the web (`date_display`,
/// `time_format`), in device local time; what they never set keeps the
/// app's own formats: relative where the app says how far away a moment
/// is, the device's short date and 12/24-hour clock where it shows the
/// moment itself.
final class MomentFormatter {
  new({
    required this.l10n,
    required this.material,
    required this.settings,
    required this.alwaysUse24HourFormat,
  });

  factory of(BuildContext context, DisplaySettings settings) => MomentFormatter(
    l10n: context.l10n,
    material: MaterialLocalizations.of(context),
    settings: settings,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );

  factory watch(BuildContext context, WidgetRef ref) =>
      MomentFormatter.of(context, ref.watch(displaySettingsProvider));

  final AppLocalizations l10n;
  final MaterialLocalizations material;
  final DisplaySettings settings;

  /// The device's 24-hour switch; off means the locale's clock.
  final bool alwaysUse24HourFormat;

  bool get uses24HourFormat =>
      settings.use24HourFormat ??
      hourFormat(
            of: material.timeOfDayFormat(
              alwaysUse24HourFormat: alwaysUse24HourFormat,
            ),
          ) !=
          HourFormat.h;

  /// Where the app says how far away [moment] is: task rows, the metadata
  /// line, comments and the inbox.
  String relative(DateTime moment, {required DateTime now}) {
    if (chosenAbsolute(moment) case final text?) return text;
    if (settings.dateDisplay == DateDisplay.relative &&
        moment.difference(now).abs() < const Duration(minutes: 1)) {
      return l10n.relativeJustNow;
    }
    return formatRelativeTime(l10n, moment, now: now);
  }

  /// Where the app shows [moment] itself: the detail sheet's dates and
  /// reminders, the edit page and the new-task sheet.
  String absolute(DateTime moment) =>
      chosenAbsolute(moment) ??
      '${material.formatShortDate(moment.toLocal())} ${timeOfDay(moment)}';

  /// For screen readers once the user picked a date display: the long date
  /// with the weekday, as the web's tooltips show every date. Null before,
  /// where each place keeps what it read out so far.
  String? semanticsLabel(DateTime moment) => settings.dateDisplay == null
      ? null
      : _written(moment, intl.DateFormat.yMMMMEEEEd(l10n.localeName));

  /// [absolute] as screen readers hear it.
  String spokenAbsolute(DateTime moment) =>
      semanticsLabel(moment) ?? absolute(moment);

  String timeOfDay(DateTime moment) {
    final local = moment.toLocal();
    if (settings.timeFormat == null) {
      return material.formatTimeOfDay(
        TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: alwaysUse24HourFormat,
      );
    }
    return _time(local, padded: false);
  }

  /// [moment] in the absolute format the user picked on the web; null
  /// while they have none.
  String? chosenAbsolute(DateTime moment) {
    final locale = l10n.localeName;
    final local = moment.toLocal();
    String numeric(String date) =>
        '${intl.DateFormat(date, locale).format(local)} '
        '${_time(local, padded: true)}';
    return switch (settings.dateDisplay) {
      null || DateDisplay.relative => null,
      DateDisplay.monthDayYearDashed => numeric('MM-dd-yyyy'),
      DateDisplay.dayMonthYearDashed => numeric('dd-MM-yyyy'),
      DateDisplay.yearMonthDayDashed => numeric('yyyy-MM-dd'),
      DateDisplay.monthDayYearSlashed => numeric('MM/dd/yyyy'),
      DateDisplay.dayMonthYearSlashed => numeric('dd/MM/yyyy'),
      DateDisplay.yearMonthDaySlashed => numeric('yyyy/MM/dd'),
      DateDisplay.dayMonthYear => _written(
        moment,
        intl.DateFormat.yMMMMd(locale),
      ),
      DateDisplay.weekdayDayMonthYear => _written(
        moment,
        intl.DateFormat.yMMMMEEEEd(locale),
      ),
    };
  }

  String _written(DateTime moment, intl.DateFormat date) {
    final local = moment.toLocal();
    return l10n.momentDateAtTime(
      date.format(local),
      _time(local, padded: false),
    );
  }

  /// The web's clocks: `HH:mm`, and in 12 hours `hh:mm A` after a numeric
  /// date but `h:mm a` after a written one; AM/PM in German too.
  String _time(DateTime local, {required bool padded}) {
    final pattern = uses24HourFormat
        ? 'HH:mm'
        : padded
        ? 'hh:mm a'
        : 'h:mm a';
    return intl.DateFormat(pattern, l10n.localeName).format(local);
  }
}
