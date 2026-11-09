import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/online/online_trash_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/trash_repository.dart';

part 'trash_repository_providers.g.dart';

@riverpod
TrashRepository trashRepositoryFor(Ref ref, String accountId) =>
    OnlineTrashRepository(port: ref.watch(trashPortProvider(accountId)));

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
TrashRepository? trashRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(trashRepositoryForProvider(accountId));
}

/// Whether the active account's server has a trash (Vikunja 2.8.0 and
/// later on `/api/v2`); false while nobody is signed in. Every mention of
/// the bin, the Undo of a delete and the bin page depend on it.
@riverpod
bool activeServerHasTrash(Ref ref) => ref.watch(
  accountsProvider.select(
    (accounts) =>
        accounts.value?.activeAccount?.connection.capabilities.has(
          Capability.trash,
        ) ??
        false,
  ),
);
