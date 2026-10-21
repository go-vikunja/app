import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// A priority as a flag and its name: urgent and up in the error colour,
/// high with an amber flag, lower ones muted.
class PriorityFlag extends StatelessWidget {
  const new({required this.priority, super.key});

  final TaskPriority priority;

  /// In the detail sheet: high, urgent and do-now.
  static bool showsInDetail(TaskPriority priority) =>
      priority.value >= TaskPriority.high.value;

  /// In a list row, like the web's: an open task at or above the user's
  /// minimum priority.
  static bool showsOnRow(Task task, {required int minimumPriority}) =>
      !task.done &&
      task.priority != TaskPriority.unset &&
      task.priority.value >= minimumPriority;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (
      IconData icon,
      Color iconColor,
      Color textColor,
    ) = switch (priority.value) {
      >= 4 => (Icons.flag, colors.error, colors.error),
      3 => (Icons.flag, HighlightColors.of(context).highlight, colors.tertiary),
      _ => (
        Icons.outlined_flag,
        colors.onSurfaceVariant,
        colors.onSurfaceVariant,
      ),
    };
    final text = priorityLabel(l10n, priority);
    return _MetaItem(
      icon: icon,
      iconColor: iconColor,
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(color: textColor),
        semanticsLabel: l10n.prioritySemantics(text),
      ),
    );
  }
}

enum DueTone {
  overdue,
  today,
  later,
  done;

  static DueTone of(Task task, {required DateTime now}) {
    final due = task.dueDate;
    if (task.done || due == null) return done;
    if (task.isOverdue(now)) return overdue;
    final local = due.toLocal();
    final today = now.toLocal();
    return local.year == today.year &&
            local.month == today.month &&
            local.day == today.day
        ? DueTone.today
        : later;
  }
}

/// A due date with a calendar icon: in the error colour when overdue,
/// the primary colour when due later today, muted otherwise.
class DueBadge extends StatelessWidget {
  const new({
    required this.text,
    required this.tone,
    this.semanticsLabel,
    super.key,
  });

  final String text;
  final DueTone tone;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = switch (tone) {
      DueTone.overdue => colors.error,
      DueTone.today => colors.primary,
      DueTone.later || DueTone.done => colors.onSurfaceVariant,
    };
    return _MetaItem(
      icon: Icons.calendar_today_outlined,
      iconColor: color,
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(color: color),
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

/// A task's comment count, in the primary colour with a dot on the icon
/// while a comment by someone else is unread, as on the web.
class CommentCount extends StatelessWidget {
  const new({required this.count, required this.unread, super.key});

  final int count;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = unread ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      label: unread
          ? l10n.taskCommentCountUnread(count)
          : l10n.taskCommentCount(count),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 14,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.chat_bubble_outline, size: 14, color: color),
                if (unread)
                  PositionedDirectional(
                    top: -2,
                    end: -3,
                    child: Container(
                      key: const ValueKey('unread-dot'),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Material.maybeOf(context)?.color ??
                              colors.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: unread ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label as a small pill in its colour from the server, with black or
/// white text as on the web, which keeps at least 4.5:1; without a
/// colour in the secondary container colour.
class LabelPill extends StatelessWidget {
  const new({required this.label, super.key});

  final Label label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = parseHexColor(label.hexColor);
    final (fill, foreground) = background == null
        ? (colors.secondaryContainer, colors.onSecondaryContainer)
        : (background, contrastingTextColor(background));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          label.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          semanticsLabel: context.l10n.labelSemantics(label.title),
        ),
      ),
    );
  }
}

/// An item of a task's meta line: a 14 dp icon before its text.
class _MetaItem extends StatelessWidget {
  const new({required this.icon, required this.iconColor, required this.child});

  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(child: Icon(icon, size: 14, color: iconColor)),
      const SizedBox(width: 4),
      Flexible(child: child),
    ],
  );
}
