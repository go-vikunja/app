import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Account endpoints over an authenticated client from
/// `createAuthenticatedDio`. Throws `VikunjaFailure`; a cancelled request
/// rethrows its `DioException`.
final class AccountApi {
  new(Dio dio, ServerConnection connection)
    : _dio = dio,
      _connection = connection;

  final Dio _dio;
  final ServerConnection _connection;

  Future<User> currentUser() async {
    final user = parseUser(await _send('GET', '/user'));
    if (user == null) {
      throw const UnexpectedResponse(200, message: 'not a user');
    }
    return user;
  }

  /// Ends the server session of the current token (best effort for callers).
  Future<void> logout() async {
    final path = switch (_connection.preferredApiVersion) {
      ApiVersion.v2 => '/logout',
      ApiVersion.v1 => '/user/logout',
    };
    await _send('POST', path);
  }

  Future<Map<String, Object?>> _send(String method, String path) async {
    final base = _connection.apiBaseUri(_connection.preferredApiVersion);
    final Response<Object?> response;
    try {
      response = await _dio.requestUri<Object?>(
        base.replace(path: '${base.path}$path'),
        options: Options(
          method: method,
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
    final json = response.data;
    if (json is Map<String, Object?>) return json;
    throw UnexpectedResponse(response.statusCode, message: 'not JSON');
  }
}
