import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';

/// The app's texts for widgets, without a widget tree: what a headless
/// isolate can load. [alwaysUse24HourFormat] is the device's switch as the
/// app last saw it, since an engine without a view does not know it.
final class WidgetTexts {
  new({
    required this.l10n,
    required this.material,
    required this.alwaysUse24HourFormat,
  });

  /// [material] needs the locale's date data, which its delegate loads.
  static Future<WidgetTexts> load(
    AppLocalizations l10n, {
    required bool alwaysUse24HourFormat,
  }) async => WidgetTexts(
    l10n: l10n,
    material: await GlobalMaterialLocalizations.delegate.load(
      Locale(l10n.localeName.split('_').first),
    ),
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );

  final AppLocalizations l10n;
  final MaterialLocalizations material;
  final bool alwaysUse24HourFormat;

  MomentFormatter formatter(DisplaySettings settings) => MomentFormatter(
    l10n: l10n,
    material: material,
    settings: settings,
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );

  /// The absolute format the user picked on the web, else a label that
  /// only changes at midnight: today, tomorrow and yesterday with the
  /// time, a weekday within the week ahead, else the date.
  String dueLabel(
    DateTime due, {
    required DateTime now,
    required MomentFormatter formatter,
  }) {
    if (formatter.chosenAbsolute(due) case final chosen?) return chosen;
    final local = due.toLocal();
    final today = now.toLocal();
    String at(String day) => l10n.widgetDueAt(day, formatter.timeOfDay(due));
    return switch (calendarDaysBetween(today, local)) {
      0 => at(l10n.sectionToday),
      1 => at(l10n.sectionTomorrow),
      -1 => at(l10n.inboxYesterday),
      > 1 && < 7 => at(intl.DateFormat.E(l10n.localeName).format(local)),
      _ when local.year == today.year => material.formatShortMonthDay(local),
      _ => material.formatShortDate(local),
    };
  }

  WidgetDueTone tone(Task task, DateTime now) =>
      switch (DueTone.of(task, now: now)) {
        DueTone.overdue => WidgetDueTone.overdue,
        DueTone.today => WidgetDueTone.today,
        DueTone.later => WidgetDueTone.later,
        DueTone.done => WidgetDueTone.none,
      };

  String priority(TaskPriority priority) => priorityLabel(l10n, priority);
}

/// Whole local calendar days from [from] to [to], unaffected by a
/// daylight-saving change in between.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// The local midnight that starts the day after [now].
DateTime nextLocalMidnight(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}
