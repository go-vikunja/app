import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/reminder_editing.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// One row per reminder: tap edits, the trailing button removes. A
/// relative reminder also shows when it fires with the draft's [dates], or
/// that its date is missing; reminders that would fire together are
/// flagged, because the server keeps only one of them.
class RemindersSection extends StatelessWidget {
  const new({
    required this.reminders,
    required this.dates,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
    super.key,
  });

  final List<TaskReminder> reminders;
  final ReminderDates dates;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, reminder) in reminders.indexed)
          _ReminderRow(
            reminder: reminder,
            dates: dates,
            onTap: () => onEdit(index),
            onRemove: () => onRemove(index),
          ),
        if (remindersCoincide(reminders, dates))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _Warning(l10n.taskEditRemindersCoincide),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ActionChip(
            avatar: Icon(Icons.add_alarm, color: colors.onSurfaceVariant),
            label: Text(l10n.taskEditAddReminder),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const new({
    required this.reminder,
    required this.dates,
    required this.onTap,
    required this.onRemove,
  });

  final TaskReminder reminder;
  final ReminderDates dates;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final text = formatReminder(
      l10n,
      reminder,
      formatAbsolute: formatter.absolute,
    );
    final spoken = formatReminder(
      l10n,
      reminder,
      formatAbsolute: formatter.spokenAbsolute,
    );
    final relativeTo = reminder.relativeTo;
    final instant = reminderInstant(reminder, dates);
    final secondary = switch ((relativeTo, instant)) {
      (null, _) => null,
      (_, final instant?) => Text(
        formatter.absolute(instant),
        semanticsLabel: formatter.semanticsLabel(instant),
      ),
      (final relativeTo?, null) => _Warning(switch (relativeTo) {
        ReminderRelativeTo.dueDate => l10n.reminderDueDateNotSet,
        ReminderRelativeTo.startDate => l10n.reminderStartDateNotSet,
        ReminderRelativeTo.endDate => l10n.reminderEndDateNotSet,
      }),
    };
    return Semantics(
      onTapHint: l10n.taskEditEditReminder,
      child: ListTile(
        leading: Icon(Icons.alarm, color: colors.onSurfaceVariant),
        title: Text(text, semanticsLabel: spoken),
        subtitle: secondary,
        trailing: IconButton(
          onPressed: onRemove,
          tooltip: l10n.taskEditRemoveReminder(spoken),
          icon: const Icon(Icons.close),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.warning_amber, size: 18, color: colors.error),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: TextStyle(color: colors.error)),
        ),
      ],
    );
  }
}
