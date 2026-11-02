import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';

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
/// chip reads out its day; the selected one also shows [selectedTime]. One
/// row scrolling sideways, followed by [trailing]. Without [enabled] they
/// only show the value.
class DateShortcutChips extends StatelessWidget {
  const new({
    required this.options,
    required this.selectedDay,
    required this.onSelected,
    this.trailing = const [],
    this.enabled = true,
    this.selectedTime,
    super.key,
  });

  final List<DateShortcutOption> options;

  /// The start of the current value's local day, if any.
  final DateTime? selectedDay;
  final ValueChanged<DateShortcutOption?> onSelected;
  final List<Widget> trailing;
  final bool enabled;
  final String? selectedTime;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final option in options) _chip(context, option),
      ...trailing,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final chip in chips) ...[chip, const SizedBox(width: 8)],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, DateShortcutOption option) {
    final l10n = context.l10n;
    final selected = option.day == selectedDay;
    final shortcut = shortcutLabel(l10n, option.shortcut);
    final label = switch (selectedTime) {
      final time? when selected => l10n.shortcutAtTime(shortcut, time),
      _ => shortcut,
    };
    return ChoiceChip(
      label: Text(
        label,
        semanticsLabel: l10n.shortcutSemantics(
          label,
          MaterialLocalizations.of(context).formatMediumDate(option.day),
        ),
      ),
      selected: selected,
      onSelected: enabled
          ? (selected) => onSelected(selected ? option : null)
          : null,
    );
  }
}
