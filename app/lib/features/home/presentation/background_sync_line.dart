import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/home/application/background_last_run.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// When the system last let the app sync this account in the background;
/// on iOS, before the first run, that the system decides when.
class BackgroundSyncLine extends ConsumerWidget {
  const new({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastRun = ref.watch(backgroundLastRunProvider(accountId));
    if (!lastRun.hasValue) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(clockTickProvider);
    final at = lastRun.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(switch (at) {
          final at? when isJustNow(at, now: now) =>
            l10n.accountBackgroundSyncJustNow,
          final at? => l10n.accountBackgroundSync(
            formatRelativeTime(l10n, at, now: now),
          ),
          null => l10n.accountBackgroundSyncNever,
        }, style: style),
        if (at == null && theme.platform == TargetPlatform.iOS)
          Text(l10n.accountBackgroundSyncIosHint, style: style),
      ],
    );
  }
}
