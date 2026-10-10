import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// The web's scale, unset to do now, as a single choice.
class PriorityChips extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final priority in TaskPriority.values)
          ChoiceChip(
            label: Text(priorityLabel(l10n, priority)),
            selected: priority == value,
            onSelected: (_) => onChanged(priority),
          ),
      ],
    );
  }
}
