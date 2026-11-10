import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/selected_task_highlight.dart';

/// A list in the Projects tab that is no project: the Favorites list or a
/// saved filter. [selected] marks the list open beside the tree's column,
/// as the task open in the pane is marked, in the colours of any other row.
class SmartListRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.favorite = false,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Marks a saved filter the user made a favourite on the web.
  final bool favorite;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return SelectedTaskHighlight(
      selected: selected,
      child: ListTile(
        onTap: onTap,
        selected: selected,
        // Selected paints the texts and icons in the primary colour, and a
        // text colour paints the subtitle too.
        textColor: WidgetStateColor.resolveWith((_) => colors.onSurface),
        iconColor: WidgetStateColor.resolveWith((_) => colors.onSurfaceVariant),
        contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
        leading: ExcludeSemantics(
          child: Icon(icon, color: colors.onSurfaceVariant),
        ),
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(color: colors.onSurfaceVariant)),
        trailing: favorite
            ? Semantics(label: l10n.favouriteLabel, child: const FilledStar())
            : null,
      ),
    );
  }
}
