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
}

final class ApiTokenGateway implements TokenGateway {
  /// The Dio must not carry an auth interceptor.
  new(this._dio);

  final Dio _dio;

  @override
  Future<TokenSet> exchangeCode(
    ServerConnection connection, {
    required String code,
    required AuthorizationRequest request,
  }) => OAuthTokenClient(
    _dio,
    connection,
  ).exchangeCode(code: code, request: request);

  @override
  Future<TokenSet> refresh(ServerConnection connection, String refreshToken) =>
      OAuthTokenClient(_dio, connection).refresh(refreshToken);
}

final class ApiAccountGateway implements AccountGateway {
  new(this._base, {this._logRequests = kDebugMode});

  final Dio _base;
  final bool _logRequests;

  AccountApi _api(ServerConnection connection, AccessTokenSource tokens) =>
      AccountApi(
        createAuthenticatedDio(
          base: _base,
          connection: connection,
          tokens: tokens,
          interceptors: [if (_logRequests) RequestLogInterceptor()],
        ),
        connection,
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
}
