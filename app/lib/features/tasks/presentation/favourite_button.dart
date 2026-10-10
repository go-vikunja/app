import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// The star of a task row or its detail sheet; an indicator only without
/// [onChanged].
class FavouriteButton extends StatelessWidget {
  const new({required this.isFavorite, required this.onChanged, super.key});

  final bool isFavorite;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    // One node: the button's own node would otherwise sit below the flag.
    return MergeSemantics(
      child: Semantics(
        toggled: isFavorite,
        child: IconButton(
          onPressed: onChanged == null ? null : () => onChanged!(!isFavorite),
          tooltip: isFavorite
              ? l10n.taskRemoveFavourite
              : l10n.taskAddFavourite,
          isSelected: isFavorite,
          icon: Icon(Icons.star_border, color: colors.onSurfaceVariant),
          selectedIcon: Icon(Icons.star, color: colors.tertiary),
        ),
      ),
    );
  }
}
