import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/legible_color.dart';

/// The web's colour bubble before a task's title, as light or dark as it
/// needs to stand out from what it is drawn on.
class ColorDot extends StatelessWidget {
  const new({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: legibleIn(context, color),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

/// The description's checklist items: a progress ring and "2 of 5
/// checked", or "All 5 checked" once all are.
class ChecklistSummary extends StatelessWidget {
  const new({required this.statistics, required this.style, super.key});

  final ChecklistStatistics statistics;
  final TextStyle? style;

  static String text(AppLocalizations l10n, ChecklistStatistics statistics) =>
      statistics.allDone
      ? l10n.taskChecklistAllChecked(statistics.total)
      : l10n.taskChecklistChecked(statistics.checked, statistics.total);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The text says the same; a screen reader would read the ring as a
        // progress bar with a bare number.
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              value: statistics.checked / statistics.total,
              strokeWidth: 2,
              backgroundColor: colors.outlineVariant,
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(child: Text(text(context.l10n, statistics), style: style)),
      ],
    );
  }
}
