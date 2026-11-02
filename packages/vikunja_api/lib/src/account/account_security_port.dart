import 'package:dio/dio.dart';
import 'package:vikunja_api/src/account/account_security_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The signed-in user's two-factor status, sessions, API and CalDAV tokens
/// and data export, on `/api/v2` from 2.4.0 and `/api/v1` before. Every
/// call needs a user session: an API token gets `TokenRejected`. None needs
/// a password or a TOTP code (D14). Lists read every page, at most 20.
abstract interface class AccountSecurityPort {
  /// `GET /user/settings/totp`; 412 code 1016 is [TotpStatus.notSetUp].
  /// Only whether a secret is present is read, never the secret or its
  /// url. An account managed by OIDC or LDAP is a `DomainError` 412 code
  /// 1021; a server with TOTP turned off has no route (`NotFound` with
  /// `routeAbsent`).
  Future<TotpStatus> totpStatus();

  /// `GET /user/sessions`, most recently active first. Nothing marks the
  /// caller's own session: it is the `sid` claim of the access token.
  Future<List<UserSession>> sessions();

  /// `DELETE /user/sessions/{id}`. A session that is gone already (404 code
  /// 16001) counts as ended. The session's refresh fails at once, its
  /// access token keeps working for up to ten minutes. Another user's
  /// session is a `Forbidden`.
  Future<void> revokeSession(String id);

  /// `GET /tokens`, oldest first, without the tokens' values.
  Future<List<ApiToken>> apiTokens();

  /// `GET /routes`: what this server lets tokens do.
  Future<ApiPermissionGroups> apiPermissions();

  /// v2 `POST /tokens`, v1 `PUT /tokens`; never retried, since only this
  /// answer carries the value. A blank title or an expiry that is not in
  /// the future, both of which the server accepts, is an [ArgumentError]
  /// before any request. No permission or no title is a `ValidationFailed`
  /// (v1 412 code 2002, v2 422), a permission the server does not offer a
  /// `DomainError` 400 code 14002.
  Future<CreatedApiToken> createApiToken(NewApiToken token);

  /// `DELETE /tokens/{id}`. Another user's token is a `Forbidden`, and so is
  /// an unknown id up to 2.7.0; from 2.7.1 an unknown id, a token deleted
  /// already among them, is a 404 code 14017, which counts as deleted.
  Future<void> deleteApiToken(int id);

  /// `GET /user/settings/token/caldav`, oldest first, without the values.
  /// The endpoints exist even when the server's CalDAV is off.
  Future<List<CaldavToken>> caldavTokens();

  /// v2 `POST`, v1 `PUT /user/settings/token/caldav`; never retried.
  Future<CreatedCaldavToken> createCaldavToken();

  /// `DELETE /user/settings/token/caldav/{id}`; the server answers an
  /// unknown id like a deleted one.
  Future<void> deleteCaldavToken(int id);

  /// `GET /user/export`; null when there is none. Requesting and
  /// downloading one need the password, so they belong to the web.
  Future<UserDataExport?> dataExport();
}

/// Over [dio] and [connection] like `createUserSettingsWritePort`.
AccountSecurityPort createAccountSecurityPort({
  required Dio dio,
  required ServerConnection connection,
}) => AccountSecurityApi(dio: dio, connection: connection);
