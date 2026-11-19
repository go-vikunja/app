import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';

/// The attribute card's rows for the sheet's list, none when the card
/// would be empty: a gap, then the card with the task's dates, priority,
/// progress, repeat, reminders, labels and assignees, and last the
/// [AddAttributeLine] for what is unset and has its callback. The due date,
/// priority and reminder rows are buttons where their callback is set; the
/// label pills open [onOpenLabel].
List<Widget> attributeSection(
  BuildContext context, {
  required Task task,
  required MomentFormatter formatter,
  required DateTime now,
  required ValueChanged<Label> onOpenLabel,
  required VoidCallback? onChangeDueDate,
  required VoidCallback? onChangePriority,
  required VoidCallback? onChangeReminders,
  required VoidCallback? onChangeLabels,
  required VoidCallback? onAddReminder,
}) {
  final l10n = context.l10n;
  final colors = Theme.of(context).colorScheme;
  final repeat = formatRepeat(l10n, task);
  final percent = (task.percentDone * 100).round();
  _Attribute dateAttribute(
    IconData icon,
    String label,
    DateTime moment, {
    String? semanticsText,
    TextStyle? style,
    VoidCallback? onTap,
    String? tapHint,
  }) => _Attribute.text(
    icon: icon,
    label: label,
    text: formatter.absolute(moment),
    semanticsText: semanticsText ?? formatter.semanticsLabel(moment),
    style: style,
    onTap: onTap,
    tapHint: tapHint,
  );
  final dueTone = DueTone.of(task, now: now);
  final attributes = [
    if (task.dueDate case final dueDate?)
      dateAttribute(
        dueTone == DueTone.overdue ? Icons.error_outline : Icons.event_outlined,
        l10n.taskDetailDueDateRow,
        dueDate,
        semanticsText: dueTone == DueTone.overdue
            ? l10n.taskOverdueSemantics(formatter.spokenAbsolute(dueDate))
            : null,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: switch (dueTone) {
            DueTone.overdue => colors.error,
            DueTone.today => colors.primary,
            DueTone.later => colors.onSurface,
            DueTone.done => colors.onSurfaceVariant,
          },
        ),
        onTap: onChangeDueDate,
        tapHint: l10n.taskDetailChangeDueDate,
      ),
    if (task.startDate case final startDate?)
      dateAttribute(
        Icons.play_arrow_outlined,
        l10n.taskDetailStartDate,
        startDate,
      ),
    if (task.endDate case final endDate?)
      dateAttribute(Icons.stop_outlined, l10n.taskDetailEndDate, endDate),
    if (task.priority != TaskPriority.unset)
      _Attribute(
        icon: Icons.flag_outlined,
        label: l10n.taskDetailPriority,
        value: (_) => _PriorityValue(priority: task.priority),
        onTap: onChangePriority,
        tapHint: l10n.taskDetailChangePriority,
      ),
    if (percent > 0)
      _Attribute.text(
        icon: Icons.percent,
        label: l10n.taskDetailProgress,
        text: l10n.taskPercentDone(percent),
      ),
    if (repeat != null)
      _Attribute.text(
        icon: Icons.repeat,
        label: l10n.taskDetailRepeat,
        text: repeat,
      ),
    if (task.reminders.isNotEmpty)
      _Attribute.text(
        icon: Icons.alarm_outlined,
        label: l10n.taskDetailReminders,
        text: [
          for (final reminder in task.reminders)
            formatReminder(l10n, reminder, formatAbsolute: formatter.absolute),
        ].join('\n'),
        semanticsText: [
          for (final reminder in task.reminders)
            formatReminder(
              l10n,
              reminder,
              formatAbsolute: formatter.spokenAbsolute,
            ),
        ].join('\n'),
        onTap: onChangeReminders,
        tapHint: l10n.taskDetailEditReminders,
      ),
    if (task.labels.isNotEmpty)
      _Attribute(
        icon: Icons.label_outline,
        label: l10n.taskDetailLabels,
        merge: false,
        value: (alignment) => Wrap(
          alignment: alignment,
          spacing: 6,
          children: [
            for (final label in rowLabels(task.labels))
              LabelPill(label: label, onTap: () => onOpenLabel(label)),
            // The pills open their labels' tasks (D60).
            if (onChangeLabels != null)
              IconButton(
                onPressed: onChangeLabels,
                tooltip: l10n.taskDetailChangeLabels,
                icon: const Icon(Icons.new_label_outlined),
              ),
          ],
        ),
      ),
    if (task.assignees.isNotEmpty)
      _Attribute(
        icon: Icons.people_outline,
        label: l10n.taskDetailAssignees,
        value: (alignment) => Wrap(
          alignment: alignment,
          spacing: 12,
          runSpacing: 8,
          children: [for (final user in task.assignees) _Assignee(user: user)],
        ),
      ),
  ];
  final addDueDate = task.dueDate == null ? onChangeDueDate : null;
  final addPriority = task.priority == TaskPriority.unset
      ? onChangePriority
      : null;
  final addFirstReminder = task.reminders.isEmpty ? onAddReminder : null;
  final addLabel = task.labels.isEmpty ? onChangeLabels : null;
  final footer =
      addDueDate == null &&
          addPriority == null &&
          addFirstReminder == null &&
          addLabel == null
      ? null
      : AddAttributeLine(
          onDueDate: addDueDate,
          onPriority: addPriority,
          onReminder: addFirstReminder,
          onLabel: addLabel,
        );
  if (attributes.isEmpty && footer == null) return const [];
  return [
    const SizedBox(height: 20),
    _AttributeCard(attributes: attributes, footer: footer),
  ];
}

/// The attribute card, whose rows share one column for their names, as
/// wide as the widest name on one line, so that they line up and go from
/// side by side to stacked together; [footer] is its last row.
class _AttributeCard extends StatelessWidget {
  const new({required this.attributes, this.footer});

  final List<_Attribute> attributes;
  final Widget? footer;

  static const _minLabelWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final style = _Attribute.nameStyle(context);
    final direction = Directionality.of(context);
    double widthOf(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: textScaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // Android 14 and later scale text nonlinearly: the minimum grows as the
    // names' own size does, not as a font size of 96.
    final size = style?.fontSize ?? 14;
    final minWidth = _minLabelWidth * textScaler.scale(size) / size;
    final width = attributes
        .map((attribute) => widthOf(attribute.label))
        .fold(minWidth, math.max)
        .ceilToDouble();
    return _NameColumn(
      width: width,
      child: SectionCard(children: [...attributes, ?footer]),
    );
  }
}

class _NameColumn extends InheritedWidget {
  const new({required this.width, required super.child});

  final double width;

  @override
  bool updateShouldNotify(_NameColumn oldWidget) => width != oldWidget.width;
}

/// One row of the attribute card: an icon, the name in the card's column
/// and the value at the end; the value goes under the name when the two do
/// not fit side by side, as at a large text size. [value] gets the
/// alignment of the side it is on. With [onTap] the whole row is a button,
/// whose tap [tapHint] names.
class _Attribute extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.value,
    this.merge = true,
    this.onTap,
    this.tapHint,
  });

  factory text({
    required IconData icon,
    required String label,
    required String text,
    String? semanticsText,
    TextStyle? style,
    VoidCallback? onTap,
    String? tapHint,
  }) => _Attribute(
    icon: icon,
    label: label,
    onTap: onTap,
    tapHint: tapHint,
    value: (alignment) => Text(
      text,
      semanticsLabel: semanticsText,
      style: style,
      textAlign: alignment == WrapAlignment.end
          ? TextAlign.end
          : TextAlign.start,
    ),
  );

  final IconData icon;
  final String label;
  final Widget Function(WrapAlignment alignment) value;

  /// False when [value] holds buttons, each of which a screen reader must
  /// reach on its own.
  final bool merge;

  final VoidCallback? onTap;
  final String? tapHint;

  static const _minValueWidth = 120.0;

  /// Bold under the platform's bold text setting, as [Text] draws it, so
  /// that the card measures what is drawn.
  static TextStyle? nameStyle(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return MediaQuery.boldTextOf(context)
        ? style?.merge(const TextStyle(fontWeight: FontWeight.bold))
        : style;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelWidth = context
        .dependOnInheritedWidgetOfExactType<_NameColumn>()!
        .width;
    final name = Text(label, style: nameStyle(context));
    final glyph = Icon(icon, size: 20, color: colors.onSurfaceVariant);
    final padded = DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide =
                  constraints.maxWidth - 20 - 16 - labelWidth - 16 >=
                  _minValueWidth;
              if (!sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: glyph,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [name, value(WrapAlignment.start)],
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  glyph,
                  const SizedBox(width: 16),
                  // At least the column: a name a fraction wider than
                  // measured takes from the value instead of wrapping.
                  ConstrainedBox(
                    constraints: BoxConstraints(minWidth: labelWidth),
                    child: name,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: value(WrapAlignment.end),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final onTap = this.onTap;
    final row = onTap == null
        ? padded
        : Semantics(
            button: true,
            onTapHint: tapHint,
            child: InkWell(onTap: onTap, child: padded),
          );
    return merge ? MergeSemantics(child: row) : row;
  }
}

/// The priority with its flag: in the error colour from urgent up, amber
/// for high, muted below.
class _PriorityValue extends StatelessWidget {
  const new({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (priority.value) {
      >= 4 => (Icons.flag, colors.error),
      3 => (Icons.flag, HighlightColors.of(context).highlight),
      _ => (Icons.outlined_flag, colors.onSurfaceVariant),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            priorityLabel(context.l10n, priority),
            style: priority.value >= 4 ? TextStyle(color: colors.error) : null,
          ),
        ),
      ],
    );
  }
}

class _Assignee extends StatelessWidget {
  const new({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      UserAvatar(user: user, radius: 12),
      const SizedBox(width: 6),
      Flexible(child: Text(user.displayName)),
    ],
  );
}
