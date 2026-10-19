import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// A list in the Projects tab that is no project: the Favorites list or a
/// saved filter.
class SmartListRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.favorite = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Marks a saved filter the user made a favourite on the web.
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      leading: ExcludeSemantics(
        child: Icon(icon, color: colors.onSurfaceVariant),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: favorite
          ? Icon(
              Icons.star,
              color: colors.tertiary,
              semanticLabel: l10n.favouriteLabel,
            )
          : null,
    );
  }
}
