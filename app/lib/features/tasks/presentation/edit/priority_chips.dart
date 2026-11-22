import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_form_parts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// The web's scale as one row of single-choice chips that scrolls sideways,
/// Unset first, so that a priority can be cleared.
class PriorityChips extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ChipRow(
      children: [
        for (final priority in TaskPriority.values)
          ChoiceChip(
            label: Text(
              priorityLabel(l10n, priority),
              semanticsLabel: l10n.prioritySemantics(
                priorityLabel(l10n, priority),
              ),
            ),
            selected: priority == value,
            onSelected: (_) => onChanged(priority),
          ),
      ],
    );
  }
}
