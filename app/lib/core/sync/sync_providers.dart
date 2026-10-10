import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

part 'sync_providers.g.dart';

/// The sync status of the active account: loading until its engine has
/// reported, and forever while nobody is signed in. Its `value` is null
/// before the first report; during an account switch it stays the previous
/// account's until the new engine reports, so a switch between two synced
/// accounts never passes through the first-sync screen.
@Riverpod(keepAlive: true)
Stream<SyncStatus> syncStatus(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return const Stream.empty();
  return ref.watch(syncEngineProvider(accountId)).status;
}

/// The first status the active account's engine reports, for the moment
/// before anything on screen listens. A provider nobody listens to is
/// paused, so its future alone would never complete.
Future<SyncStatus> firstSyncStatus(ProviderContainer container) async {
  final subscription = container.listen(syncStatusProvider, (_, _) {});
  try {
    return await container.read(syncStatusProvider.future);
  } finally {
    subscription.close();
  }
}
