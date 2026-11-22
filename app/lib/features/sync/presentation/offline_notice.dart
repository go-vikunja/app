import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';

/// Above a list on a page over the shell, where the [OfflineBanner] does
/// not show, when the last sync or refresh could not reach the server: the
/// saved data is shown, nothing is wrong with it.
class OfflineNotice extends StatelessWidget {
  const new({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _SavedDataNotice(
    icon: Icons.cloud_off_outlined,
    text: context.l10n.offlineNotice,
    onRetry: onRetry,
  );
}

/// Above a list whose refresh, which the user started, still waits for the
/// server after the pull's spinner ended: the list shows the saved data
/// meanwhile, and the refresh goes on.
class ServerWaitNotice extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => _SavedDataNotice(
    icon: Icons.hourglass_empty,
    text: context.l10n.refreshWaitingNotice,
  );
}

class _SavedDataNotice extends StatelessWidget {
  const new({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (onRetry case final onRetry?)
                TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ),
        ),
      ),
    );
  }
}
