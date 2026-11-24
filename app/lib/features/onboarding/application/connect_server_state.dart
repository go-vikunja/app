import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';

@immutable
sealed class ConnectServerState {
  const new();
}

final class ConnectServerIdle extends ConnectServerState {
  const new();
}

enum ConnectTarget { server, sharedLink, invite }

final class ConnectServerConnecting extends ConnectServerState {
  const new(
    this.input, {
    this.target = ConnectTarget.server,
    this.cancellable = true,
  });

  /// What is being opened, without a link's secret: the address as entered,
  /// a shared link shortened, or an invite's web address without its token.
  final String input;
  final ConnectTarget target;

  /// False once the server has answered a shared link: the guest is then
  /// stored and kept, so neither Cancel nor Close may end it.
  final bool cancellable;

  ConnectServerConnecting get committed =>
      ConnectServerConnecting(input, target: target, cancellable: false);
}

/// Found a Vikunja server over plain http; the user has to accept the risk.
final class ConnectServerAwaitingInsecureConsent extends ConnectServerState {
  const new(this.connection, {this.httpsFailed = false});

  final ServerConnection connection;

  /// The address was typed without a scheme and https did not connect, so
  /// the server answered over http in its place.
  final bool httpsFailed;
}

final class ConnectServerFailed extends ConnectServerState {
  const new({required this.input, this.failure});

  /// Shown in the message: for a link only the server's part of it.
  final String input;

  /// Null when the connector failed in an unexpected way.
  final ServerConnectionFailure? failure;
}

final class ConnectServerConnected extends ConnectServerState {
  const new(this.connection);

  final ServerConnection connection;
}

enum InviteCheck {
  passed,

  /// The server has no invite check: older than 2.7.0, or without
  /// `/api/v2` or local accounts.
  unavailable,

  /// The check failed in another way, e.g. offline.
  failed,
}

/// An admin's registration invite, checked on its server as far as it
/// could be.
final class ConnectServerInviteFound extends ConnectServerState {
  const new(this.connection, this.invite, {required this.check, this.preview});

  final ServerConnection connection;
  final ParsedInviteLink invite;
  final InviteCheck check;

  /// Only when [check] passed.
  final InvitePreview? preview;
}

/// A shared link or an invite was refused, or opening it failed in a way
/// that is not about reaching the server: a `VikunjaFailure` (an invite
/// refused is a `NotFound` code 2005, a link share gone a
/// `LinkShareGone`), a `GuestServerUnsupported` when a shared link's server
/// is below the support floor, or anything unexpected.
final class ConnectServerLinkFailed extends ConnectServerState {
  const new({required this.serverRoot, required this.error});

  final Uri serverRoot;
  final Object error;
}

/// A shared link's own address answered, but not as a Vikunja server: its
/// web frontend runs apart from the API, whose address the user enters
/// next to open the link.
final class ConnectServerShareNeedsServer extends ConnectServerState {
  const new({
    required this.linkBase,
    required this.failure,
    this.claimingServer,
    this.addressFailed,
  });

  final Uri linkBase;
  final ServerConnectionFailure failure;

  /// A stored account's server that names [linkBase] as its web frontend,
  /// offered as the address; the link goes there only once the user
  /// continues with it.
  final Uri? claimingServer;

  /// The address last given for the link and why it failed; the link still
  /// waits, for that address again or another.
  final ConnectServerFailed? addressFailed;

  ConnectServerShareNeedsServer withAddressFailed(ConnectServerFailed failed) =>
      ConnectServerShareNeedsServer(
        linkBase: linkBase,
        failure: failure,
        claimingServer: claimingServer,
        addressFailed: failed,
      );
}

/// The shared project has a password, which the screen asks for, naming
/// [serverRoot]'s host, where the password goes.
final class ConnectServerSharePasswordNeeded extends ConnectServerState {
  const new(this.serverRoot);

  final Uri serverRoot;
}

enum SharePasswordOutcome { accepted, wrong, failed }

/// The shared link opened as a guest account, which is now active.
final class ConnectServerGuestSignedIn extends ConnectServerState {
  const new(this.account, {required this.isNewAccount});

  final RegisteredAccount account;

  /// False when the link was opened on this device before; only its
  /// session was replaced.
  final bool isNewAccount;
}
