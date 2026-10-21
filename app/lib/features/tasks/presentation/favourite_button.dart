import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';

/// The star of a task row or its detail sheet, muted when off and amber
/// when on; an indicator only without [onChanged].
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
          selectedIcon: const FilledStar(),
        ),
      ),
    );
  }
}

/// The highlight's star, outlined in the tertiary colour so that the pale
/// amber stands out from a light surface.
class FilledStar extends StatelessWidget {
  const new({this.size, super.key});

  final double? size;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Icon(
        Icons.star,
        size: size,
        color: HighlightColors.of(context).highlight,
      ),
      Icon(
        Icons.star_border,
        size: size,
        color: Theme.of(context).colorScheme.tertiary,
      ),
    ],
  );
}
