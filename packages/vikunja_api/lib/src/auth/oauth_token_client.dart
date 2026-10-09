import 'package:dio/dio.dart';
import 'package:vikunja_api/src/auth/authorization_request.dart';
import 'package:vikunja_api/src/auth/jwt_claims.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The public token endpoint: `/api/v2/oauth/token` when the server has
/// `/api/v2`, `/api/v1/oauth/token` on 2.3.x. Throws `VikunjaFailure`.
final class OAuthTokenClient {
  /// [dio] must not carry an auth interceptor. [timeout] bounds sending and
  /// receiving each token request.
  new(
    Dio dio,
    ServerConnection connection, {
    this.timeout = const Duration(seconds: 60),
  }) : _dio = dio,
       _connection = connection;

  final Dio _dio;
  final ServerConnection _connection;
  final Duration timeout;

  // `service.jwtttlshort`, the access token lifetime of a default server.
  static const _defaultLifetime = Duration(seconds: 600);

  Uri get _endpoint {
    final base = _connection.apiBaseUri(_connection.preferredApiVersion);
    return base.replace(path: '${base.path}/oauth/token');
  }

  Future<TokenSet> exchangeCode({
    required String code,
    required AuthorizationRequest request,
  }) => _requestTokens({
    'grant_type': 'authorization_code',
    'code': code,
    'client_id': request.client.clientId,
    'redirect_uri': request.client.redirectUri.toString(),
    'code_verifier': request.codeVerifier,
  }, isRefresh: false);

  /// The refresh must not be cancelled once sent: the server rotates the
  /// refresh token on receipt.
  ///
  /// Besides [SessionEnded] and [RefreshRaceLost] this throws [ServerFailure]
  /// for a lost rotation race on SQLite servers, which answer the loser with a
  /// 500, and [RateLimited] for the shared 10 per minute and IP limit of
  /// `/login`, `/register` and `/api/v1/oauth/token` before 2.7.0.
  Future<TokenSet> refresh(String refreshToken) => _requestTokens({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
  }, isRefresh: true);

  Future<TokenSet> _requestTokens(
    Map<String, Object?> body, {
    required bool isRefresh,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.postUri<Object?>(
        _endpoint,
        data: body,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
          sendTimeout: timeout,
          receiveTimeout: timeout,
          // The platform clients would re-send the body, which holds the
          // refresh token or the code, to wherever a 307 or 308 points.
          followRedirects: false,
          validateStatus: _isSuccess,
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final failure = normalizeError(error);
      throw isRefresh ? _refreshFailure(failure) : failure;
    }
    return _tokenSet(response);
  }

  TokenSet _tokenSet(Response<Object?> response) {
    final json = response.data;
    if (json is! Map<String, Object?>) {
      throw UnexpectedResponse(response.statusCode, message: 'not JSON');
    }
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    final tokenType = json['token_type'];
    if (accessToken is! String ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        (tokenType is String && tokenType.toLowerCase() != 'bearer')) {
      throw UnexpectedResponse(
        response.statusCode,
        message: 'not a bearer token response',
      );
    }
    final claims = JwtClaims.tryParse(accessToken);
    if (claims == null) {
      throw UnexpectedResponse(
        response.statusCode,
        message: 'the access token is not a user JWT',
      );
    }
    final lifetime = switch (json['expires_in']) {
      final num seconds when seconds > 0 => Duration(
        milliseconds: (seconds * 1000).round(),
      ),
      _ => _defaultLifetime,
    };
    return TokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiry: claims.expiresAt,
      issuedAt: claims.issuedAt ?? claims.expiresAt.subtract(lifetime),
      sessionId: claims.sessionId,
      userId: claims.userId,
      username: claims.username,
    );
  }
}

bool _isSuccess(int? status) => status != null && status >= 200 && status < 300;

// The token endpoint is public, so any 401 is about the refresh token. 2.3.0
// and 2.4.0 send no code with it.
VikunjaFailure _refreshFailure(VikunjaFailure failure) => switch (failure) {
  UnexpectedResponse(statusCode: 401) ||
  DomainError(statusCode: 401) => SessionEnded(
    SessionEndReason.invalidRefreshToken,
    code: failure.code,
    message: failure.message,
  ),
  // A locked account before 2.7.0; a refresh cannot hit 2.7.0's reserved
  // username error, which reuses the code.
  DomainError(statusCode: 412, code: 1026) => SessionEnded(
    SessionEndReason.accountLocked,
    code: failure.code,
    message: failure.message,
  ),
  _ => failure,
};
