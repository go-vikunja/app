import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';

part 'account_context_providers.g.dart';

/// The active account's server and frontend, which rich text needs for its
/// attachment images and task links; null while nobody is signed in.
@riverpod
AccountLinkBases? activeLinkBases(Ref ref) => ref.watch(
  accountsProvider.select((accounts) {
    final connection = accounts.value?.activeAccount?.connection;
    return connection == null ? null : AccountLinkBases.of(connection);
  }),
);

/// The signed-in user's id on the active account's server.
@riverpod
int? activeUserId(Ref ref) => ref.watch(
  accountsProvider.select(
    (accounts) => accounts.value?.activeAccount?.account.userId,
  ),
);
