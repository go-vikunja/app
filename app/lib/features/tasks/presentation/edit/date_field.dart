import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_format.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';

/// One date of the edit page: the row opens the picker, the trailing
/// button clears, the chips below jump to a day and keep the time already
/// set (else the breakpoint time for [now]).
class DateField extends StatelessWidget {
  const new({
    required this.label,
    required this.clearLabel,
    required this.icon,
    required this.value,
    required this.now,
    required this.shortcuts,
    required this.onChanged,
    super.key,
  });

  final String label;

  /// The clear button's tooltip, naming the field.
  final String clearLabel;
  final IconData icon;
  final DateTime? value;
  final DateTime now;
  final List<DateShortcutOption> shortcuts;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await pickDateTime(context, current: value, now: now);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final local = value?.toLocal();
    final selectedDay = local == null
        ? null
        : DateTime(local.year, local.month, local.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(icon, color: colors.onSurfaceVariant),
          title: Text(label),
          subtitle: Text(
            value == null
                ? l10n.taskEditDateNotSet
                : formatMoment(context, value!),
          ),
          trailing: value == null
              ? null
              : IconButton(
                  onPressed: () => onChanged(null),
                  tooltip: clearLabel,
                  icon: const Icon(Icons.clear),
                ),
          onTap: () => unawaited(_pick(context)),
        ),
        DateShortcutChips(
          options: shortcuts,
          selectedDay: selectedDay,
          onSelected: (option) => onChanged(
            option == null
                ? null
                : dayWithTime(option.day, current: value, now: now),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
