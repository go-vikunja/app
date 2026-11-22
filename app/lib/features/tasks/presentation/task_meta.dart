import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/app/theme/legible_color.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// The size of a meta line's icons: 14 dp, growing with the text up to
/// twice that, so that the overdue mark stays legible at large text sizes.
double metaIconSize(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14).clamp(14, 28);

/// The colour of urgent and up, an orange set apart from the error red,
/// which marks what is overdue; with [text] for a priority's name, which
/// needs more contrast than its flag.
Color urgentPriorityColor(BuildContext context, {bool text = false}) {
  // The high-contrast schemes give their text roles 7:1.
  final high = MediaQuery.highContrastOf(context);
  return legibleIn(
    context,
    _urgentOrange,
    minContrast: switch ((text, high)) {
      (true, true) => 7,
      (true, false) || (false, true) => 4.5,
      (false, false) => 3,
    },
  );
}

const _urgentOrange = Color(0xFFEF6C00);

/// A priority as a flag and its name: urgent and up with a flag in
/// [urgentPriorityColor], high with an amber flag, lower ones muted.
class PriorityFlag extends StatelessWidget {
  const new({required this.priority, super.key});

  final TaskPriority priority;

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
      >= 4 => (
        Icons.flag,
        urgentPriorityColor(context),
        urgentPriorityColor(context, text: true),
      ),
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

/// The Table view's priority: every value, Unset and a done task's
/// included, drawn as [PriorityFlag] draws it everywhere else.
class TablePriorityLabel extends StatelessWidget {
  const new({required this.priority, super.key});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) => PriorityFlag(priority: priority);
}

/// A table column's icon in the columns sheet; a row's dates lead with
/// theirs.
IconData tableColumnIcon(TableColumn column) => switch (column) {
  TableColumn.done => Icons.check_circle_outline,
  TableColumn.project => Icons.folder_outlined,
  TableColumn.title => Icons.title,
  TableColumn.priority => Icons.flag_outlined,
  TableColumn.labels => Icons.label_outline,
  TableColumn.assignees => Icons.people_outline,
  TableColumn.commentCount => Icons.chat_bubble_outline,
  TableColumn.dueDate => Icons.calendar_today_outlined,
  TableColumn.startDate => Icons.play_arrow_outlined,
  TableColumn.endDate => Icons.stop_outlined,
  TableColumn.percentDone => Icons.donut_large,
  TableColumn.doneAt => Icons.task_alt,
  TableColumn.created => Icons.add_circle_outline,
  TableColumn.updated => Icons.update,
  TableColumn.createdBy => Icons.person_outline,
};

/// One of a table row's dates after the icon of its column, muted like
/// the web table's cells, an overdue due date too.
class TableDateItem extends StatelessWidget {
  const new({required this.column, required this.text, super.key});

  final TableColumn column;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return _MetaItem(
      icon: tableColumnIcon(column),
      iconColor: color,
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

/// A task's percent done as a ring and the whole percent, for a table
/// row.
class PercentDoneItem extends StatelessWidget {
  const new({required this.percent, super.key});

  /// 0 to 100.
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            value: percent.clamp(0, 100) / 100,
            strokeWidth: 2,
            backgroundColor: colors.outlineVariant,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.l10n.projectTableCellPercent(percent),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Who created a task: a small avatar and the name, for a table row.
class CreatedByItem extends StatelessWidget {
  const new({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(user: user, radius: 8),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Done" in a small pill, for a done task where a card or a table row
/// says so.
class DoneBadge extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          context.l10n.taskDoneSemantics,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onPrimaryContainer,
          ),
        ),
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

/// A due date with a calendar icon: in the primary colour when due later
/// today, muted otherwise; an overdue one in the error colour and with its
/// own icon, so that the colour is not its only sign.
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
      // The home-screen widgets mark an overdue row the same way.
      icon: tone == DueTone.overdue
          ? Icons.error_outline
          : Icons.calendar_today_outlined,
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
    final iconSize = metaIconSize(context);
    return Semantics(
      label: unread
          ? l10n.taskCommentCountUnread(count)
          : l10n.taskCommentCount(count),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: iconSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.chat_bubble_outline, size: iconSize, color: color),
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
/// colour in the secondary container colour. With [onTap] it is a button
/// that shows the label's tasks, with a tap target of the minimum height.
class LabelPill extends StatelessWidget {
  const new({required this.label, this.onTap, super.key});

  final Label label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = parseHexColor(label.hexColor);
    final (fill, foreground) = background == null
        ? (colors.secondaryContainer, colors.onSecondaryContainer)
        : (background, contrastingTextColor(background));
    final pill = DecoratedBox(
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
    final onTap = this.onTap;
    if (onTap == null) return pill;
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.labelsShowTasks(label.title),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Align(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}

/// An item of a task's meta line: an icon of [metaIconSize] before its
/// text.
class _MetaItem extends StatelessWidget {
  const new({required this.icon, required this.iconColor, required this.child});

  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Icon(icon, size: metaIconSize(context), color: iconColor),
      ),
      const SizedBox(width: 4),
      Flexible(child: child),
    ],
  );
}
