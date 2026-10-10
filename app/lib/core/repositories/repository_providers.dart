import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

part 'repository_providers.g.dart';

final _log = Logger('AccountData');

@Riverpod(keepAlive: true)
String? activeAccountId(Ref ref) => ref.watch(
  accountsProvider.select((accounts) => accounts.value?.activeAccountId),
);

/// Reads for one account, through its session manager. Kept alive by the
/// sync engine that uses it, so it goes with the engine on sign-out.
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

@Riverpod(keepAlive: true)
AccountDatabaseFiles accountDatabaseFiles(Ref ref) =>
    PathProviderAccountDatabaseFiles();

@Riverpod(keepAlive: true)
OpenDatabases openDatabases(Ref ref) =>
    OpenDatabases(ref.watch(accountDatabaseFilesProvider));

typedef AccountDatabaseOpener = AppDatabase Function(
  String accountId,
  AccountDatabaseFiles files,
);

/// The databases this isolate has open, one per account. Sign-out closes a
/// database here, exactly once and before its files go, whenever Riverpod
/// gets round to disposing the provider.
final class OpenDatabases {
  new(this._files, {AccountDatabaseOpener open = _openDefault})
    : _openDatabase = open;

  final AccountDatabaseFiles _files;
  final AccountDatabaseOpener _openDatabase;
  final _open = <String, AppDatabase>{};
  final _closing = <String, Future<void>>{};

  static AppDatabase _openDefault(
    String accountId,
    AccountDatabaseFiles files,
  ) => openAccountDatabase(accountId: accountId, files: files);

  AppDatabase open(String accountId) =>
      _open[accountId] ??= _openDatabase(accountId, _files);

  /// Completes once the database isolate has closed sqlite; immediately when
  /// the database is not open.
  Future<void> close(String accountId) {
    final database = _open.remove(accountId);
    if (database == null) return _closing[accountId] ?? Future.value();
    late final Future<void> closing;
    closing = database
        .close()
        // close() only disconnects; the isolate closes sqlite afterwards.
        .then((_) => awaitAccountDatabaseClosed(accountId))
        .whenComplete(() {
          if (identical(_closing[accountId], closing)) {
            unawaited(_closing.remove(accountId));
          }
        });
    return _closing[accountId] = closing;
  }
}

/// One account's database, open until sign-out.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref, String accountId) {
  // Sign-out deletes the files right after the registry drops the account;
  // a rebuild in between must not open them again.
  final registered = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId) != null,
    ),
  );
  if (!registered) throw StateError('Account $accountId is not registered');
  final databases = ref.watch(openDatabasesProvider);
  ref.onDispose(() => unawaited(databases.close(accountId)));
  return databases.open(accountId);
}

/// One account's sync engine; disposed with its database on sign-out.
@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref, String accountId) {
  final perPage = ref.watch(
    accountsProvider.select(
      (accounts) =>
          accounts.value?.find(accountId)?.connection.info.maxItemsPerPage,
    ),
  );
  if (perPage == null) throw StateError('Account $accountId is not registered');
  final gateway = ref.watch(accountGatewayProvider);
  final sessions = ref.watch(sessionManagersProvider);
  final engine = DefaultSyncEngine(
    db: ref.watch(appDatabaseProvider(accountId)),
    client: ref.watch(readClientProvider(accountId)),
    perPage: perPage,
    currentUser: () {
      final entry = ref.read(accountsProvider).value?.find(accountId);
      if (entry == null) {
        throw StateError('Account $accountId is not registered');
      }
      return gateway.currentUser(
        entry.connection,
        sessions.forAccount(accountId),
      );
    },
  );
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
}

/// One account's repositories over its database. Kept alive by the
/// active-account providers below, so they go when another account takes
/// over.
@riverpod
ProjectRepository accountProjectRepository(Ref ref, String accountId) {
  final repository = LocalProjectRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(syncEngineProvider(accountId)),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@riverpod
TaskRepository accountTaskRepository(Ref ref, String accountId) {
  final repository = LocalTaskRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(syncEngineProvider(accountId)),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

/// The active account's projects; replaced when the active account changes.
/// Null while no account is signed in.
@Riverpod(keepAlive: true)
ProjectRepository? projectRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountProjectRepositoryProvider(accountId));
}

@Riverpod(keepAlive: true)
TaskRepository? taskRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountTaskRepositoryProvider(accountId));
}

/// The last step of a sign-out: stops the account's sync engine, closes its
/// database and deletes the files.
@Riverpod(keepAlive: true)
AccountDataWiper accountDataWiper(Ref ref) => (accountId) async {
  await _disposeSyncEngine(ref, accountId);
  await ref.read(openDatabasesProvider).close(accountId);
  await ref.read(accountDatabaseFilesProvider).deleteFor(accountId);
};

Future<void> _disposeSyncEngine(Ref ref, String accountId) async {
  if (!ref.exists(syncEngineProvider(accountId))) return;
  try {
    await ref.read(syncEngineProvider(accountId)).dispose();
  } on Object catch (error) {
    // The registry change got there first: the provider disposed the engine
    // and now refuses the unregistered account.
    _log.fine(
      'Sync engine of account $accountId was already disposed: '
      '${error.runtimeType}',
    );
  }
}
