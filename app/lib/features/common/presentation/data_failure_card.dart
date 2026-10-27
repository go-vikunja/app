import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_message.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_settings_action.dart';

/// Explains a failed load or refresh and offers a retry, and the server's
/// connection settings when only they can fix it. With [stale] data on
/// screen it is a notice above the list rather than the whole screen.
class DataFailureCard extends ConsumerWidget {
  const new({
    required this.error,
    required this.stale,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final bool stale;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final serverRoot = ref.watch(
      accountsProvider.select(
        (accounts) => accounts.value?.activeAccount?.connection.rootUri,
      ),
    );
    final guest = ref.watch(
      accountsProvider.select(
        (accounts) =>
            accounts.value?.activeAccount?.account.isLinkShare ?? false,
      ),
    );
    final message = describeDataFailure(
      l10n,
      error,
      serverRoot: serverRoot ?? Uri(),
      platform: theme.platform,
      stale: stale,
      guest: guest,
    );
    return StatusCard(
      icon: stale ? Icons.cloud_off_outlined : Icons.error_outline,
      title: message.title,
      body: message.explanation,
      footnote: message.suggestion.isEmpty ? null : message.suggestion,
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
      liveRegion: true,
      action: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: [
          if (serverRoot != null && ConnectionSettingsAction.appliesTo(error))
            ConnectionSettingsAction(
              error: error,
              serverRoot: serverRoot,
              onChanged: onRetry,
              foreground: colors.onErrorContainer,
            ),
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: colors.onErrorContainer,
            ),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
