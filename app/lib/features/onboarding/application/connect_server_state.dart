import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

@immutable
sealed class ConnectServerState {
  const new();
}

final class ConnectServerIdle extends ConnectServerState {
  const new();
}

final class ConnectServerConnecting extends ConnectServerState {
  const new(this.input);

  final String input;
}

/// Found a Vikunja server over plain http; the user has to accept the risk.
final class ConnectServerAwaitingInsecureConsent extends ConnectServerState {
  const new(this.connection);

  final ServerConnection connection;
}

final class ConnectServerFailed extends ConnectServerState {
  const new({required this.input, this.failure});

  final String input;

  /// Null when the connector failed in an unexpected way.
  final ServerConnectionFailure? failure;
}

final class ConnectServerConnected extends ConnectServerState {
  const new(this.connection);

  final ServerConnection connection;
}
