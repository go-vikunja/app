import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'bucket_repository_providers.g.dart';

@riverpod
BucketRepository accountBucketRepository(Ref ref, String accountId) {
  final tasks = ref.watch(accountTaskRepositoryProvider(accountId));
  return LocalBucketRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(writeClientProvider(accountId)),
    // After a bucket write: a sync that read before it would put it back.
    refreshBoard: (projectId, viewId) =>
        tasks.refreshBoard(projectId, viewId, inNewRun: true),
    now: ref.watch(clockProvider),
  );
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
BucketRepository? bucketRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountBucketRepositoryProvider(accountId));
}
