import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';

/// The web's colour bubble before a task's title or a project's name.
class ColorDot extends StatelessWidget {
  const new({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}

/// The description's checkboxes: a progress ring and "2 of 5 tasks", or
/// "5 tasks" once all are checked.
class ChecklistSummary extends StatelessWidget {
  const new({required this.statistics, required this.style, super.key});

  final ChecklistStatistics statistics;
  final TextStyle? style;

  static String text(AppLocalizations l10n, ChecklistStatistics statistics) =>
      statistics.allDone
      ? l10n.taskChecklistAllDone(statistics.total)
      : l10n.taskChecklistProgress(statistics.checked, statistics.total);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            value: statistics.checked / statistics.total,
            strokeWidth: 2,
            backgroundColor: colors.outlineVariant,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(child: Text(text(context.l10n, statistics), style: style)),
      ],
    );
  }
}

/// Up to [max] assignee avatars, overlapping, then "+N" for the rest.
class AssigneeAvatars extends StatelessWidget {
  const new({required this.users, this.max = 3, super.key});

  final List<User> users;
  final int max;

  static const _radius = 12.0;
  static const _overlap = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shown = users.take(max).toList();
    final more = users.length - shown.length;
    const diameter = _radius * 2;
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: diameter + (shown.length - 1) * (diameter - _overlap),
          height: diameter,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                PositionedDirectional(
                  start: i * (diameter - _overlap),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface),
                    ),
                    child: UserAvatar(user: shown[i], radius: _radius),
                  ),
                ),
            ],
          ),
        ),
        if (more > 0)
          Text(
            context.l10n.taskMoreAssignees(more),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
