import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// One related task in a section card: its title, struck through when
/// done; a tap opens it and the trailing button removes the relation.
/// [leading] is a subtask's done control.
class RelationRow extends StatelessWidget {
  const new({
    required this.task,
    required this.onOpen,
    this.onRemove,
    this.leading,
    this.projectTitle,
    super.key,
  });

  final Task task;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;
  final Widget? leading;

  /// Shown for a task in another project than the one the sheet is about.
  final String? projectTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final projectTitle = this.projectTitle;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        // The done control brings its own padding, as does the button.
        start: leading == null ? 16 : 4,
        end: onRemove == null ? 16 : 4,
      ),
      leading: leading,
      horizontalTitleGap: leading == null ? null : 4,
      title: Text(
        task.title,
        style: task.done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: colors.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: projectTitle == null
          ? null
          : Text(
              projectTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
      onTap: onOpen,
      trailing: onRemove == null
          ? null
          : IconButton(
              onPressed: onRemove,
              tooltip: l10n.taskRelationRemove,
              icon: const Icon(Icons.link_off),
            ),
    );
  }
}
