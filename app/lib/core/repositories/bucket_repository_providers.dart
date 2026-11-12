import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'bucket_repository_providers.g.dart';

@riverpod
BucketRepository accountBucketRepository(Ref ref, String accountId) =>
    LocalBucketRepository(
      ref.watch(appDatabaseProvider(accountId)),
      ref.watch(writeClientProvider(accountId)),
      refreshBoard: ref
          .watch(accountTaskRepositoryProvider(accountId))
          .refreshBoard,
      now: ref.watch(clockProvider),
    );

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
BucketRepository? bucketRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountBucketRepositoryProvider(accountId));
}
