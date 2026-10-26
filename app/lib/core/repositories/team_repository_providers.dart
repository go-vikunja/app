import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/online/online_team_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/team_repository.dart';

part 'team_repository_providers.g.dart';

@riverpod
TeamRepository teamRepositoryFor(Ref ref, String accountId) {
  final user = ref.watch(
    accountsProvider.select((accounts) {
      final account = accounts.value?.find(accountId)?.account;
      if (account == null) return null;
      return (id: account.userId, username: account.username);
    }),
  );
  return OnlineTeamRepository(
    port: ref.watch(teamsPortProvider(accountId)),
    sync: ref.watch(syncEngineProvider(accountId)),
    currentUser: () => user,
  );
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
TeamRepository? teamRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(teamRepositoryForProvider(accountId));
}
