import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_view_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'project_view_repository_providers.g.dart';

@riverpod
ProjectViewRepository accountProjectViewRepository(Ref ref, String accountId) {
  final perPage = ref.watch(
    accountsProvider.select(
      (accounts) =>
          accounts.value?.find(accountId)?.connection.info.maxItemsPerPage,
    ),
  );
  if (perPage == null) throw StateError('Account $accountId is not registered');
  return LocalProjectViewRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(syncEngineProvider(accountId)),
    ref.watch(writeClientProvider(accountId)),
    ref.watch(readClientProvider(accountId)),
    perPage: perPage,
    now: ref.watch(clockProvider),
  );
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
ProjectViewRepository? projectViewRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountProjectViewRepositoryProvider(accountId));
}
