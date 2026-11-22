import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_form_parts.dart';

String shortcutLabel(AppLocalizations l10n, DateShortcut shortcut) =>
    switch (shortcut) {
      DateShortcut.today => l10n.shortcutToday,
      DateShortcut.tomorrow => l10n.shortcutTomorrow,
      DateShortcut.nextMonday => l10n.shortcutNextMonday,
      DateShortcut.thisWeekend => l10n.shortcutThisWeekend,
      DateShortcut.laterThisWeek => l10n.shortcutLaterThisWeek,
      DateShortcut.nextWeek => l10n.shortcutNextWeek,
      DateShortcut.nextWeekend => l10n.shortcutNextWeekend,
      DateShortcut.endOfMonth => l10n.shortcutEndOfMonth,
      DateShortcut.inAMonth => l10n.shortcutInAMonth,
    };

/// Date shortcut toggles: the chip whose day the current value falls on is
/// selected, and tapping it again clears ([onSelected] gets null). Each
/// chip reads out its day, after [fieldLabel] where several dates have
/// chips; the others show their day too ("Next week · Sat, Nov 28"), and
/// the selected one shows [selectedTime] instead. One row scrolling
/// sideways, followed by [trailing]. Without [enabled] they only show the
/// value.
class DateShortcutChips extends StatelessWidget {
  const new({
    required this.options,
    required this.selectedDay,
    required this.onSelected,
    this.trailing = const [],
    this.enabled = true,
    this.selectedTime,
    this.fieldLabel,
    super.key,
  });

  final List<DateShortcutOption> options;

  /// The start of the current value's local day, if any.
  final DateTime? selectedDay;
  final ValueChanged<DateShortcutOption?> onSelected;
  final List<Widget> trailing;
  final bool enabled;
  final String? selectedTime;
  final String? fieldLabel;

  @override
  Widget build(BuildContext context) => ChipRow(
    children: [
      for (final option in options) _chip(context, option),
      ...trailing,
    ],
  );

  Widget _chip(BuildContext context, DateShortcutOption option) {
    final l10n = context.l10n;
    final selected = option.day == selectedDay;
    final shortcut = shortcutLabel(l10n, option.shortcut);
    final day = MaterialLocalizations.of(context).formatMediumDate(option.day);
    final spoken = switch (selectedTime) {
      final time? when selected => l10n.shortcutAtTime(shortcut, time),
      _ => shortcut,
    };
    return ChoiceChip(
      label: Semantics(
        label: switch (fieldLabel) {
          final field? => l10n.shortcutFieldSemantics(field, spoken, day),
          null => l10n.shortcutSemantics(spoken, day),
        },
        excludeSemantics: true,
        child: selected
            ? Text(spoken)
            : _NameAndDay(
                name: shortcut,
                text: l10n.shortcutOnDay(shortcut, day),
              ),
      ),
      selected: selected,
      onSelected: enabled
          ? (selected) => onSelected(selected ? option : null)
          : null,
    );
  }
}

/// [text], which holds [name] and the day, with the name in its own run,
/// so that the day reads as the lighter part.
class _NameAndDay extends StatelessWidget {
  const new({required this.name, required this.text});

  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    final at = text.indexOf(name);
    if (at < 0) return Text(text);
    const day = TextStyle(fontWeight: FontWeight.w400);
    final before = text.substring(0, at);
    final after = text.substring(at + name.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (before.isNotEmpty) Text(before, style: day),
        Text(name),
        if (after.isNotEmpty) Text(after, style: day),
      ],
    );
  }
}
