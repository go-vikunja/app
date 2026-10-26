import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/online/online_project_sharing_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_sharing_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'project_sharing_repository_providers.g.dart';

@riverpod
ProjectSharingRepository projectSharingRepositoryFor(
  Ref ref,
  String accountId,
) {
  final username = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId)?.account.username,
    ),
  );
  return OnlineProjectSharingRepository(
    port: ref.watch(projectSharingPortProvider(accountId)),
    sync: ref.watch(syncEngineProvider(accountId)),
    currentUsername: () => username,
  );
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
ProjectSharingRepository? projectSharingRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(projectSharingRepositoryForProvider(accountId));
}
