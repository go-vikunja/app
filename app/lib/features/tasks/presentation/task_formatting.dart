import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

String priorityLabel(AppLocalizations l10n, TaskPriority priority) =>
    switch (priority) {
      TaskPriority.unset => l10n.priorityUnset,
      TaskPriority.low => l10n.priorityLow,
      TaskPriority.medium => l10n.priorityMedium,
      TaskPriority.high => l10n.priorityHigh,
      TaskPriority.urgent => l10n.priorityUrgent,
      TaskPriority.doNow => l10n.priorityDoNow,
    };

enum _PeriodUnit { weeks, days, hours, minutes, seconds }

/// The web's `secondsToPeriod`: the largest unit that divides evenly.
(_PeriodUnit, int) _wholeUnits(Duration period) {
  final seconds = period.abs().inSeconds;
  const week = Duration.secondsPerDay * 7;
  if (seconds > 0 && seconds % week == 0) {
    return (_PeriodUnit.weeks, seconds ~/ week);
  }
  if (seconds > 0 && seconds % Duration.secondsPerDay == 0) {
    return (_PeriodUnit.days, seconds ~/ Duration.secondsPerDay);
  }
  if (seconds > 0 && seconds % Duration.secondsPerHour == 0) {
    return (_PeriodUnit.hours, seconds ~/ Duration.secondsPerHour);
  }
  if (seconds > 0 && seconds % Duration.secondsPerMinute == 0) {
    return (_PeriodUnit.minutes, seconds ~/ Duration.secondsPerMinute);
  }
  return (_PeriodUnit.seconds, seconds);
}

String formatPeriod(AppLocalizations l10n, Duration period) =>
    switch (_wholeUnits(period)) {
      (_PeriodUnit.weeks, final count) => l10n.periodWeeks(count),
      (_PeriodUnit.days, final count) => l10n.periodDays(count),
      (_PeriodUnit.hours, final count) => l10n.periodHours(count),
      (_PeriodUnit.minutes, final count) => l10n.periodMinutes(count),
      (_PeriodUnit.seconds, final count) => l10n.periodSeconds(count),
    };

/// "Every day", "Every 2 weeks": one phrase per unit, so that German can
/// decline it.
String _formatRepeatInterval(AppLocalizations l10n, Duration period) =>
    switch (_wholeUnits(period)) {
      (_PeriodUnit.weeks, final count) => l10n.repeatEveryWeeks(count),
      (_PeriodUnit.days, final count) => l10n.repeatEveryDays(count),
      (_PeriodUnit.hours, final count) => l10n.repeatEveryHours(count),
      (_PeriodUnit.minutes, final count) => l10n.repeatEveryMinutes(count),
      (_PeriodUnit.seconds, final count) => l10n.repeatEverySeconds(count),
    };

/// Null when the task does not repeat.
String? formatRepeat(AppLocalizations l10n, Task task) {
  if (!task.repeats) return null;
  return switch (task.repeatMode) {
    RepeatMode.monthly => l10n.repeatMonthly,
    RepeatMode.afterAmount => _formatRepeatInterval(l10n, task.repeatAfter),
    RepeatMode.fromCurrentDate => l10n.repeatFromCompletion(
      _formatRepeatInterval(l10n, task.repeatAfter),
    ),
  };
}

/// [formatAbsolute] renders the instant of an absolute reminder.
String formatReminder(
  AppLocalizations l10n,
  TaskReminder reminder, {
  required String Function(DateTime moment) formatAbsolute,
}) {
  final relativeTo = reminder.relativeTo;
  if (relativeTo == null) {
    final moment = reminder.reminder;
    return moment == null ? l10n.relativeNow : formatAbsolute(moment);
  }
  final reference = switch (relativeTo) {
    ReminderRelativeTo.dueDate => l10n.reminderReferenceDueDate,
    ReminderRelativeTo.startDate => l10n.reminderReferenceStartDate,
    ReminderRelativeTo.endDate => l10n.reminderReferenceEndDate,
  };
  final period = reminder.relativePeriod;
  if (period == Duration.zero) return l10n.reminderAtReference(reference);
  final amount = formatPeriod(l10n, period);
  return period.isNegative
      ? l10n.reminderBefore(amount, reference)
      : l10n.reminderAfter(amount, reference);
}
