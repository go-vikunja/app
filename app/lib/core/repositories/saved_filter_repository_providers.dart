import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/local/local_saved_filter_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/saved_filter_repository.dart';

part 'saved_filter_repository_providers.g.dart';

@riverpod
SavedFilterRepository accountSavedFilterRepository(Ref ref, String accountId) =>
    LocalSavedFilterRepository(
      ref.watch(appDatabaseProvider(accountId)),
      ref.watch(syncEngineProvider(accountId)),
      ref.watch(writeClientProvider(accountId)),
    );

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
SavedFilterRepository? savedFilterRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountSavedFilterRepositoryProvider(accountId));
}
