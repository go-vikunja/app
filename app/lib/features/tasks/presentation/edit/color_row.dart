import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/tasks/application/color_palette.dart';

/// "No colour", the [okabeItoColors], and the [original] and current colour
/// when they are none of those, so that a colour set elsewhere stays and
/// can be chosen again after trying another. [value], [original] and the
/// callback carry six hex digits without `#`, or an empty string.
class ColorRow extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    this.original = '',
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// The colour the item had when the page opened.
  final String original;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final choices = [
      ...okabeItoColors,
      for (final hex in {original, value})
        if (hex.isNotEmpty && !okabeItoColors.contains(hex)) hex,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Swatch(
          label: l10n.taskEditNoColour,
          color: null,
          selected: value.isEmpty,
          onTap: () => onChanged(''),
        ),
        for (final hex in choices)
          _Swatch(
            label: l10n.taskEditColourSemantics('#$hex'),
            color: parseHexColor(hex) ?? colors.surfaceContainerHighest,
            selected: value == hex,
            onTap: () => onChanged(hex),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const new({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = color ?? colors.surface;
    final check = color == null ? colors.onSurface : contrastingTextColor(fill);
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        // The tap target is 48 dp; the swatch inside stays compact.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              child: color == null
                  ? Icon(Icons.block, color: colors.onSurfaceVariant, size: 20)
                  : selected
                  ? Icon(Icons.check, color: check, size: 22)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
