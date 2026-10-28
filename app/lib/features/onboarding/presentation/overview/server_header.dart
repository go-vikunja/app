import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

class ServerHeader extends StatelessWidget {
  const new({required this.connection, super.key});

  final ServerConnection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final host = displayHost(connection.rootUri);
    final subPath = displaySubPath(connection.rootUri);
    final version = connection.info.version;
    final apiVersions = connection.apiVersions.toList()
      ..sort((a, b) => b.index.compareTo(a.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          headingLevel: 2,
          label: host,
          excludeSemantics: true,
          child: Text(
            // Lets long host names wrap at dots instead of mid-label.
            host.replaceAll('.', '.\u200B'),
            style: theme.textTheme.headlineMedium,
          ),
        ),
        if (subPath != null)
          Text(
            subPath,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        Text(switch ((version, connection.info.rawVersion)) {
          (final ServerVersion v, _) => l10n.overviewVikunjaVersion(v.display),
          (null, final raw) when raw.isNotEmpty => l10n.overviewVikunjaVersion(
            raw.length > 40 ? '${raw.substring(0, 40)}…' : raw,
          ),
          _ => l10n.overviewVikunjaVersionUnknown,
        }, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final api in apiVersions)
              _Badge(label: l10n.overviewApiBadge(api.pathSegment)),
            if (connection.info.demoModeEnabled)
              _Badge(
                label: l10n.overviewDemoBadge,
                icon: Icons.science_outlined,
              ),
            if (connection.isInsecure)
              _Badge(
                label: l10n.overviewInsecureBadge,
                icon: Icons.lock_open,
                background: colors.errorContainer,
                foreground: colors.onErrorContainer,
              ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const new({required this.label, this.icon, this.background, this.foreground});

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        this.foreground ?? theme.colorScheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
