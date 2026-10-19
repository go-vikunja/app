import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';

/// Above a list on a page over the shell, where the [OfflineBanner] does
/// not show, when the last sync or refresh could not reach the server: the
/// saved data is shown, nothing is wrong with it.
class OfflineNotice extends StatelessWidget {
  const new({super.key});

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
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.offlineNotice,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
