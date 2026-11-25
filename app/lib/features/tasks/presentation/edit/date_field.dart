import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_form_parts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';

// The checkmark goes in the avatar's fixed box; without an avatar it takes
// a square as tall as the label, which grows with the text size.
const _chipIconBox = BoxConstraints.tightFor(width: 20, height: 20);

/// One date of the edit page laid out as the New task sheet lays out its
/// due date: a heading, then one row of the [shortcuts], a chip for a date
/// on none of them, whose delete button clears it, and "Pick date…", the
/// last two named with the field for screen readers, as the shortcuts are. A
/// shortcut jumps to its day and keeps the time already set (else the
/// user's default due time, else the breakpoint time); tapping the chosen
/// one again clears. Both are dated at the tap, as the [shortcuts] can be a
/// minute old, from before midnight or before a default time passed.
class DateField extends ConsumerWidget {
  const new({
    required this.label,
    required this.clearLabel,
    required this.icon,
    required this.value,
    required this.shortcuts,
    required this.onChanged,
    super.key,
  });

  final String label;

  /// The tooltip of the delete button of a date on no shortcut, naming the
  /// field.
  final String clearLabel;
  final IconData icon;
  final DateTime? value;
  final List<DateShortcutOption> shortcuts;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await pickDateTime(
      context,
      current: value,
      now: ref.read(clockProvider)(),
      display: ref.read(displaySettingsProvider),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final formatter = MomentFormatter.watch(context, ref);
    final defaultTime = ref.watch(
      displaySettingsProvider.select((display) => display.defaultDueTime),
    );
    final value = this.value;
    final local = value?.toLocal();
    final selectedDay = local == null
        ? null
        : DateTime(local.year, local.month, local.day);
    final onShortcut = shortcuts.any((option) => option.day == selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskFormHeading(icon: icon, text: label, top: 10, bottom: 0),
        DateShortcutChips(
          options: shortcuts,
          selectedDay: selectedDay,
          selectedTime: value == null ? null : formatter.timeOfDay(value),
          fieldLabel: label,
          onSelected: (option) {
            if (option == null) {
              onChanged(null);
              return;
            }
            final now = ref.read(clockProvider)();
            final day = buildDateShortcuts(now)
                .firstWhere(
                  (current) => current.shortcut == option.shortcut,
                  orElse: () => option,
                )
                .day;
            onChanged(
              dayWithTime(
                day,
                current: value,
                now: now,
                defaultTime: defaultTime,
              ),
            );
          },
          trailing: [
            if (value != null && !onShortcut)
              InputChip(
                avatar: const SizedBox.shrink(),
                avatarBoxConstraints: _chipIconBox,
                deleteIconBoxConstraints: _chipIconBox,
                label: Text(
                  formatter.absolute(value),
                  semanticsLabel: l10n.dateFieldChipSemantics(
                    label,
                    formatter.spokenAbsolute(value),
                  ),
                ),
                selected: true,
                onDeleted: () => onChanged(null),
                deleteButtonTooltipMessage: clearLabel,
              ),
            ActionChip(
              avatar: Icon(
                Icons.calendar_month_outlined,
                color: colors.onSurfaceVariant,
              ),
              label: Text(
                l10n.newTaskPickDate,
                semanticsLabel: l10n.dateFieldChipSemantics(
                  label,
                  l10n.newTaskPickDate,
                ),
              ),
              onPressed: () => unawaited(_pick(context, ref)),
            ),
          ],
        ),
      ],
    );
  }
}
