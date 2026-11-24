import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';

/// The OAuth token endpoint. Throws `VikunjaFailure`.
abstract interface class TokenGateway {
  Future<TokenSet> exchangeCode(
    ServerConnection connection, {
    required String code,
    required AuthorizationRequest request,
  });

  Future<TokenSet> refresh(ServerConnection connection, String refreshToken);
}

/// Account endpoints called with an account's tokens. Throws
/// `VikunjaFailure`.
abstract interface class AccountGateway {
  Future<User> currentUser(
    ServerConnection connection,
    AccessTokenSource tokens,
  );

  /// The same `GET /user`, with the settings it carries.
  Future<UserWithSettings> currentUserWithSettings(
    ServerConnection connection,
    AccessTokenSource tokens,
  );

  /// The same `GET /user`, with the settings and the profile.
  Future<UserWithProfile> currentUserWithProfile(
    ServerConnection connection,
    AccessTokenSource tokens,
  );

  Future<void> logout(ServerConnection connection, AccessTokenSource tokens);

  /// `GET /user/sessions`.
  Future<List<UserSession>> sessions(
    ServerConnection connection,
    AccessTokenSource tokens,
  );

  /// `DELETE /user/sessions/{id}`; one that is gone already counts as done.
  Future<void> revokeSession(
    ServerConnection connection,
    AccessTokenSource tokens,
    String sessionId,
  );
}

final class ApiTokenGateway implements TokenGateway {
  /// The Dio must not carry an auth interceptor. `timeout` gives the bound
  /// on sending and receiving each token request when it is sent.
  new(this._dio, {this._timeout = _sixtySeconds});

  static Duration _sixtySeconds() => const Duration(seconds: 60);

  final Dio _dio;
  final Duration Function() _timeout;

  @override
  Future<TokenSet> exchangeCode(
    ServerConnection connection, {
    required String code,
    required AuthorizationRequest request,
  }) => OAuthTokenClient(
    _dio,
    connection,
    timeout: _timeout(),
  ).exchangeCode(code: code, request: request);

  @override
  Future<TokenSet> refresh(ServerConnection connection, String refreshToken) =>
      OAuthTokenClient(
        _dio,
        connection,
        timeout: _timeout(),
      ).refresh(refreshToken);
}

final class ApiAccountGateway implements AccountGateway {
  new(this._base, {this._logRequests = kDebugMode});

  final Dio _base;
  final bool _logRequests;

  Dio _dio(ServerConnection connection, AccessTokenSource tokens) =>
      createAuthenticatedDio(
        base: _base,
        connection: connection,
        tokens: tokens,
        // Only maps a guest's gone share: the session check ends the guest
        // itself.
        interceptors: [
          LinkShareGoneInterceptor(),
          if (_logRequests) RequestLogInterceptor(),
        ],
      );

  AccountApi _api(ServerConnection connection, AccessTokenSource tokens) =>
      AccountApi(_dio(connection, tokens), connection);

  AccountSecurityPort _security(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => createAccountSecurityPort(
    dio: _dio(connection, tokens),
    connection: connection,
  );

  @override
  Future<User> currentUser(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => _api(connection, tokens).currentUser();

  @override
  Future<UserWithSettings> currentUserWithSettings(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => _api(connection, tokens).currentUserWithSettings();

  @override
  Future<UserWithProfile> currentUserWithProfile(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => _api(connection, tokens).currentUserWithProfile();

  @override
  Future<void> logout(ServerConnection connection, AccessTokenSource tokens) =>
      _api(connection, tokens).logout();

  @override
  Future<List<UserSession>> sessions(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) => _security(connection, tokens).sessions();

  @override
  Future<void> revokeSession(
    ServerConnection connection,
    AccessTokenSource tokens,
    String sessionId,
  ) => _security(connection, tokens).revokeSession(sessionId);
}
