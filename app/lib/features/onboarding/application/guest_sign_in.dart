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
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_landing.dart';

part 'guest_sign_in.g.dart';

final _log = Logger('GuestSignIn');

@immutable
sealed class GuestSignInResult {
  const new();
}

/// The guest is stored and active.
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
    this._clock = DateTime.now,
  });

  final LinkShareGateway _gateway;
  final LinkShareStore _store;
  final LinkShareSessions _sessions;
  final AccountRegistry _registry;
  final ServerConnector _connector;
  final GuestLandings _landing;
  final SharedProjectTitle _projectTitle;
  final DateTime Function() _clock;

  /// The server behind [link]: a stored account's server whose web frontend
  /// is the link's base, else the link's base probed like an address typed
  /// on the Connect screen, or [serverAddress] when given. Throws a
  /// `ServerConnectionFailure` when nothing answers there, which happens
  /// when the web frontend runs on another host than the API: then ask for
  /// the server's address and call again with it. The connection may be
  /// insecure (`isInsecure`), which needs the user's consent first.
  Future<ServerConnection> connect(
    ParsedLinkShareUrl link, {
    String? serverAddress,
    CancelToken? cancelToken,
  }) async {
    if (serverAddress == null) {
      for (final entry in (await _registry.load()).accounts) {
        if (_frontendOf(entry.connection) == link.base) return entry.connection;
      }
    }
    return await _connector.connect(
      serverAddress ?? link.base.toString(),
      cancelToken: cancelToken,
    );
  }

  /// Authenticates with [link]'s hash and, with [password] when the share
  /// has one, stores the guest and makes it active, remembering the link's
  /// project and view for the first screen. [beforeActivatingExisting] runs
  /// for a share already on this device before it becomes active again.
  Future<GuestSignInResult> signIn(
    ServerConnection connection,
    ParsedLinkShareUrl link, {
    String? password,
    Future<void> Function(String accountId)? beforeActivatingExisting,
  }) => _open(
    connection,
    link,
    password: password,
    beforeActivatingExisting: beforeActivatingExisting,
    land: true,
  );

  Future<GuestSignInResult> _open(
    ServerConnection connection,
    ParsedLinkShareUrl link, {
    required String? password,
    required bool land,
    Future<void> Function(String accountId)? beforeActivatingExisting,
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
      if (failure.code case _passwordRequired || _wrongPassword) {
        return GuestPasswordRequired(
          wrongPassword: failure.code == _wrongPassword,
        );
      }
      _log.info('Opening the link share failed: $failure');
      return GuestSignInFailed(failure);
    }
    final receivedAt = _clock();

    final accountId = linkShareAccountIdFor(connection.rootUri, auth.shareId);
    await _store.write(accountId, hash: link.hash, token: auth.token.jwt);
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
    await _registry.upsert(entry, activate: true);
    _log.info('Opened link share as guest $accountId');
    return GuestSignedIn(entry, isNewAccount: existing == null);
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

  /// [signIn] with a guest's stored link and server, without a landing:
  /// the user stays on the screen that offered to open the link again.
  Future<GuestSignInResult> reopen(String accountId, {String? password}) async {
    final entry = await _registry.find(accountId);
    final link = await storedLink(accountId);
    if (entry == null || link == null) return const GuestLinkGone();
    return await _open(entry.connection, link, password: password, land: false);
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

  static const _passwordRequired = 13001;
  static const _wrongPassword = 13002;
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
);
