import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

/// The title after the task's colour, which opens the edit page; one
/// node with the heading, its tap and the hint.
class TaskDetailTitle extends StatelessWidget {
  const new({required this.task, required this.onEdit, super.key});

  final Task task;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineSmall;
    final color = parseHexColor(task.hexColor);
    final title = Text(
      task.title,
      style: task.done
          ? style?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : style,
    );
    return MergeSemantics(
      child: Semantics(
        header: true,
        headingLevel: 1,
        button: onEdit != null,
        hint: onEdit == null ? null : l10n.taskEdit,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: switch (color) {
              null => title,
              final color => Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // One line of the title's height, so the dot sits on its
                  // first.
                  ExcludeSemantics(
                    child: Text.rich(
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: ColorDot(color: color),
                      ),
                      style: style,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: title),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Whether the task is open or done, and that it is not synced yet while
/// it is [pending].
class TaskStatusLine extends StatelessWidget {
  const new({required this.done, required this.pending, super.key});

  final bool done;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          done ? l10n.taskDone : l10n.taskDetailStatusOpen,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (pending) const _PendingNote(),
      ],
    );
  }
}

class _PendingNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.l10n.taskNotYetSynced,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The done toggle as a full-width button: filled while the task is open,
/// outlined once it is done.
class TaskDoneButton extends StatelessWidget {
  const new({required this.done, required this.onPressed, super.key});

  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filled = Theme.of(context).filledButtonTheme.style;
    return SizedBox(
      width: double.infinity,
      child: done
          ? OutlinedButton.icon(
              onPressed: onPressed,
              // The filled button's size, so a toggle moves nothing below.
              style: ButtonStyle(
                minimumSize: filled?.minimumSize,
                textStyle: filled?.textStyle,
              ),
              icon: const Icon(Icons.undo),
              label: Text(l10n.taskDetailMarkNotDone),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.check),
              label: Text(l10n.taskDetailMarkDone),
            ),
    );
  }
}
