import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_text_controller.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_formatting.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// Removes the parts of [kind] from the text; with [items] only the tokens
/// standing for one of them (ignoring case).
typedef MagicPartRemover = void Function(
  MagicSpanKind kind, {
  Iterable<String>? items,
});

/// What one line will create, as chips; each chip's remove button takes its
/// part out of the text.
class QuickAddPreview extends ConsumerWidget {
  const new({
    required this.plan,
    required this.prefixes,
    required this.now,
    required this.onRemove,
    this.projectLabel,
    this.lineCount = 1,
    this.subtaskCount = 0,
    this.dueFromSheet = false,
    super.key,
  });

  final QuickAddPlan plan;
  final QuickAddPrefixes? prefixes;
  final DateTime now;
  final MagicPartRemover onRemove;

  /// How the project chip names [plan]'s project; its display title
  /// without.
  final String? projectLabel;

  /// The number of tasks the text makes; the chips show the first.
  final int lineCount;

  /// How many of them become subtasks, by their indentation.
  final int subtaskCount;

  /// Whether the sheet's own due date dates a line without a date phrase.
  /// The sheet shows that date and its own priority itself, so only the
  /// text's get a chip here.
  final bool dueFromSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chips = plan.magicOnly
        ? const <Widget>[]
        : _chips(
            context,
            MomentFormatter.watch(context, ref),
            offline: ref.watch(offlineProvider) != null,
            guest: ref.watch(activeAccountIsGuestProvider),
          );
    final notes = [
      if (lineCount > 1 && subtaskCount > 0 && chips.isEmpty)
        l10n.newTaskTreeCountOnly(lineCount, subtaskCount)
      else if (lineCount > 1 && subtaskCount > 0)
        l10n.newTaskTreeCount(lineCount, subtaskCount)
      else if (lineCount > 1 && chips.isEmpty)
        l10n.newTaskLineCountOnly(lineCount)
      else if (lineCount > 1)
        l10n.newTaskLineCount(lineCount),
      if (plan.magicOnly) l10n.quickAddMagicOnly(plan.title),
    ];
    if (chips.isEmpty && notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (chips.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 4, children: chips),
        ],
      ),
    );
  }

  List<Widget> _chips(
    BuildContext context,
    MomentFormatter formatter, {
    required bool offline,
    required bool guest,
  }) {
    final l10n = context.l10n;
    final parsed = plan.parsed;
    final assigneePrefix = prefixes?.assignee ?? '';
    bool same(String a, String b) => a.toLowerCase() == b.toLowerCase();

    final projectTitle = projectLabel ?? plan.project?.displayTitle(l10n) ?? '';
    return [
      if (plan.dueDate case final due?
          when plan.dueDateFromText || !dueFromSheet)
        _dueChip(context, due, formatter),
      if (plan.repeat case final repeat?)
        if (describeQuickAddRepeat(l10n, repeat) case final text?)
          _PartChip(
            kind: MagicSpanKind.repeat,
            icon: const Icon(Icons.repeat),
            label: text,
            semanticsLabel: l10n.quickAddRepeatSemantics(text),
            onRemove: () => onRemove(MagicSpanKind.repeat),
          ),
      if (plan.unmatchedProject case final name?)
        _PartChip(
          kind: MagicSpanKind.unmatchedProject,
          icon: const Icon(Icons.warning_amber),
          label: l10n.quickAddProjectNotFound(name),
          warning: true,
          onRemove: () => onRemove(MagicSpanKind.unmatchedProject),
        )
      else if (parsed.project != null && plan.project != null) ...[
        _PartChip(
          kind: MagicSpanKind.project,
          icon: const Icon(Icons.folder_outlined),
          label: projectTitle,
          semanticsLabel: l10n.taskEditProjectSemantics(projectTitle),
          onRemove: () => onRemove(MagicSpanKind.project),
        ),
        if (plan.projectAmbiguous)
          _PartChip(
            kind: MagicSpanKind.unmatchedProject,
            icon: const Icon(Icons.warning_amber),
            label: l10n.quickAddProjectAmbiguous(parsed.project!),
            warning: true,
          ),
      ],
      for (final label in plan.labels)
        _PartChip(
          kind: MagicSpanKind.label,
          icon: _LabelDot(color: parseHexColor(label.hexColor)),
          label: label.title,
          semanticsLabel: l10n.labelSemantics(label.title),
          onRemove: () => onRemove(MagicSpanKind.label, items: [label.title]),
        ),
      for (final title in plan.newLabels)
        _newLabelChip(l10n, title, offline: offline, guest: guest),
      for (final user in plan.assignees)
        _PartChip(
          kind: MagicSpanKind.assignee,
          icon: ExcludeSemantics(
            child: InitialsAvatar(name: user.displayName, radius: 10),
          ),
          label: user.displayName,
          semanticsLabel: l10n.quickAddAssigneeSemantics(user.displayName),
          onRemove: () => onRemove(
            MagicSpanKind.assignee,
            items: [
              for (final name in parsed.assignees)
                if (same(name, user.username) || same(name, user.name)) name,
              user.username,
            ],
          ),
        ),
      for (final name in plan.unresolvedAssignees)
        _PartChip(
          kind: MagicSpanKind.assignee,
          icon: const Icon(Icons.person_search_outlined),
          label: l10n.quickAddLookedUp('$assigneePrefix$name'),
          semanticsLabel: l10n.quickAddLookedUpSemantics(name),
          onRemove: () => onRemove(MagicSpanKind.assignee, items: [name]),
        ),
      if (plan.priority case final priority? when plan.priorityFromText)
        _PartChip(
          kind: MagicSpanKind.priority,
          icon: const Icon(Icons.flag_outlined),
          label: l10n.prioritySemantics(
            priorityLabel(l10n, TaskPriority.fromValue(priority)),
          ),
          onRemove: () => onRemove(MagicSpanKind.priority),
        ),
      for (final reminder in plan.reminders)
        _PartChip(
          kind: MagicSpanKind.date,
          icon: const Icon(Icons.notifications_none),
          label: formatReminder(
            l10n,
            reminder,
            formatAbsolute: formatter.absolute,
          ),
          semanticsLabel: l10n.quickAddReminderSemantics(
            formatReminder(
              l10n,
              reminder,
              formatAbsolute: formatter.spokenAbsolute,
            ),
          ),
        ),
    ];
  }

  Widget _newLabelChip(
    AppLocalizations l10n,
    String title, {
    required bool offline,
    required bool guest,
  }) {
    final (icon, label, semanticsLabel) = guest
        ? (
            Icons.label_off_outlined,
            l10n.quickAddLabelStaysInTitle(title),
            l10n.quickAddLabelStaysInTitleSemantics(title),
          )
        : offline
        ? (
            Icons.cloud_off_outlined,
            l10n.quickAddNewLabelOffline(title),
            l10n.quickAddNewLabelOfflineSemantics(title),
          )
        : (
            Icons.new_label_outlined,
            l10n.quickAddNewLabel(title),
            l10n.quickAddNewLabelSemantics(title),
          );
    return _PartChip(
      kind: MagicSpanKind.label,
      icon: Icon(icon),
      label: label,
      semanticsLabel: semanticsLabel,
      onRemove: () => onRemove(MagicSpanKind.label, items: [title]),
    );
  }

  Widget _dueChip(
    BuildContext context,
    DateTime due,
    MomentFormatter formatter,
  ) {
    final l10n = context.l10n;
    final (date, relative) = describeQuickAddDue(
      context,
      due,
      now: now,
      formatter: formatter,
    );
    return _PartChip(
      kind: MagicSpanKind.date,
      icon: const Icon(Icons.event),
      label: l10n.quickAddDueLabel(date, relative),
      semanticsLabel: l10n.quickAddDueSemantics(
        formatter.semanticsLabel(due) ?? date,
        relative,
      ),
      onRemove: plan.dueDateFromText
          ? () => onRemove(MagicSpanKind.date)
          : null,
    );
  }
}

class _PartChip extends StatelessWidget {
  const new({
    required this.kind,
    required this.icon,
    required this.label,
    this.semanticsLabel,
    this.onRemove,
    this.warning = false,
  });

  final MagicSpanKind kind;
  final Widget icon;
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onRemove;
  final bool warning;

  static const _iconBox = BoxConstraints.tightFor(width: 20, height: 20);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = warning ? colors.onErrorContainer : null;
    return Chip(
      avatar: IconTheme.merge(
        data: IconThemeData(
          color: foreground ?? MagicColors.accentOf(context, kind),
          size: 18,
        ),
        child: icon,
      ),
      // The chip's own text style keeps one line and fades the rest, which
      // cuts off the date's time at large text. A wrapped label needs icon
      // boxes of a fixed size: by default they are squares as tall as the
      // label, which leaves it ever less width.
      avatarBoxConstraints: _iconBox,
      deleteIconBoxConstraints: _iconBox,
      label: Text(
        label,
        semanticsLabel: semanticsLabel,
        softWrap: true,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      labelStyle: foreground == null ? null : TextStyle(color: foreground),
      backgroundColor: warning ? colors.errorContainer : null,
      side: warning ? BorderSide.none : null,
      visualDensity: VisualDensity.compact,
      deleteIcon: const Icon(Icons.close, size: 18),
      deleteIconColor: foreground,
      deleteButtonTooltipMessage: context.l10n.quickAddRemovePart(
        semanticsLabel ?? label,
      ),
      onDeleted: onRemove,
    );
  }
}

class _LabelDot extends StatelessWidget {
  const new({required this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color;
    if (fill == null) return const Icon(Icons.label_outline);
    return Center(
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
