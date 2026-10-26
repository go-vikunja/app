import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:vikunja_api/src/auth/link_share_claims.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A link share JWT with its claims.
@immutable
final class LinkShareToken {
  const new(this.jwt, this.claims);

  /// The bearer token: never logged or put in a route.
  final String jwt;
  final LinkShareClaims claims;

  @override
  String toString() =>
      'LinkShareToken(share: ${claims.shareId}, '
      'expires: ${claims.expiresAt.toIso8601String()})';
}

/// What `POST /shares/{hash}/auth` grants.
@immutable
final class LinkShareAuth {
  const new({
    required this.token,
    required this.projectId,
    required this.permission,
    this.name,
  });

  final LinkShareToken token;
  final int projectId;
  final Permission permission;

  /// The name the share's creator gave it; null when it has none.
  final String? name;

  int get shareId => token.claims.shareId;

  /// Never with the token or the name.
  @override
  String toString() =>
      'LinkShareAuth(share: $shareId, project: $projectId, '
      '${permission.name})';
}

/// A guest's way in through a link share, on `/api/v2` when the server has
/// it (2.4.0) and `/api/v1` before. Its Dio must not carry an auth
/// interceptor or log bodies: the requests carry the hash, the token and
/// maybe the share's password, and the answers echo the hash.
///
/// Failures are `VikunjaFailure`s; a cancelled request rethrows its
/// `DioException`. Authentication shares the limit of 10 requests per
/// minute and IP with sign-in and registration (`RateLimited` with
/// `Retry-After`); renewal does not.
final class LinkShareAuthClient {
  /// [timeout] bounds sending and receiving each request.
  new(
    Dio dio,
    ServerConnection connection, {
    this.timeout = const Duration(seconds: 60),
  }) : _dio = dio,
       _connection = connection;

  final Dio _dio;
  final ServerConnection _connection;
  final Duration timeout;

  /// `POST /shares/{hash}/auth`. A password sent to a share without one is
  /// ignored. Throws a `DomainError` 412 code 13001 when the share needs a
  /// [password] and none was given, a `Forbidden` code 13002 for a wrong
  /// one, and [LinkShareGone] for an unknown or deleted share (404 code
  /// 3006) or with link sharing turned off (404 without a code).
  Future<LinkShareAuth> authenticate(String hash, {String? password}) async {
    final response = await _post(
      'shares/${Uri.encodeComponent(hash)}/auth',
      body: {if (password != null && password.isNotEmpty) 'password': password},
    );
    final json = response.data;
    if (json is! Map<String, Object?>) {
      throw UnexpectedResponse(response.statusCode, message: 'not JSON');
    }
    final token = _tokenOf(response);
    final permission =
        Permission.fromValue(json['permission']) ?? token.claims.permission;
    if (permission == null) {
      throw UnexpectedResponse(response.statusCode, message: 'no permission');
    }
    return LinkShareAuth(
      token: token,
      projectId: switch (json['project_id']) {
        final int id when id > 0 => id,
        _ => token.claims.projectId,
      },
      permission: permission,
      name: switch (json['name']) {
        final String name when name.trim().isNotEmpty => name,
        _ => null,
      },
    );
  }

  /// `POST /user/token` with [token]: a new token for the same share with a
  /// fresh lifetime; [token] stays valid until it expires. An expired
  /// [token] is a `TokenRejected`, a deleted share a [LinkShareGone] (v1
  /// 404 code 3006, v2 401 without a code).
  Future<LinkShareToken> renew(String token) async {
    final response = await _post('user/token', bearer: token);
    return _tokenOf(response);
  }

  Future<Response<Object?>> _post(
    String path, {
    Map<String, Object?>? body,
    String? bearer,
  }) async {
    final base = _connection.apiBaseUri(_connection.preferredApiVersion);
    try {
      return await _dio.postUri<Object?>(
        base.replace(path: '${base.path}/$path'),
        data: body,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: {
            'Accept': 'application/json',
            if (bearer != null) 'Authorization': 'Bearer $bearer',
          },
          sendTimeout: timeout,
          receiveTimeout: timeout,
          // The platform clients would re-send the body or the token to
          // wherever a 307 or 308 points.
          followRedirects: false,
          validateStatus: _isSuccess,
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw _shareFailure(normalizeError(error));
    }
  }

  static LinkShareToken _tokenOf(Response<Object?> response) {
    final jwt = switch (response.data) {
      {'token': final String jwt} => jwt,
      _ => null,
    };
    final claims = jwt == null ? null : LinkShareClaims.tryParse(jwt);
    if (jwt == null || claims == null) {
      throw UnexpectedResponse(
        response.statusCode,
        message: 'not a link share token',
      );
    }
    return LinkShareToken(jwt, claims);
  }
}

bool _isSuccess(int? status) => status != null && status >= 200 && status < 300;

const _shareDoesNotExist = 3006;

// Both endpoints are about one share, so a 404 is that share, and a 401
// without a code is v2's answer to a token whose share is gone.
VikunjaFailure _shareFailure(VikunjaFailure failure) => switch (failure) {
  NotFound(code: null || _shareDoesNotExist) ||
  UnexpectedResponse(
    statusCode: 401,
  ) => LinkShareGone(code: failure.code, message: failure.message),
  _ => failure,
};
