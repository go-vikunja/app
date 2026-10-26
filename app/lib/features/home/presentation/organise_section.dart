import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/tasks/application/label_providers.dart';

/// The account's labels, with how many this device has, and its teams.
class OrganiseSection extends ConsumerWidget {
  const new({required this.busy, super.key});

  /// While signing in or out, when the account must not be read again.
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelCount = ref.watch(
      allLabelsProvider.select((labels) => labels.value?.length),
    );
    return SettingsSection(
      title: l10n.accountOrganiseHeading,
      children: [
        ListTile(
          leading: const Icon(Icons.label_outline),
          title: Text(l10n.accountLabelsEntry),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (labelCount != null)
                Text(
                  '$labelCount',
                  semanticsLabel: l10n.labelsCount(labelCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
          enabled: !busy,
          onTap: () => unawaited(GoRouter.of(context).push(AppRoutes.labels)),
        ),
        ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(l10n.accountTeamsEntry),
          trailing: const Icon(Icons.chevron_right),
          enabled: !busy,
          onTap: () => unawaited(GoRouter.of(context).push(AppRoutes.teams)),
        ),
      ],
    );
  }
}
