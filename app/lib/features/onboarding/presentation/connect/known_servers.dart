import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// The servers of the accounts already on this device, one tap each, for
/// adding another account on one of them.
class KnownServers extends StatelessWidget {
  const new({
    required this.servers,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final List<Uri> servers;
  final bool enabled;
  final ValueChanged<Uri> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.addAccountYourServers,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final server in servers)
              ActionChip(
                avatar: const Icon(Icons.dns_outlined),
                label: Text(
                  '${displayHost(server)}${displaySubPath(server) ?? ''}',
                ),
                onPressed: enabled ? () => onSelected(server) : null,
              ),
          ],
        ),
      ],
    );
  }
}
