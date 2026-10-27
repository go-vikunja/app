// Thrown by the app's transport inside a connection error. Their toString
// names only the class and the origin: no header value, certificate byte or
// password may ever reach a log through them.

/// A request to an `http://` or `ws://` origin the user has not allowed
/// unencrypted connections to.
final class CleartextBlockedException implements Exception {
  const new(this.origin);

  final String origin;

  @override
  String toString() => 'CleartextBlockedException($origin)';
}

/// Secure storage is not readable yet (before the first unlock) or failed;
/// transient, like a locked Keychain (D24).
final class ConnectionProfileLockedException implements Exception {
  const new(this.origin);

  final String origin;

  @override
  String toString() => 'ConnectionProfileLockedException($origin)';
}

/// The stored secrets are missing, do not match the metadata, or were
/// refused by the transport, so the settings need to be entered again.
final class ConnectionProfileIncompleteException implements Exception {
  const new(this.origin);

  final String origin;

  @override
  String toString() => 'ConnectionProfileIncompleteException($origin)';
}

/// The stored connection settings cannot be read at all; every request fails
/// until the user resets them.
final class ConnectionProfilesDamagedException implements Exception {
  const new();

  @override
  String toString() => 'ConnectionProfilesDamagedException';
}

/// The server closed the connection right after the TLS handshake, and a
/// handshake-only check confirmed it: it refuses this device's client
/// certificate, or wants one and got none.
final class ClientCertificateRefusedException implements Exception {
  const new(this.origin);

  final String origin;

  @override
  String toString() => 'ClientCertificateRefusedException($origin)';
}
