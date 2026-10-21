import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_api/src/dto/user_profile_codec.dart';
import 'package:vikunja_api/src/dto/user_settings_codec.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

typedef UserWithSettings = ({User user, UserSettings settings});

typedef UserWithProfile = ({
  User user,
  UserProfile profile,
  UserSettings settings,
});

/// Account endpoints over an authenticated client from
/// `createAuthenticatedDio`. Throws `VikunjaFailure`; a cancelled request
/// rethrows its `DioException`.
final class AccountApi {
  new(Dio dio, ServerConnection connection)
    : _dio = dio,
      _connection = connection;

  final Dio _dio;
  final ServerConnection _connection;

  Future<User> currentUser() async => (await currentUserWithSettings()).user;

  /// Settings the client cannot read are the defaults; only a body that is
  /// not a user fails.
  Future<UserWithSettings> currentUserWithSettings() async {
    final (:user, profile: _, :settings) = await currentUserWithProfile();
    return (user: user, settings: settings);
  }

  /// [currentUserWithSettings] with the profile from the same read.
  Future<UserWithProfile> currentUserWithProfile() async {
    final json = await _send('GET', '/user');
    final user = parseUser(json);
    final profile = parseUserProfile(json);
    if (user == null || profile == null) {
      throw const UnexpectedResponse(200, message: 'not a user');
    }
    return (
      user: user,
      profile: profile,
      settings: parseUserSettings(json['settings']),
    );
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
