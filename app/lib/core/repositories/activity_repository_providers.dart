import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_sync.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_activity_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'activity_repository_providers.g.dart';

@Riverpod(keepAlive: true)
ActivityTray activityTray(Ref ref) =>
    ActivityTray(ref.watch(notificationGatewayProvider));

/// One account's activity sync (the server's notifications); goes with its
/// database on sign-out.
@Riverpod(keepAlive: true)
ActivitySync activitySync(Ref ref, String accountId) {
  final tray = ref.watch(activityTrayProvider);
  return ActivitySync(
    db: ref.watch(appDatabaseProvider(accountId)),
    read: ref.watch(readClientProvider(accountId)).notifications,
    write: ref.watch(writeClientProvider(accountId)).notifications,
    now: ref.watch(clockProvider),
    withdraw: (ids) => tray.withdraw(accountId, ids),
  );
}

/// Kept alive by [activityRepositoryProvider], so it goes when another
/// account takes over.
@riverpod
ActivityRepository accountActivityRepository(Ref ref, String accountId) {
  final repository = LocalActivityRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(activitySyncProvider(accountId)),
    accountId: accountId,
    tray: ref.watch(activityTrayProvider),
    now: ref.watch(clockProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

/// The active account's inbox; null while nobody is signed in.
@Riverpod(keepAlive: true)
ActivityRepository? activityRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountActivityRepositoryProvider(accountId));
}
