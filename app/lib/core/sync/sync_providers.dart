import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

part 'sync_providers.g.dart';

final _log = Logger('SyncStatus');

/// One account's sync status: loading until its engine has reported. Kept
/// alive, so that once its engine has reported, an account that becomes
/// active has its status at once.
@Riverpod(keepAlive: true)
Stream<SyncStatus> accountSyncStatus(Ref ref, String accountId) =>
    ref.watch(syncEngineProvider(accountId)).status;

/// The sync status of the active account: loading until its engine has
/// reported, and forever while nobody is signed in. Never the previous
/// account's status, nor that of an engine a sign-out replaced, which a
/// reloading provider would otherwise carry as its value.
@Riverpod(keepAlive: true)
AsyncValue<SyncStatus> syncStatus(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return const AsyncLoading();
  return ref.watch(accountSyncStatusProvider(accountId)).unwrapPrevious();
}

/// The first status the account's engine reports, building the engine if
/// needed; afterwards [accountSyncStatusProvider] has it at once. A
/// provider nobody listens to is paused, so its future alone would never
/// complete.
Future<SyncStatus> firstSyncStatus(
  ProviderContainer container,
  String accountId,
) async {
  final provider = accountSyncStatusProvider(accountId);
  final subscription = container.listen(provider, (_, _) {});
  try {
    return await container.read(provider.future);
  } finally {
    subscription.close();
  }
}

/// For an account about to become active: has its status at hand, so that
/// routing never sends an account that has synced before through the
/// first-sync screen. Never throws; after [timeout] the router waits for the
/// status on the first-sync screen instead.
Future<void> prepareSyncStatus(
  ProviderContainer container,
  String accountId, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    await firstSyncStatus(container, accountId).timeout(timeout);
  } on Object catch (error) {
    _log.info(
      'No sync status for account $accountId yet: ${error.runtimeType}',
    );
  }
}
