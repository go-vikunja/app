import 'package:vikunja_domain/vikunja_domain.dart';

/// What the connect screen offers for a failure that the connection
/// settings of the failed origin can fix.
enum ConnectionFix {
  viewCertificate,
  addHeaders,
  clientCertificate,
  openSettings,

  /// Secure storage cannot be read yet: only trying again helps.
  retry,

  /// The stored settings are unreadable: only a reset of all of them helps.
  reset,
}

/// Null for failures no connection setting fixes. [error] is a
/// [ServerConnectionFailure] of the connector or a `VikunjaFailure` of a
/// later request.
ConnectionFix? connectionFixFor(Object? error) => switch (error) {
  TlsFailure(clientCertificateRefused: true) => ConnectionFix.clientCertificate,
  TlsFailure(certificateRejected: true) => ConnectionFix.viewCertificate,
  BehindLoginProxy() ||
  NotAVikunjaServer(statusCode: 401 || 403) => ConnectionFix.addHeaders,
  ConnectionSettingsFailure(problem: ConnectionSettingsProblem.locked) =>
    ConnectionFix.retry,
  ConnectionSettingsFailure(problem: ConnectionSettingsProblem.damaged) =>
    ConnectionFix.reset,
  ConnectionSettingsFailure() => ConnectionFix.openSettings,
  NetworkFailure(:final problem) => switch (problem) {
    NetworkProblem.unreachable || NetworkProblem.timeout => null,
    NetworkProblem.tls => ConnectionFix.viewCertificate,
    NetworkProblem.clientCertificate => ConnectionFix.clientCertificate,
    NetworkProblem.profileLocked => ConnectionFix.retry,
    NetworkProblem.profileDamaged => ConnectionFix.reset,
    NetworkProblem.cleartextBlocked ||
    NetworkProblem.profileIncomplete => ConnectionFix.openSettings,
  },
  _ => null,
};

/// Away from the connect screen, a failure whose fix is in the connection
/// settings opens them, except unreadable settings, which only a reset
/// fixes.
bool opensConnectionSettings(Object? error) => switch (error) {
  NetworkFailure(problem: NetworkProblem.profileDamaged) => false,
  NetworkFailure(problem: NetworkProblem.tls) => true,
  NetworkFailure(:final problem) => problem.concernsConnectionSettings,
  TlsFailure(certificateRejected: true) ||
  TlsFailure(clientCertificateRefused: true) => true,
  ConnectionSettingsFailure(problem: ConnectionSettingsProblem.damaged) =>
    false,
  ConnectionSettingsFailure() => true,
  _ => false,
};

bool needsConnectionSettingsReset(Object? error) => switch (error) {
  NetworkFailure(problem: NetworkProblem.profileDamaged) ||
  ConnectionSettingsFailure(problem: ConnectionSettingsProblem.damaged) => true,
  _ => false,
};
