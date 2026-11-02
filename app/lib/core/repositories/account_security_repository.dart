import 'package:vikunja_domain/vikunja_domain.dart';

/// The account's two-factor status, sessions, API and CalDAV tokens and data
/// export on the server. Online only and never stored: every call goes to
/// the server and throws its `VikunjaFailure` (offline a `NetworkFailure`).
/// The value of a new token exists only in the create answer; the caller
/// shows it once and drops it.
abstract interface class AccountSecurityRepository {
  /// A codeless `NotFound` when the server has two-factor authentication
  /// off; `DomainError` code 1021 for an account of a sign-in provider.
  Future<TotpStatus> totpStatus();

  /// Most recently active first, this app's own session among them.
  Future<List<UserSession>> sessions();

  /// This app's session: the `sid` of the account's access token, which a
  /// refresh keeps. Null when no token is stored (signed out). Reads the
  /// device, unless only a refresh token is stored.
  Future<String?> currentSessionId();

  /// That device or browser stays signed in until its access token
  /// expires, up to ten minutes. A session that is already gone counts as
  /// ended. [currentSessionId]'s own is an `ArgumentError` before any
  /// request: signing out is the way to end it.
  Future<void> revokeSession(String id);

  /// Ends every session except [currentSessionId]'s, one after the other,
  /// and returns how many ended. The first failure stops it as
  /// [OtherSessionsNotAllEnded]; reading the list can fail as
  /// [sessions] does.
  Future<int> revokeOtherSessions();

  Future<List<ApiToken>> apiTokens();

  /// What this server lets a token do; it differs between servers.
  Future<ApiPermissionGroups> apiPermissions();

  /// A blank title, no permission or an expiry that is not in the future is
  /// an `ArgumentError` before any request: the server would take a past
  /// date and make a token that never works. A permission the server does
  /// not know is a `DomainError` code 14002.
  Future<CreatedApiToken> createApiToken(NewApiToken token);

  /// Another user's token is a `Forbidden`, and so is an unknown id up to
  /// 2.7.0; from 2.7.1 an unknown id counts as deleted.
  Future<void> deleteApiToken(int id);

  Future<List<CaldavToken>> caldavTokens();
  Future<CreatedCaldavToken> createCaldavToken();

  /// An unknown id is a silent success, as on the server.
  Future<void> deleteCaldavToken(int id);

  /// Null when there is none: never requested, expired, or dropped early by
  /// the server's cleanup.
  Future<UserDataExport?> dataExport();
}

/// [AccountSecurityRepository.revokeOtherSessions] stopped at [failure]
/// after [ended] sessions had ended; [notEnded] others are still signed in,
/// the failed one included.
final class OtherSessionsNotAllEnded implements Exception {
  const new({
    required this.ended,
    required this.notEnded,
    required this.failure,
  });

  final int ended;
  final int notEnded;
  final VikunjaFailure failure;

  @override
  String toString() =>
      'OtherSessionsNotAllEnded(ended: $ended, notEnded: $notEnded, $failure)';
}
