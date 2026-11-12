import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/deleted_account.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/sign_out.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/background/background_runner_channel.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/repositories/user_repository.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/core/support/session_end_log.dart';
import 'package:vikunja_mobile/core/sync/guest_read_client.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_hosts.dart';

part 'repository_providers.g.dart';

final _log = Logger('AccountData');

@Riverpod(keepAlive: true)
String? activeAccountId(Ref ref) => ref.watch(
  accountsProvider.select((accounts) => accounts.value?.activeAccountId),
);

/// Whether the active account is a link-share guest, which sees one
/// project and none of what needs a user.
@Riverpod(keepAlive: true)
bool activeAccountIsGuest(Ref ref) => ref.watch(
  accountsProvider.select(
    (accounts) => accounts.value?.activeAccount?.account.isLinkShare ?? false,
  ),
);

@riverpod
bool accountIsGuest(Ref ref, String accountId) => ref.watch(
  accountsProvider.select(
    (accounts) => accounts.value?.find(accountId)?.account.isLinkShare ?? false,
  ),
);

/// The authenticated client of one account, shared by its read and write
/// clients. Kept alive by the sync engine and the outbox sender that use
/// it, so it goes with them on sign-out.
@riverpod
Dio accountDio(Ref ref, String accountId) {
  final linkShares = _sharedProjectOf(ref, accountId) == null
      ? null
      : ref.watch(linkShareSessionsProvider);
  final dio = createAuthenticatedDio(
    base: ref.watch(dioProvider),
    connection: _connectionOf(ref, accountId),
    tokens: AccountTokens(
      ref.watch(sessionManagersProvider),
      accountId,
      linkShares: linkShares,
    ),
    interceptors: [
      if (linkShares != null)
        LinkShareGoneInterceptor(
          onGone: (failure) =>
              linkShares.forAccount(accountId).noteGone(failure),
        ),
      if (kDebugMode) RequestLogInterceptor(),
    ],
  );
  ref.onDispose(dio.close);
  return dio;
}

@riverpod
VikunjaReadClient readClient(Ref ref, String accountId) {
  final client = createReadClient(
    dio: ref.watch(accountDioProvider(accountId)),
    connection: _connectionOf(ref, accountId),
  );
  final registry = ref.watch(accountRegistryProvider);
  return switch (_sharedProjectOf(ref, accountId)) {
    final projectId? => GuestReadClient(
      client,
      sharedProjectId: projectId,
      onSharedProjectTitle: (title) =>
          registry.updateGuestTitle(accountId, title),
    ),
    null => client,
  };
}

@riverpod
VikunjaWriteClient writeClient(Ref ref, String accountId) => createWriteClient(
  dio: ref.watch(accountDioProvider(accountId)),
  connection: _connectionOf(ref, accountId),
);

@riverpod
UserSettingsWritePort userSettingsWritePort(Ref ref, String accountId) =>
    createUserSettingsWritePort(
      dio: ref.watch(accountDioProvider(accountId)),
      connection: _connectionOf(ref, accountId),
    );

@riverpod
AccountSecurityPort accountSecurityPort(Ref ref, String accountId) =>
    createAccountSecurityPort(
      dio: ref.watch(accountDioProvider(accountId)),
      connection: _connectionOf(ref, accountId),
    );

@riverpod
TeamsPort teamsPort(Ref ref, String accountId) => createTeamsPort(
  dio: ref.watch(accountDioProvider(accountId)),
  connection: _connectionOf(ref, accountId),
);

@riverpod
ProjectSharingPort projectSharingPort(Ref ref, String accountId) =>
    createProjectSharingPort(
      dio: ref.watch(accountDioProvider(accountId)),
      connection: _connectionOf(ref, accountId),
    );

@riverpod
TrashPort trashPort(Ref ref, String accountId) => createTrashPort(
  dio: ref.watch(accountDioProvider(accountId)),
  connection: _connectionOf(ref, accountId),
);

/// The registry hands out new connection instances on every write, so only
/// the parts the ports build on count as a change: the root and the API
/// versions, which choose the transport, and the server version, which
/// gates routes and changes when a refresh of `/info` finds the server
/// upgraded.
ServerConnection _connectionOf(Ref ref, String accountId) {
  final portsKey = ref.watch(
    accountsProvider.select(
      (accounts) => _portsKey(accounts.value?.find(accountId)?.connection),
    ),
  );
  if (portsKey == null) {
    throw StateError('Account $accountId is not registered');
  }
  return ref.read(accountsProvider).value!.find(accountId)!.connection;
}

/// A guest's shared project, null for a user. Neither changes for an
/// account id.
int? _sharedProjectOf(Ref ref, String accountId) => ref.watch(
  accountsProvider.select(
    (accounts) => accounts.value?.find(accountId)?.account.projectId,
  ),
);

/// Looks the session up on every request: a new sign-in replaces it, and a
/// client built before it must use the new session. A guest's session
/// comes from the link shares, a user's from the session managers.
final class AccountTokens implements AccessTokenSource {
  const new(this._sessions, this._accountId, {this._linkShares});

  final SessionManagers _sessions;
  final String _accountId;
  final LinkShareSessions? _linkShares;

  AccessTokenSource get _session =>
      _linkShares?.forAccount(_accountId) ?? _sessions.forAccount(_accountId);

  @override
  Future<String> validAccessToken() => _session.validAccessToken();

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) =>
      _session.refreshAfterRejection(rejectedToken);
}

(Uri, String, String)? _portsKey(ServerConnection? connection) {
  if (connection == null) return null;
  final versions = [
    for (final version in ApiVersion.values)
      if (connection.apiVersions.contains(version)) version.name,
  ];
  final info = connection.info;
  return (
    connection.rootUri,
    versions.join(','),
    info.version?.raw ?? info.rawVersion,
  );
}

@Riverpod(keepAlive: true)
AccountDatabaseFiles accountDatabaseFiles(Ref ref) =>
    PathProviderAccountDatabaseFiles();

/// One account's stored copies of queued uploads, shared by its task
/// repository and outbox sender.
@Riverpod(keepAlive: true)
UploadFiles accountUploadFiles(Ref ref, String accountId) {
  final files = ref.watch(accountDatabaseFilesProvider);
  return UploadFiles(() => files.uploadsDirectoryFor(accountId));
}

/// Downloaded attachments of every account; downloads unused for a few
/// days go when this is first read.
@Riverpod(keepAlive: true)
AttachmentDownloads attachmentDownloads(Ref ref) {
  final downloads = AttachmentDownloads(getApplicationCacheDirectory);
  unawaited(downloads.purgeStale());
  return downloads;
}

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

  /// Disconnects this isolate's client; immediately when the database is
  /// not open. The isolate closes sqlite once its last client is gone,
  /// which another isolate's client may hold off.
  Future<void> close(String accountId) {
    final database = _open.remove(accountId);
    if (database == null) return _closing[accountId] ?? Future.value();
    late final Future<void> closing;
    closing = database.close().whenComplete(() {
      if (identical(_closing[accountId], closing)) {
        unawaited(_closing.remove(accountId));
      }
    });
    return _closing[accountId] = closing;
  }

  /// Sign-out: [close], then wait until the database isolate has closed
  /// sqlite, so the files can go.
  Future<void> closeForDeletion(String accountId) async {
    await close(accountId);
    await awaitAccountDatabaseClosed(accountId);
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

/// True in a container the OS started without the app (a background run,
/// a notification action): its sync engines leave the daily full pull to
/// the app and give way to a run already in progress.
@Riverpod(keepAlive: true)
bool runsHeadless(Ref ref) => false;

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
  final registry = ref.watch(accountRegistryProvider);
  final isGuest = _sharedProjectOf(ref, accountId) != null;
  final engine = DefaultSyncEngine(
    db: ref.watch(appDatabaseProvider(accountId)),
    client: ref.watch(readClientProvider(accountId)),
    perPage: perPage,
    headless: ref.watch(runsHeadlessProvider),
    // The name and the avatar change on the web too. A guest is a pseudo
    // user "Link Share" without settings, which older servers may not even
    // answer, and keeps the name it was given.
    currentUserWithProfile: isGuest
        ? null
        : () async {
            final entry = ref.read(accountsProvider).value?.find(accountId);
            if (entry == null) {
              throw StateError('Account $accountId is not registered');
            }
            final session = sessions.forAccount(accountId);
            final current = await endingSessionOfDeletedAccount(
              session,
              () => gateway.currentUserWithProfile(entry.connection, session),
            );
            final UserProfile(:username, :name, :updated) = current.profile;
            if (updated != null &&
                ref.mounted &&
                ref.exists(accountAvatarCacheProvider(accountId))) {
              ref
                  .read(accountAvatarCacheProvider(accountId))
                  .noteUpdated(username, updated);
            }
            await registry.updateDisplayName(accountId, name);
            return current;
          },
  );
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
}

/// One account's outbox sender; disposed with its database on sign-out.
/// It drains when built (app start), when the app comes back to the front
/// and after every local write; a session that needs a new sign-in pauses
/// it, and the sign-in resumes it.
@Riverpod(keepAlive: true)
OutboxSender outboxSender(Ref ref, String accountId) {
  final sender = OutboxSender(
    db: ref.watch(appDatabaseProvider(accountId)),
    writeClient: ref.watch(writeClientProvider(accountId)),
    readClient: ref.watch(readClientProvider(accountId)),
    sync: ref.watch(syncEngineProvider(accountId)),
    now: ref.watch(clockProvider),
    uploads: ref.watch(accountUploadFilesProvider(accountId)),
    headless: ref.watch(runsHeadlessProvider),
    currentUserId: () =>
        ref.read(accountsProvider).value?.find(accountId)?.account.userId,
    maxUploadBytes: () =>
        switch (ref.read(accountsProvider).value?.find(accountId)) {
          final entry? => maxUploadBytesOf(entry.connection.info),
          null => null,
        },
  );
  final needsReauth = accountsProvider.select(
    (accounts) => accounts.value?.find(accountId)?.account.needsReauth,
  );
  ref.listen(needsReauth, (_, next) {
    switch (next) {
      case true:
        sender.pause();
      case false:
        _drainQuietly(sender.resume);
      case null:
        break;
    }
  });
  final lifecycle = AppLifecycleListener(
    onResume: () => _drainQuietly(sender.drain),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(sender.dispose());
  });
  if (ref.read(needsReauth) ?? true) {
    sender.pause();
  } else {
    _drainQuietly(sender.drain);
  }
  return sender;
}

void _drainQuietly(Future<void> Function() drain) => unawaited(
  drain().then<void>(
    (_) {},
    onError: (Object error) =>
        _log.warning('Outbox drain failed: ${error.runtimeType}'),
  ),
);

/// One account's repositories over its database. Kept alive by the
/// active-account providers below, so they go when another account takes
/// over.
@riverpod
ProjectRepository accountProjectRepository(Ref ref, String accountId) {
  final repository = LocalProjectRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(syncEngineProvider(accountId)),
    ref.watch(writeClientProvider(accountId)),
    trash: ref.watch(trashPortProvider(accountId)),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@riverpod
TaskRepository accountTaskRepository(Ref ref, String accountId) {
  final perPage = ref.watch(
    accountsProvider.select(
      (accounts) =>
          accounts.value?.find(accountId)?.connection.info.maxItemsPerPage,
    ),
  );
  if (perPage == null) throw StateError('Account $accountId is not registered');
  final maxUploadBytes = ref.watch(
    accountsProvider.select(
      (accounts) => switch (accounts.value?.find(accountId)) {
        final entry? => maxUploadBytesOf(entry.connection.info),
        null => defaultMaxUploadBytes,
      },
    ),
  );
  // Listened, not watched: a tick re-evaluates the filters with relative
  // dates instead of rebuilding the repository and every list.
  final clockTicks = StreamController<void>.broadcast();
  ref.listen(clockTickProvider, (_, _) => clockTicks.add(null));
  final repository = LocalTaskRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(syncEngineProvider(accountId)),
    ref.watch(outboxSenderProvider(accountId)),
    ref.watch(writeClientProvider(accountId)),
    read: ref.watch(readClientProvider(accountId)),
    perPage: perPage,
    now: ref.watch(clockProvider),
    clockTicks: clockTicks.stream,
    uploads: ref.watch(accountUploadFilesProvider(accountId)),
    maxUploadBytes: maxUploadBytes,
    trash: ref.watch(trashPortProvider(accountId)),
  );
  ref
    ..onDispose(repository.dispose)
    ..onDispose(clockTicks.close);
  return repository;
}

@riverpod
LabelRepository accountLabelRepository(Ref ref, String accountId) {
  final userId = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId)?.account.userId,
    ),
  );
  final repository = LocalLabelRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(writeClientProvider(accountId)),
    ref.watch(readClientProvider(accountId)),
    sync: ref.watch(syncEngineProvider(accountId)),
    currentUserId: () => userId,
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@riverpod
UserRepository accountUserRepository(Ref ref, String accountId) {
  final repository = LocalUserRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(readClientProvider(accountId)),
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

@Riverpod(keepAlive: true)
LabelRepository? labelRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountLabelRepositoryProvider(accountId));
}

@Riverpod(keepAlive: true)
UserRepository? userRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountUserRepositoryProvider(accountId));
}

/// The last step of a sign-out: makes a background run in another isolate
/// let go of the account, drops its avatars and attachment images from
/// memory, cancels the account's notifications (scheduled and in the
/// tray) and forgets their preferences, the background notes, the last
/// session end, the sign-in page on another host it confirmed, the unsent
/// comments and the description draft, replaces its home-screen widgets'
/// content with "Account removed", stops its outbox sender and sync
/// engine, closes its database and deletes the files: the database, the
/// stored copies of queued uploads and the downloaded attachments.
@Riverpod(keepAlive: true)
AccountDataWiper accountDataWiper(Ref ref) => (accountId) async {
  BackgroundRunnerChannel.release(accountId);
  ref
    ..invalidate(accountAvatarCacheProvider(accountId))
    ..invalidate(accountAttachmentImagesProvider(accountId));
  await _disposeQuietly('Background notes', accountId, () async {
    await ref.read(backgroundRunLogProvider).forget(accountId);
    await ref.read(sessionEndLogProvider).forget(accountId);
    await ref
        .read(preferencesStoreProvider)
        .remove(ActivityNotifier.sessionEndedKey(accountId));
  });
  await _disposeQuietly(
    'Confirmed sign-in host',
    accountId,
    () =>
        ConfirmedSignInHosts(ref.read(preferencesStoreProvider))
            .forget(accountId),
  );
  await _disposeQuietly(
    'Comment drafts',
    accountId,
    () => ref.read(commentDraftsProvider).discardAll(accountId),
  );
  await _disposeQuietly(
    'Description draft',
    accountId,
    () => ref.read(descriptionDraftsProvider).discardAll(accountId),
  );
  await _disposeQuietly(
    'Notification scheduler',
    accountId,
    () => ref.read(notificationSchedulersProvider).cancelAll(accountId),
  );
  await _disposeQuietly(
    'Delivered notifications',
    accountId,
    () =>
        ActivityTray(ref.read(notificationGatewayProvider))
            .withdrawAll(accountId),
  );
  await _disposeQuietly(
    'Notification preferences',
    accountId,
    () => ref.read(notificationPreferencesStoreProvider).delete(accountId),
  );
  await _disposeQuietly(
    'Widgets',
    accountId,
    () => ref.read(widgetPublishersProvider).wipe(accountId),
  );
  if (ref.exists(outboxSenderProvider(accountId))) {
    await _disposeQuietly(
      'Outbox sender',
      accountId,
      () => ref.read(outboxSenderProvider(accountId)).dispose(),
    );
  }
  if (ref.exists(syncEngineProvider(accountId))) {
    await _disposeQuietly(
      'Sync engine',
      accountId,
      () => ref.read(syncEngineProvider(accountId)).dispose(),
    );
  }
  await ref.read(openDatabasesProvider).closeForDeletion(accountId);
  await ref.read(accountDatabaseFilesProvider).deleteFor(accountId);
  ref.invalidate(accountUploadFilesProvider(accountId));
  await _disposeQuietly(
    'Downloaded attachments',
    accountId,
    () => ref.read(attachmentDownloadsProvider).purgeAccount(accountId),
  );
};

Future<void> _disposeQuietly(
  String what,
  String accountId,
  Future<void> Function() dispose,
) async {
  try {
    await dispose();
  } on Object catch (error) {
    // The registry change got there first: the provider disposed it and
    // now refuses the unregistered account.
    _log.fine(
      '$what of account $accountId was already disposed: '
      '${error.runtimeType}',
    );
  }
}
