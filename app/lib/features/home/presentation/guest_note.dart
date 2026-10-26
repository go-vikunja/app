import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/sharing/presentation/share_texts.dart';

/// Under a link-share guest's header: the share's permission as the last
/// sync stored it, what that allows, and what needs an account.
class GuestNote extends ConsumerWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final permission = ref.watch(
      projectAccessProvider(projectId).select((access) => access.permission),
    );
    final allowed = switch (permission) {
      null => null,
      final permission when permission.canWrite => l10n.guestNoteCanChange,
      _ => l10n.guestNoteCanView,
    };
    final body = [?allowed, l10n.guestNoteNeedsAccount].join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Semantics(
        container: true,
        child: Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.link, color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      if (permission != null)
                        Text(
                          l10n.guestNotePermission(
                            permissionLabel(l10n, permission),
                          ),
                          style: theme.textTheme.titleSmall,
                        ),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
