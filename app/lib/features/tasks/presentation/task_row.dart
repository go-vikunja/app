import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/avatar_stack.dart';
import 'package:vikunja_mobile/features/common/presentation/identifier_text.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_summary.dart';

/// One task in a list, with the web row's content: the done checkbox, the
/// title and one wrapping line of what else the task has (one semantics
/// node that reads it all, with [actions] for screen readers, and opens
/// the detail sheet), the assignees and the favourite star. The controls
/// are indicators only without their callbacks; the checkbox also in a
/// project the user may only read. Full-bleed or in a section card alike.
/// In a table view the line holds the chosen [columns] instead.
class TaskRow extends ConsumerWidget {
  const new({
    required this.task,
    required this.now,
    required this.minimumPriority,
    this.projectTitle,
    this.projectColor,
    this.identifierBeforeTitle = false,
    this.depth = 0,
    this.parentTitle,
    this.columns,
    this.pending = false,
    this.onTap,
    this.onDoneChanged,
    this.onFavoriteChanged,
    this.actions = const {},
    super.key,
  });

  final Task task;
  final DateTime now;

  /// `UserSettings.effectiveMinimumPriority`.
  final int minimumPriority;

  /// For a task from another project than the list's; in a table, for
  /// every task, shown while [columns] has the project.
  final String? projectTitle;
  final Color? projectColor;

  /// The identifier leads the title, as in a project's own list, instead
  /// of standing in the line below. The list decides it for all of its rows
  /// with [identifiersFitBeforeTitle].
  final bool identifierBeforeTitle;

  /// As a subtask: indented under its parent, 4 levels at most.
  final int depth;

  /// The title of the row a subtask is nested under, for screen readers:
  /// the indent alone does not reach them.
  final String? parentTitle;

  /// A table view's columns; null for the list row.
  final Set<TableColumn>? columns;

  /// A change of the task still waits to be sent.
  final bool pending;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onDoneChanged;
  final ValueChanged<bool>? onFavoriteChanged;
  final Map<CustomSemanticsAction, VoidCallback> actions;

  static const _indentPerLevel = 22.0;
  static const _maxIndentedLevels = 4;

  static const double _horizontalPadding = 4 + 4;

  /// The checkbox, the star and the gaps beside the texts.
  static const double _controlsWidth = 48 + 4 + 8 + 48;

  /// Whether the identifiers of [tasks] lead their titles in rows
  /// [rowWidth] wide: while the longest takes a fifth of an unindented row
  /// at most, as a longer one, or one in large text, would squeeze the
  /// title. Decided once for a list, so that all of its rows agree.
  static bool identifiersFitBeforeTitle(
    BuildContext context,
    Iterable<Task> tasks, {
    required double rowWidth,
  }) {
    String? longest;
    for (final task in tasks) {
      final identifier = task.displayIdentifier;
      if (identifier.length > (longest?.length ?? 0)) longest = identifier;
    }
    // Monospaced: the longest is the widest.
    return longest == null ||
        IdentifierText.widthOf(context, longest) <=
            (rowWidth - _horizontalPadding) * 0.2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = TaskSummary.of(
      task,
      now: now,
      minimumPriority: minimumPriority,
      formatter: MomentFormatter.watch(context, ref),
      projectTitle: projectTitle,
      columns: columns,
    );
    final readOnly = ref.watch(
      projectAccessProvider(task.projectId)
          .select((access) => !access.canChangeTasks),
    );
    final identifier = summary.identifier;
    final identifierLeads = identifierBeforeTitle && identifier != null;
    final mutedSmall = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    Widget metaIcon(IconData icon) =>
        Icon(icon, size: 14, color: colors.onSurfaceVariant);

    final titleStyle = task.done
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: colors.onSurfaceVariant,
          )
        : null;
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (summary.taskColor case final color?) ...[
          // One line of the title's height, so the dot sits on its first.
          Text.rich(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: ColorDot(color: color),
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(width: 6),
        ],
        if (identifierLeads) ...[
          IdentifierText(identifier),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(task.title, style: titleStyle)),
      ],
    );

    final project = switch (summary.projectTitle) {
      final project? => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (projectColor case final color?) ...[
            ColorDot(color: color),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text(project, style: mutedSmall)),
        ],
      ),
      null => null,
    };
    final comments = summary.showsCommentCount
        ? CommentCount(count: task.commentCount, unread: task.isUnread)
        : null;
    final identifierBelow = identifier != null && !identifierLeads
        ? IdentifierText(identifier)
        : null;
    final pendingIcon = pending ? metaIcon(Icons.cloud_off_outlined) : null;
    final meta = columns == null
        ? [
            if (summary.showsPriority) PriorityFlag(priority: task.priority),
            if (summary.dueText case final due?)
              DueBadge(text: due, tone: summary.dueTone),
            ?identifierBelow,
            ?project,
            for (final label in summary.labels) LabelPill(label: label),
            if (!summary.checklist.isEmpty)
              _ChecklistCount(statistics: summary.checklist, style: mutedSmall),
            ?comments,
            if (summary.described) metaIcon(Icons.notes),
            if (summary.repeats) metaIcon(Icons.repeat),
            ?pendingIcon,
          ]
        : [
            ?identifierBelow,
            if (summary.showsDoneBadge) const DoneBadge(),
            ?project,
            if (summary.showsPriority)
              TablePriorityLabel(priority: task.priority),
            for (final label in summary.labels) LabelPill(label: label),
            ?comments,
            // The web's column order puts the progress among the dates.
            for (final date in summary.tableDates)
              if (date.column.index < TableColumn.percentDone.index)
                TableDateItem(column: date.column, text: date.text),
            if (summary.showsPercent) PercentDoneItem(percent: summary.percent),
            for (final date in summary.tableDates)
              if (date.column.index > TableColumn.percentDone.index)
                TableDateItem(column: date.column, text: date.text),
            if (summary.createdBy case final user?) CreatedByItem(user: user),
            ?pendingIcon,
          ];
    final avatars = summary.showsAssignees
        ? AvatarStack(users: task.assignees)
        : null;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: onTap != null,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 4 + _indentPerLevel * math.min(depth, _maxIndentedLevels),
            end: 4,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Beside the texts while they keep room for about ten
              // characters, in the line below them otherwise.
              final avatarsBeside =
                  avatars != null &&
                  constraints.maxWidth -
                          _controlsWidth -
                          AvatarStack.widthOf(task.assignees.length) >=
                      MediaQuery.textScalerOf(context).scale(160);
              final details = [...meta, ?(avatarsBeside ? null : avatars)];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskDoneControl(
                    done: task.done,
                    onChanged: readOnly ? null : onDoneChanged,
                    readOnly: readOnly,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: summary.semanticsLabel(
                              l10n,
                              parentTitle: depth > 0 ? parentTitle : null,
                              pending: pending,
                            ),
                            customSemanticsActions: actions.isEmpty
                                ? null
                                : actions,
                            child: ExcludeSemantics(
                              child: DefaultTextStyle.merge(
                                style: theme.textTheme.bodyLarge,
                                child: title,
                              ),
                            ),
                          ),
                          if (details.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: ExcludeSemantics(
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: details,
                                ),
                              ),
                            ),
                          if (columns == null && summary.showsPercent)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ExcludeSemantics(
                                child: TaskProgressBar(
                                  percentDone: task.percentDone,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (avatarsBeside)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 12,
                        start: 8,
                      ),
                      child: avatars,
                    ),
                  FavouriteButton(
                    isFavorite: task.isFavorite,
                    onChanged: readOnly ? null : onFavoriteChanged,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The description's checkboxes, "1/3" after a checkbox icon.
class _ChecklistCount extends StatelessWidget {
  const new({required this.statistics, required this.style});

  final ChecklistStatistics statistics;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        statistics.allDone ? Icons.check_box : Icons.check_box_outlined,
        size: 14,
        color: style?.color,
      ),
      const SizedBox(width: 2),
      Flexible(
        child: Text('${statistics.checked}/${statistics.total}', style: style),
      ),
    ],
  );
}

/// The square done checkbox of a task row; an indicator only without
/// [onChanged], which [readOnly] says.
class TaskDoneControl extends StatelessWidget {
  const new({
    required this.done,
    required this.onChanged,
    this.readOnly = false,
    super.key,
  });

  final bool done;
  final ValueChanged<bool>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onChanged = this.onChanged;
    // One node of its own: a checkbox alone would melt into the row's.
    return MergeSemantics(
      child: Tooltip(
        message: readOnly
            ? l10n.shareTaskReadOnly
            : done
            ? l10n.taskMarkNotDone
            : l10n.taskMarkDone,
        child: Checkbox(
          value: done,
          onChanged: onChanged == null
              ? null
              : (value) => onChanged(value ?? !done),
        ),
      ),
    );
  }
}
