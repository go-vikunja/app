import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_message.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_phase_label.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// When the account was last synced, what went wrong if the last run
/// failed, and a button for a sync right now. The button rests during a
/// sign-out, whose wipe a run would race, and for a session that ended,
/// which the banner above asks to renew.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.sync, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  // The phase and a failure are announced when they change;
                  // the time ticks every minute and is only read on focus.
                  if (status case SyncRunning(:final phase))
                    Semantics(
                      container: true,
                      liveRegion: true,
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
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: canSync ? () => _syncNow(ref) : null,
            icon: running
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(running ? l10n.accountSyncing : l10n.accountSyncNow),
          ),
        ),
      ],
    );
  }
}
