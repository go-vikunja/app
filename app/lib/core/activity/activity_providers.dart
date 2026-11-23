import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/foreground_activity.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'activity_providers.g.dart';

final _log = Logger('ActivitySync');

@Riverpod(keepAlive: true)
ActivityNotifier activityNotices(Ref ref) => ActivityNotifier(
  gateway: ref.watch(notificationGatewayProvider),
  preferences: ref.watch(notificationPreferencesStoreProvider),
  store: ref.watch(preferencesStoreProvider),
  l10n: ref.watch(deviceAppLocalizationsProvider),
  content: () async =>
      (await ref.read(privacySettingsProvider.future)).notificationContent,
  endedOnDevice: ref.watch(sessionDiagnosticsProvider).endedOnDevice,
);

/// The foreground side of activity and background sync; the foreground
/// sync scheduler reports its start, resumes and ticks here.
@Riverpod(keepAlive: true)
ForegroundActivity foregroundActivity(Ref ref) => ForegroundActivity(
  syncActive: () => _syncActiveAccount(ref),
  syncInactive: () => _syncInactiveAccounts(ref),
  clock: ref.watch(clockProvider),
);

Future<void> _syncActiveAccount(Ref ref) async {
  final active = ref.read(accountsProvider).value?.activeAccount;
  if (active == null || active.account.needsReauth) return;
  await _sessionRestored(ref, active.id);
  // The server keeps no activity for a guest.
  if (active.account.isLinkShare) return;
  await ref.read(activityRepositoryProvider)?.refresh();
}

/// Withdraws the "Sign in again" notification unless the stored registry
/// says the session ended: a background run may have ended it, and posted
/// the notification, after this isolate last read the registry.
Future<void> _sessionRestored(Ref ref, String accountId) async {
  final stored = await ref.read(accountRegistryProvider).find(accountId);
  if (stored == null || stored.account.needsReauth) return;
  await ref.read(activityNoticesProvider).sessionRestored(accountId);
}

/// Every other signed-in account that has synced before, one after the
/// other; what is new becomes OS notifications.
Future<void> _syncInactiveAccounts(Ref ref) async {
  final state = ref.read(accountsProvider).value;
  if (state == null) return;
  for (final entry in state.accounts) {
    if (entry.id == state.activeAccountId || entry.account.needsReauth) {
      continue;
    }
    try {
      // A session that ends again after this sign-in notifies again.
      await _sessionRestored(ref, entry.id);
      if (entry.account.isLinkShare) continue;
      final db = ref.read(appDatabaseProvider(entry.id));
      final synced = await db.syncStateDao.readAll();
      if (synced[SyncStateKeys.lastSyncedAt] == null) continue;
      final fresh = await ref.read(activitySyncProvider(entry.id)).run();
      await ref
          .read(activityNoticesProvider)
          .show(account: entry.account, db: db, fresh: fresh, labelled: true);
    } on Object catch (error) {
      _log.info(
        'Activity of account ${entry.id} not synced: ${error.runtimeType}',
      );
    }
  }
}
