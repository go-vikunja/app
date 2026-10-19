import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// The shell's strip while the last sync could not reach the server: the
/// saved data is shown, and when it was synced last. A tap syncs now.
/// Nothing while online.
class OfflineBanner extends ConsumerWidget {
  const new({super.key});

  void _syncNow(WidgetRef ref) {
    final accountId = ref.read(activeAccountIdProvider);
    if (accountId == null) return;
    // The status stream reports the outcome.
    unawaited(
      ref
          .read(syncEngineProvider(accountId))
          .refresh()
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    if (offline == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(clockTickProvider);
    final running = ref.watch(
      syncStatusProvider.select((status) => status.value is SyncRunning),
    );
    // Like the Account tab's Sync now: a run would race a sign-out's wipe,
    // and an ended session cannot sync.
    final canSync =
        !running &&
        !ref.watch(signOutControllerProvider) &&
        !ref.watch(
          accountsProvider.select(
            (accounts) =>
                accounts.value?.activeAccount?.account.needsReauth ?? false,
          ),
        );
    final lastSynced = switch (offline.lastSyncedAt) {
      final at? when isJustNow(at, now: now) => l10n.accountLastSyncedJustNow,
      final at? => l10n.accountLastSynced(
        formatRelativeTime(l10n, at.isAfter(now) ? now : at, now: now),
      ),
      null => l10n.accountNeverSynced,
    };
    final onTap = canSync ? () => _syncNow(ref) : null;

    // Announced when it appears; the time ticks every minute and is only
    // read on focus, as the value.
    return Semantics(
      container: true,
      button: true,
      enabled: canSync,
      liveRegion: true,
      label: l10n.offlineNotice,
      value: lastSynced,
      onTapHint: l10n.accountSyncNow,
      onTap: onTap,
      excludeSemantics: true,
      // It stays while offline: at full text scale it would take a third
      // of a small screen from the saved data it is about.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Material(
          color: colors.surfaceContainerHighest,
          child: InkWell(
            onTap: onTap,
            child: SafeArea(
              top: false,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: l10n.offlineNotice),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: lastSynced,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.sync,
                      size: 20,
                      color: canSync
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.38),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks the screens under the shell, which shows the [OfflineBanner]; a
/// list outside it, on a page over the shell, shows the offline notice
/// itself.
class OfflineBannerArea extends InheritedWidget {
  const new({required super.child, super.key});

  static bool contains(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OfflineBannerArea>() != null;

  @override
  bool updateShouldNotify(OfflineBannerArea oldWidget) => false;
}
