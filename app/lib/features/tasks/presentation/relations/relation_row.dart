import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// One related task: its title, struck through when done, and identifier;
/// a tap opens it and the trailing button removes the relation. [leading]
/// is a subtask's done control.
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
    final colors = Theme.of(context).colorScheme;
    // A task not yet sent has no identifier until the server assigns one.
    final details = [
      if (task.id > 0) task.displayIdentifier,
      ?projectTitle,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: Text(
        task.title,
        style: task.done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: colors.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: details.isEmpty ? null : Text(details),
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

/// A section heading in the detail sheet, with [trailing] at its end.
class DetailSectionHeader extends StatelessWidget {
  const new({required this.title, this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.primary,
              ),
            ),
          ),
          if (trailing case final trailing?)
            Text(
              trailing,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
