import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_account_id.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_landing.dart';

part 'guest_sign_in.g.dart';

final _log = Logger('GuestSignIn');

@immutable
sealed class GuestSignInResult {
  const new();
}

/// The guest is stored, and active unless [GuestSignIn.reopen] found
/// another account active.
final class GuestSignedIn extends GuestSignInResult {
  const new(this.account, {required this.isNewAccount});

  final RegisteredAccount account;

  /// False when the share was on this device already: only its session was
  /// replaced.
  final bool isNewAccount;
}

/// The share has a password (13001), or the one given was wrong (13002).
final class GuestPasswordRequired extends GuestSignInResult {
  const new({required this.wrongPassword});

  final bool wrongPassword;
}

/// The link no longer works: the share was deleted (with its project, or
/// to change its password), never existed, or the server has link sharing
/// off ([sharingOff]).
final class GuestLinkGone extends GuestSignInResult {
  const new({this.sharingOff = false});

  final bool sharingOff;
}

/// Any other failure: offline, the server's error, the sign-in limit
/// ([RateLimited] with its wait).
final class GuestSignInFailed extends GuestSignInResult {
  const new(this.failure);

  final VikunjaFailure failure;
}

/// Ended without keeping anything: by its `commit`, or for
/// [GuestSignIn.reopen] by the guest's removal meanwhile.
final class GuestSignInCancelled extends GuestSignInResult {
  const new();
}

typedef SharedProjectTitle = Future<String?> Function(
  ServerConnection connection,
  AccessTokenSource tokens,
  int projectId,
);

/// Opens a link share as a guest account: one per share and server, so the
/// same link opened again replaces the guest's session instead of adding a
/// second one. The hash and the token go to secure storage, the share's
/// password only into the one request.
final class GuestSignIn {
  new({
    required this._gateway,
    required this._store,
    required this._sessions,
    required this._registry,
    required this._connector,
    required this._landing,
    required this._projectTitle,
    AccountDatabaseFiles? files,
    this._diagnostics,
    this._clock = DateTime.now,
  }) : _files = files ?? PathProviderAccountDatabaseFiles();

  final LinkShareGateway _gateway;
  final LinkShareStore _store;
  final LinkShareSessions _sessions;
  final AccountRegistry _registry;
  final ServerConnector _connector;
  final GuestLandings _landing;
  final SharedProjectTitle _projectTitle;
  final AccountDatabaseFiles _files;
  final SessionDiagnostics? _diagnostics;
  final DateTime Function() _clock;

  /// The server behind [link]: a stored account's server on the link's own
  /// origin whose web frontend is the link's base, else the link's base
  /// probed like an address typed on the Connect screen, or [serverAddress]
  /// when given. Throws a `ServerConnectionFailure` when nothing answers
  /// there, which happens when the web frontend runs on another host than
  /// the API: then ask for the server's address, offering
  /// [serverClaiming], and call again with it. The connection may be
  /// insecure (`isInsecure`), which needs the user's consent first.
  Future<ServerConnection> connect(
    ParsedLinkShareUrl link, {
    String? serverAddress,
    CancelToken? cancelToken,
  }) async {
    final linkOrigin = OriginKey.tryOf(link.base);
    if (serverAddress == null && linkOrigin != null) {
      for (final entry in (await _registry.load()).accounts) {
        if (_frontendOf(entry.connection) == link.base &&
            OriginKey.tryOf(entry.connection.rootUri) == linkOrigin) {
          return entry.connection;
        }
      }
    }
    return await _connector.connect(
      serverAddress ?? link.base.toString(),
      cancelToken: cancelToken,
    );
  }

  /// The root of a stored account's server whose `/info` names [link]'s
  /// base as its web frontend. Only that server says so, and any server
  /// can name another's host, so it is offered for the link but the hash
  /// goes there only once the user confirmed it.
  Future<Uri?> serverClaiming(ParsedLinkShareUrl link) async {
    for (final entry in (await _registry.load()).accounts) {
      if (_frontendOf(entry.connection) == link.base) {
        return entry.connection.rootUri;
      }
    }
    return null;
  }

  /// Authenticates with [link]'s hash and, with [password] when the share
  /// has one, kept on the device only with [rememberPassword], stores the
  /// guest and makes it active, remembering the link's
  /// project and view for the first screen. [beforeActivatingExisting] runs
  /// for a share already on this device before it becomes active again.
  /// [commit] is asked once the server has answered with a token, before
  /// anything is stored: false ends it as [GuestSignInCancelled], and after
  /// true it runs to its end. Throws [SignOutStillFinishing] while the
  /// database of the same guest's sign-out is still held.
  Future<GuestSignInResult> signIn(
    ServerConnection connection,
    ParsedLinkShareUrl link, {
    String? password,
    bool rememberPassword = false,
    Future<void> Function(String accountId)? beforeActivatingExisting,
    bool Function()? commit,
  }) => _open(
    connection,
    link,
    password: password,
    rememberPassword: rememberPassword,
    beforeActivatingExisting: beforeActivatingExisting,
    commit: commit,
    land: true,
    reopening: false,
  );

  Future<GuestSignInResult> _open(
    ServerConnection connection,
    ParsedLinkShareUrl link, {
    required String? password,
    required bool land,
    required bool reopening,
    bool rememberPassword = false,
    Future<void> Function(String accountId)? beforeActivatingExisting,
    bool Function()? commit,
  }) async {
    // A stored account's `/info` can be hours old (it is read again at most
    // every few hours while signed in), so only a fresh probe may save the
    // request; the server's 404 without a code says the same.
    if (!connection.capabilities.has(Capability.linkSharing) &&
        !await _hasStoredAccountOn(connection.rootUri)) {
      return const GuestLinkGone(sharingOff: true);
    }
    final LinkShareAuth auth;
    try {
      auth = await _gateway.authenticate(
        connection,
        link.hash,
        password: password,
      );
    } on LinkShareGone catch (failure) {
      _log.info('The link share is gone: $failure');
      return GuestLinkGone(sharingOff: failure.code == null);
    } on VikunjaFailure catch (failure) {
      if (failure.code
          case LinkShareCodes.passwordRequired ||
              LinkShareCodes.wrongPassword) {
        return GuestPasswordRequired(
          wrongPassword: failure.code == LinkShareCodes.wrongPassword,
        );
      }
      _log.info('Opening the link share failed: $failure');
      return GuestSignInFailed(failure);
    }
    final receivedAt = _clock();
    // The only cancel point: once something is stored, undoing it could
    // leave the long-lived hash behind or a replaced session gone.
    if (commit != null && !commit()) {
      _log.info('Opening the link share was cancelled');
      return const GuestSignInCancelled();
    }

    final accountId = linkShareAccountIdFor(connection.rootUri, auth.shareId);
    // One at a time with the guest's sign-out (decision log: Several
    // accounts).
    return await _sessions.exclusive(accountId, () async {
      await settleSignedOutDatabases(_files, accountId: accountId);
      if (reopening && await _registry.find(accountId) == null) {
        _log.info('Guest $accountId was removed while its link opened');
        return const GuestSignInCancelled();
      }
      await _store.write(accountId, hash: link.hash, token: auth.token.jwt);
      await _store.writePassword(accountId, rememberPassword ? password : null);
      await _settleEnded(accountId);
      // The old session goes only now: retired before, it would answer the
      // requests in between as ended, which pauses the outbox. A token it
      // still writes is one of the same share, which renewal does not rotate.
      final session = _sessions.signedIn(
        accountId,
        auth.token,
        receivedAt: receivedAt,
      );

      final existing = await _registry.find(accountId);
      final title = await _titleOf(connection, session, auth.projectId);
      if (existing != null) await beforeActivatingExisting?.call(accountId);
      final entry = RegisteredAccount(
        account: Account.linkShare(
          id: accountId,
          serverRoot: connection.rootUri,
          shareId: auth.shareId,
          projectId: auth.projectId,
          shareName: auth.name,
          displayName:
              auth.name ??
              title ??
              existing?.account.displayName ??
              'link-share-${auth.shareId}',
          addedAt: existing?.account.addedAt ?? receivedAt.toUtc(),
        ),
        connection: connection,
      );
      if (land) {
        _landing.remember(
          accountId,
          GuestLanding(projectId: auth.projectId, viewId: link.viewId),
        );
      }
      if (!reopening) {
        await _registry.upsert(entry, activate: true);
      } else if (!await _registry.replace(entry)) {
        // Removed by another isolate after the check above. Only what this
        // call stored goes: a sign-in that stored the guest again keeps its
        // own session and link.
        await session.retire();
        if ((await _store.read(accountId))?.token == auth.token.jwt) {
          await _store.delete(accountId);
        }
        _log.info('Guest $accountId was removed while its link opened');
        return const GuestSignInCancelled();
      }
      _log.info('Opened link share as guest $accountId');
      return GuestSignedIn(entry, isNewAccount: existing == null);
    });
  }

  /// The stored link of a guest, to open it again once its session ended;
  /// null when it is no guest or its hash is gone.
  Future<ParsedLinkShareUrl?> storedLink(String accountId) async {
    final entry = await _registry.find(accountId);
    if (entry == null || !entry.account.isLinkShare) return null;
    final stored = await _store.read(accountId);
    if (stored == null) return null;
    return ParsedLinkShareUrl(
      base: _frontendOf(entry.connection),
      hash: stored.hash,
    );
  }

  /// [signIn] with a guest's stored link and server, without a landing and
  /// without activating the guest: the user stays on the screen that
  /// offered to open the link again, or on the account switched to
  /// meanwhile. A guest removed meanwhile stays removed, without its hash,
  /// as [GuestSignInCancelled] (decision log: Several accounts).
  Future<GuestSignInResult> reopen(
    String accountId, {
    String? password,
    bool rememberPassword = false,
  }) async {
    final entry = await _registry.find(accountId);
    final link = await storedLink(accountId);
    if (entry == null || link == null) return const GuestLinkGone();
    return await _open(
      entry.connection,
      link,
      password: password,
      rememberPassword: rememberPassword,
      land: false,
      reopening: true,
    );
  }

  /// The link reads and writes again, and an ended session is replaced.
  /// Before the guest is unmarked: a record left open would let the
  /// session check restore a guest marked later for a gone share, which
  /// leaves no record.
  Future<void> _settleEnded(String accountId) async {
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;
    await diagnostics.noteReadable(accountId);
    final ended = await diagnostics.lastEnd(accountId);
    if (ended == null || ended.resolution != null) return;
    await diagnostics.recordEnd(
      accountId,
      ended.resolved(SessionEndResolution.unknown),
    );
  }

  /// Only for the account's name; the guest works without it.
  Future<String?> _titleOf(
    ServerConnection connection,
    AccessTokenSource session,
    int projectId,
  ) async {
    try {
      final title = await _projectTitle(connection, session, projectId);
      return title == null || title.trim().isEmpty ? null : title;
    } on Object catch (error) {
      _log.info('No title for the shared project: ${error.runtimeType}');
      return null;
    }
  }

  Future<bool> _hasStoredAccountOn(Uri serverRoot) async =>
      (await _registry.load()).accounts.any(
        (entry) => entry.connection.rootUri == serverRoot,
      );

  static Uri _frontendOf(ServerConnection connection) => webFrontendBase(
    serverRoot: connection.rootUri,
    frontendUrl: connection.info.frontendUrl,
  );
}

/// The shared project's title, read with the guest's fresh token over
/// [base]'s adapter, for the name of a share that has none.
SharedProjectTitle readSharedProjectTitle(Dio base) =>
    (connection, tokens, projectId) async {
      final dio = createAuthenticatedDio(
        base: base,
        connection: connection,
        tokens: tokens,
      );
      try {
        final project = await createReadClient(
          dio: dio,
          connection: connection,
        ).projects.read(projectId);
        return project.title;
      } finally {
        dio.close();
      }
    };

@riverpod
SharedProjectTitle sharedProjectTitle(Ref ref) =>
    readSharedProjectTitle(ref.watch(dioProvider));

@riverpod
GuestSignIn guestSignIn(Ref ref) => GuestSignIn(
  gateway: ref.watch(linkShareGatewayProvider),
  store: ref.watch(linkShareStoreProvider),
  sessions: ref.watch(linkShareSessionsProvider),
  registry: ref.watch(accountRegistryProvider),
  connector: ref.watch(serverConnectorProvider),
  landing: ref.watch(guestLandingsProvider),
  projectTitle: ref.watch(sharedProjectTitleProvider),
  files: ref.watch(accountDatabaseFilesProvider),
  diagnostics: ref.watch(sessionDiagnosticsProvider),
);
