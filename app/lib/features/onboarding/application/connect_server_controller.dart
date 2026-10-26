import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';

export 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';

part 'connect_server_controller.g.dart';

const publicDemoAddress = 'https://try.vikunja.io';

final _log = Logger('ConnectServer');

const _inviteInvalid = 2005;

typedef InviteLinksPortFactory = InviteLinksPort Function(
  ServerConnection connection,
);

/// Checks admins' registration invites on a server, without an account.
@riverpod
InviteLinksPortFactory inviteLinksPorts(Ref ref) {
  final dio = ref.watch(dioProvider);
  return (connection) =>
      createInviteLinksPort(dio: dio, connection: connection);
}

/// The web address of [invite], where the browser registers with it.
Uri inviteUrl(ParsedInviteLink invite) => Uri.parse(
  '${invite.base}register#invite-link=${Uri.encodeComponent(invite.token)}',
);

/// A server's address, an admin's registration invite (checked on its
/// server) or a shared project's link (opened as a guest), from the
/// address field, the shared-link sheet or another app's share. The
/// secrets of links stay in this controller, never in its state.
@riverpod
class ConnectServerController extends _$ConnectServerController {
  CancelToken? _cancelToken;

  /// What runs once the user accepted a plain http server, when that is
  /// more than taking the server.
  Future<ConnectServerState> Function(ServerConnection connection)?
  _afterConsent;

  /// The shared link being opened, while it waits for its password or its
  /// server's address.
  ParsedLinkShareUrl? _share;
  ServerConnection? _shareConnection;

  @override
  ConnectServerState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const ConnectServerIdle();
  }

  /// With [forPendingShare], an address the user gave for the shared link
  /// that waits for its server; any other input forgets that link, whose
  /// secret goes to no other server.
  Future<void> connect(String input, {bool forPendingShare = false}) async {
    if (state is ConnectServerConnecting) return;
    final share = parseLinkShareUrl(input);
    final invite = share == null ? parseInviteLink(input) : null;
    final shareAwaitingServer =
        forPendingShare && state is ConnectServerShareNeedsServer
        ? _share
        : null;
    final cancelToken = _cancelToken = CancelToken();
    _forgetLink();
    ref.read(currentServerProvider.notifier).clear();
    state = switch ((share, invite)) {
      (final share?, _) => ConnectServerConnecting(
        share.shortened,
        target: ConnectTarget.sharedLink,
      ),
      (_, final invite?) => ConnectServerConnecting(
        '${invite.base}',
        target: ConnectTarget.invite,
      ),
      _ => ConnectServerConnecting(input),
    };

    final outcome = switch ((share, invite, shareAwaitingServer)) {
      (final share?, _, _) => await _openShare(share, cancelToken),
      (_, final invite?, _) => await _openInvite(invite, cancelToken),
      (_, _, final share?) => await _openShare(
        share,
        cancelToken,
        serverAddress: input,
      ),
      _ => await _probe(input, cancelToken),
    };
    if (!ref.mounted || cancelToken.isCancelled) return;
    _cancelToken = null;
    _apply(outcome);
  }

  Future<ConnectServerState> _probe(
    String input,
    CancelToken cancelToken,
  ) async {
    try {
      final connection = await ref
          .read(serverConnectorProvider)
          .connect(input, cancelToken: cancelToken);
      return connection.isInsecure
          ? ConnectServerAwaitingInsecureConsent(connection)
          : ConnectServerConnected(connection);
    } on ServerConnectionFailure catch (failure) {
      return ConnectServerFailed(input: input, failure: failure);
    } on Object catch (error, stackTrace) {
      if (!cancelToken.isCancelled) _logUnexpected(error, stackTrace);
      return ConnectServerFailed(input: input);
    }
  }

  Future<ConnectServerState> _openInvite(
    ParsedInviteLink invite,
    CancelToken cancelToken,
  ) async {
    final probed = await _probe(invite.base.toString(), cancelToken);
    if (cancelToken.isCancelled) return probed;
    if (probed case ConnectServerConnected(:final connection)) {
      return await _checkInvite(connection, invite);
    }
    if (probed is ConnectServerAwaitingInsecureConsent) {
      // Its token goes to the server only once the user accepted http.
      _afterConsent = (connection) => _checkInvite(connection, invite);
    }
    return probed;
  }

  Future<ConnectServerState> _checkInvite(
    ServerConnection connection,
    ParsedInviteLink invite,
  ) async {
    final port = ref.read(inviteLinksPortsProvider)(connection);
    try {
      final preview = await port.check(invite.token);
      return ConnectServerInviteFound(
        connection,
        invite,
        check: InviteCheck.passed,
        preview: preview,
      );
    } on NotFound catch (failure) {
      if (failure.code == _inviteInvalid) {
        _log.info('The invite was refused');
        return ConnectServerLinkFailed(
          serverRoot: connection.rootUri,
          error: failure,
        );
      }
      return ConnectServerInviteFound(
        connection,
        invite,
        check: InviteCheck.unavailable,
      );
    } on Object catch (error) {
      _log.info('Checking the invite failed: ${error.runtimeType}');
      return ConnectServerInviteFound(
        connection,
        invite,
        check: InviteCheck.failed,
      );
    }
  }

  Future<ConnectServerState> _openShare(
    ParsedLinkShareUrl share,
    CancelToken cancelToken, {
    String? serverAddress,
  }) async {
    final ServerConnection connection;
    try {
      connection = await ref
          .read(guestSignInProvider)
          .connect(
            share,
            serverAddress: serverAddress,
            cancelToken: cancelToken,
          );
    } on ServerConnectionFailure catch (failure) {
      if (failure is NotAVikunjaServer && serverAddress == null) {
        // The web frontend can run on a host of its own, apart from the API.
        _share = share;
        return ConnectServerShareNeedsServer(
          linkBase: share.base,
          failure: failure,
        );
      }
      return ConnectServerFailed(
        input: serverAddress ?? share.base.toString(),
        failure: failure,
      );
    } on Object catch (error, stackTrace) {
      if (!cancelToken.isCancelled) _logUnexpected(error, stackTrace);
      return ConnectServerFailed(input: serverAddress ?? share.base.toString());
    }
    if (cancelToken.isCancelled) return const ConnectServerIdle();
    if (connection.isInsecure) {
      _afterConsent = (connection) => _signInAsGuest(connection, share);
      return ConnectServerAwaitingInsecureConsent(connection);
    }
    return await _signInAsGuest(connection, share);
  }

  Future<ConnectServerState> _signInAsGuest(
    ServerConnection connection,
    ParsedLinkShareUrl share, {
    String? password,
  }) async {
    final container = ref.container;
    final GuestSignInResult result;
    try {
      result = await ref
          .read(guestSignInProvider)
          .signIn(
            connection,
            share,
            password: password,
            // Opened again, the guest becomes active at once, like a switch.
            beforeActivatingExisting: (accountId) =>
                prepareSyncStatus(container, accountId),
          );
    } on Object catch (error, stackTrace) {
      _logUnexpected(error, stackTrace);
      return ConnectServerLinkFailed(
        serverRoot: connection.rootUri,
        error: error,
      );
    }
    switch (result) {
      case GuestSignedIn(:final account, :final isNewAccount):
        _forgetLink();
        return ConnectServerGuestSignedIn(account, isNewAccount: isNewAccount);
      case GuestPasswordRequired():
        _share = share;
        _shareConnection = connection;
        return ConnectServerSharePasswordNeeded(connection.rootUri);
      case GuestLinkGone():
        _forgetLink();
        return ConnectServerLinkFailed(
          serverRoot: connection.rootUri,
          error: result,
        );
      case GuestSignInFailed(:final failure):
        _forgetLink();
        return ConnectServerLinkFailed(
          serverRoot: connection.rootUri,
          error: failure,
        );
    }
  }

  /// One try of the shared project's password; the state follows unless
  /// the password was wrong.
  Future<SharePasswordOutcome> submitSharePassword(String password) async {
    final share = _share;
    final connection = _shareConnection;
    if (state is! ConnectServerSharePasswordNeeded ||
        share == null ||
        connection == null) {
      return SharePasswordOutcome.failed;
    }
    final next = await _signInAsGuest(connection, share, password: password);
    if (!ref.mounted) return SharePasswordOutcome.failed;
    if (next is ConnectServerSharePasswordNeeded) {
      return SharePasswordOutcome.wrong;
    }
    _apply(next);
    return next is ConnectServerGuestSignedIn
        ? SharePasswordOutcome.accepted
        : SharePasswordOutcome.failed;
  }

  void cancel() {
    final cancelToken = _cancelToken;
    if (cancelToken == null) return;
    _cancelToken = null;
    cancelToken.cancel();
    _forgetLink();
    state = const ConnectServerIdle();
  }

  Future<void> acceptInsecureConnection() async {
    if (state case ConnectServerAwaitingInsecureConsent(:final connection)) {
      final next = _afterConsent;
      _afterConsent = null;
      if (next == null) {
        _apply(ConnectServerConnected(connection));
        return;
      }
      final cancelToken = _cancelToken = CancelToken();
      state = ConnectServerConnecting(connection.rootUri.toString());
      final outcome = await next(connection);
      if (!ref.mounted || cancelToken.isCancelled) return;
      _cancelToken = null;
      _apply(outcome);
    }
  }

  void declineInsecureConnection() {
    if (state is ConnectServerAwaitingInsecureConsent) reset();
  }

  /// From an invite to the server's overview, for the sign-in once the
  /// account exists.
  void continueToSignIn() {
    if (state case ConnectServerInviteFound(:final connection)) {
      _apply(ConnectServerConnected(connection));
    }
  }

  void reset() {
    if (state is ConnectServerConnecting) return;
    _forgetLink();
    state = const ConnectServerIdle();
  }

  void _forgetLink() {
    _afterConsent = null;
    _share = null;
    _shareConnection = null;
  }

  void _apply(ConnectServerState next) {
    if (next is ConnectServerConnected) {
      ref.read(currentServerProvider.notifier).select(next.connection);
    }
    state = next;
  }

  void _logUnexpected(Object error, StackTrace stackTrace) => _log.severe(
    'Unexpected connect failure: ${redactSecrets('$error')}',
    null,
    stackTrace,
  );
}
