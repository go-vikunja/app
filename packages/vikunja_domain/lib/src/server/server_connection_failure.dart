import 'package:meta/meta.dart';

/// Why connecting to a server address failed. A server that is Vikunja but
/// too old is not a failure: it yields a connection with
/// `SupportTier.unsupported` so the UI can show what was found.
@immutable
sealed class ServerConnectionFailure implements Exception {
  const new(this.uri);

  /// The address that was probed last, or null for unparseable input.
  final Uri? uri;
}

final class InvalidServerAddress extends ServerConnectionFailure {
  const new(this.input) : super(null);

  final String input;

  @override
  String toString() => 'InvalidServerAddress($input)';
}

/// DNS lookup failed, the connection was refused, or the network is down.
final class ServerUnreachable extends ServerConnectionFailure {
  const new(Uri super.uri, {this.cause});

  final Object? cause;

  @override
  String toString() => 'ServerUnreachable($uri, $cause)';
}

final class ServerTimeout extends ServerConnectionFailure {
  const new(Uri super.uri);

  @override
  String toString() => 'ServerTimeout($uri)';
}

/// The TLS handshake failed, typically an untrusted or expired certificate.
final class TlsFailure extends ServerConnectionFailure {
  const new(
    Uri super.uri, {
    this.cause,
    this.certificateRejected = false,
    this.clientCertificateRefused = false,
  });

  final Object? cause;

  /// The server's certificate was refused, so a TLS server did answer. False
  /// for protocol mismatches such as plain http on the port.
  final bool certificateRejected;

  /// The server refused this device's client certificate, or wants one and
  /// got none. A TLS server answered; never set with [certificateRejected].
  final bool clientCertificateRefused;

  @override
  String toString() =>
      'TlsFailure($uri, $cause, certificateRejected: $certificateRejected, '
      'clientCertificateRefused: $clientCertificateRefused)';
}

enum ConnectionSettingsProblem { cleartextBlocked, locked, incomplete, damaged }

/// The stored connection settings of the origin stopped the request before
/// it left the device.
final class ConnectionSettingsFailure extends ServerConnectionFailure {
  const new(Uri super.uri, {required this.problem});

  final ConnectionSettingsProblem problem;

  @override
  String toString() => 'ConnectionSettingsFailure($uri, $problem)';
}

/// Something answered, but not with a Vikunja `/info` document.
final class NotAVikunjaServer extends ServerConnectionFailure {
  const new(Uri super.uri, {this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'NotAVikunjaServer($uri, status: $statusCode)';
}

/// A 5xx or 429 instead of `/info`: Vikunja is down, restarting or rate
/// limiting, or the reverse proxy in front of it cannot reach it.
final class ServerUnavailable extends ServerConnectionFailure {
  const new(Uri super.uri, {required this.statusCode, this.retryAfter});

  final int statusCode;
  final Duration? retryAfter;

  @override
  String toString() =>
      'ServerUnavailable($uri, status: $statusCode, retryAfter: $retryAfter)';
}

/// A reverse proxy demands its own authentication (forward-auth redirect to
/// an identity provider, or HTTP Basic auth) before Vikunja can be reached.
final class BehindLoginProxy extends ServerConnectionFailure {
  const new(Uri super.uri, {this.redirectTarget});

  final Uri? redirectTarget;

  @override
  String toString() => 'BehindLoginProxy($uri, redirect: $redirectTarget)';
}
