import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_message.dart';
import 'package:vikunja_mobile/features/home/presentation/background_sync_line.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_phase_label.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// When the account was last synced, in front and in the background, what
/// went wrong if the last run failed, a button for a sync right now and one
/// for a full resync. The buttons rest during a sign-out, whose wipe a run
/// would race, and for a session that ended, which the banner above asks
/// to renew.
class SyncStatusSection extends ConsumerWidget {
  const new({required this.entry, required this.signingOut, super.key});

  final RegisteredAccount entry;
  final bool signingOut;

  /// The status stream reports the outcome.
  void _syncNow(WidgetRef ref) => unawaited(
    ref
        .read(syncEngineProvider(entry.id))
        .refresh()
        .then<void>((_) {}, onError: (Object _) {}),
  );

  void _fullResync(WidgetRef ref) => unawaited(
    ref
        .read(syncEngineProvider(entry.id))
        .fullResync()
        .then<void>((_) {}, onError: (Object _) {}),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = ref.watch(syncStatusProvider).value;
    final now = ref.watch(clockTickProvider);
    final running = status is SyncRunning;
    final canSync = !running && !signingOut && !entry.account.needsReauth;
    final lastSyncedAt = switch (status) {
      SyncIdle(:final lastSyncedAt) => lastSyncedAt,
      SyncFailed(:final lastSyncedAt) => lastSyncedAt,
      _ => null,
    };
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return SettingsBlock(
      icon: Icons.sync,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          // A run is announced once, not per phase: the timer runs one
          // every minute. A failure is announced when it appears; the time
          // ticks every minute and is only read on focus.
          if (status case SyncRunning(:final phase))
            Semantics(
              container: true,
              liveRegion: true,
              label: l10n.accountSyncing,
              excludeSemantics: true,
              child: Text(
                syncPhaseLabel(l10n, phase),
                style: theme.textTheme.bodyLarge,
              ),
            )
          else
            Text(switch (lastSyncedAt) {
              final at? when isJustNow(at, now: now) =>
                l10n.accountLastSyncedJustNow,
              final at? => l10n.accountLastSynced(
                formatRelativeTime(l10n, at, now: now),
              ),
              null => l10n.accountNeverSynced,
            }, style: theme.textTheme.bodyLarge),
          if (status case SyncFailed(:final failure))
            Semantics(
              container: true,
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    l10n.accountSyncFailed,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                  Text(
                    describeDataFailure(
                      l10n,
                      failure,
                      serverRoot: entry.connection.rootUri,
                      platform: theme.platform,
                      stale: lastSyncedAt != null,
                    ).explanation,
                    style: secondary,
                  ),
                ],
              ),
            ),
          BackgroundSyncLine(accountId: entry.id),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: canSync ? () => _syncNow(ref) : null,
                  style: inlineFilledButtonStyle(context),
                  icon: running
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    running ? l10n.accountSyncing : l10n.accountSyncNow,
                  ),
                ),
                TextButton.icon(
                  onPressed: canSync ? () => _fullResync(ref) : null,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.accountFullResync),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
