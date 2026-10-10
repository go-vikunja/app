import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';
import 'package:vikunja_mobile/core/repositories/online/online_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/online/online_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
String? activeAccountId(Ref ref) => ref.watch(
  accountsProvider.select((accounts) => accounts.value?.activeAccountId),
);

/// Reads for one account, through its session manager. Kept alive by the
/// repositories that use it, so it goes with them on sign-out.
@riverpod
VikunjaReadClient readClient(Ref ref, String accountId) {
  // The registry hands out new connection instances on every write, so only
  // the parts that choose the transport count as a change.
  final transportKey = ref.watch(
    accountsProvider.select(
      (accounts) => _transportKey(accounts.value?.find(accountId)?.connection),
    ),
  );
  if (transportKey == null) {
    throw StateError('Account $accountId is not registered');
  }
  final connection = ref
      .read(accountsProvider)
      .value!
      .find(accountId)!
      .connection;
  final dio = createAuthenticatedDio(
    base: ref.watch(dioProvider),
    connection: connection,
    tokens: ref.watch(sessionManagersProvider).forAccount(accountId),
    interceptors: [if (kDebugMode) RequestLogInterceptor()],
  );
  ref.onDispose(dio.close);
  return createReadClient(dio: dio, connection: connection);
}

(Uri, String)? _transportKey(ServerConnection? connection) {
  if (connection == null) return null;
  final versions = [
    for (final version in ApiVersion.values)
      if (connection.apiVersions.contains(version)) version.name,
  ];
  return (connection.rootUri, versions.join(','));
}

/// The active account's projects; rebuilt, and the old one disposed, when
/// the active account changes. Null while no account is signed in.
@Riverpod(keepAlive: true)
ProjectRepository? projectRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  final repository = OnlineProjectRepository(
    ref.watch(readClientProvider(accountId)),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@Riverpod(keepAlive: true)
TaskRepository? taskRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  final repository = OnlineTaskRepository(
    ref.watch(readClientProvider(accountId)),
  );
  ref.onDispose(repository.dispose);
  return repository;
}
