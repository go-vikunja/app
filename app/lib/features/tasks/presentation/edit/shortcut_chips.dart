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
/// chip reads out its day. One row scrolling sideways, between [leading]
/// and [trailing]. Without [enabled] they only show the value.
class DateShortcutChips extends StatelessWidget {
  const new({
    required this.options,
    required this.selectedDay,
    required this.onSelected,
    this.leading = const [],
    this.trailing = const [],
    this.enabled = true,
    super.key,
  });

  final List<DateShortcutOption> options;

  /// The start of the current value's local day, if any.
  final DateTime? selectedDay;
  final ValueChanged<DateShortcutOption?> onSelected;
  final List<Widget> leading;
  final List<Widget> trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final materialL10n = MaterialLocalizations.of(context);
    final chips = [
      ...leading,
      for (final option in options)
        ChoiceChip(
          label: Text(
            shortcutLabel(l10n, option.shortcut),
            semanticsLabel: l10n.shortcutSemantics(
              shortcutLabel(l10n, option.shortcut),
              materialL10n.formatMediumDate(option.day),
            ),
          ),
          selected: option.day == selectedDay,
          onSelected: enabled
              ? (selected) => onSelected(selected ? option : null)
              : null,
        ),
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
}
