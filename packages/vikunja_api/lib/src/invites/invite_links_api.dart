import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_api/src/invites/invite_links_port.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final class InviteLinksApi implements InviteLinksPort {
  new({required this._dio, required this._connection});

  final Dio _dio;
  final ServerConnection _connection;

  @override
  Future<InvitePreview> check(String token) async {
    if (!_connection.apiVersions.contains(ApiVersion.v2)) {
      throw const NotFound();
    }
    final base = _connection.apiBaseUri(ApiVersion.v2);
    final Response<Object?> response;
    try {
      response = await _dio.postUri<Object?>(
        base.replace(path: '${base.path}/invite-links/check'),
        data: {'token': token},
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
          followRedirects: false,
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
    final json = response.data;
    if (json is! Map<String, Object?>) {
      throw UnexpectedResponse(response.statusCode, message: 'not JSON');
    }
    return InvitePreview(
      name: switch (json['name']) {
        final String name => name,
        _ => '',
      },
      teams: [
        for (final team in objectListOf(json['teams']))
          if (team case {'id': final int id, 'name': final String name})
            InviteTeam(id: id, name: name),
      ],
      skipsEmailConfirmation: json['skip_email_confirm'] == true,
    );
  }
}
