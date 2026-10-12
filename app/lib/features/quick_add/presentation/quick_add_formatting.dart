import 'package:material_ui/material_ui.dart' hide RepeatMode;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// How the task will repeat, as the task screens say it; null when the
/// phrase amounts to no repeat (`every 0 days`).
String? describeQuickAddRepeat(AppLocalizations l10n, QuickAddRepeat repeat) {
  final (:repeatAfter, :mode) = repeat.toTaskRepeat();
  if (mode == RepeatMode.monthly) return l10n.repeatMonthly;
  final hours = repeatAfter.inHours;
  if (hours <= 0) return null;
  if (hours % (24 * 7) == 0) return l10n.repeatEveryWeeks(hours ~/ (24 * 7));
  if (hours % 24 == 0) return l10n.repeatEveryDays(hours ~/ 24);
  return l10n.repeatEveryHours(hours);
}

/// "Tue, Oct 13 9:00 AM" and "in 21 hours" for [due] (UTC) seen at [now].
(String, String) describeQuickAddDue(
  BuildContext context,
  DateTime due, {
  required DateTime now,
}) {
  final materialL10n = MaterialLocalizations.of(context);
  final local = due.toLocal();
  final date = local.year == now.year
      ? materialL10n.formatMediumDate(local)
      : materialL10n.formatShortDate(local);
  final time = materialL10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return ('$date $time', formatRelativeTime(context.l10n, due, now: now));
}
