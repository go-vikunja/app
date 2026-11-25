import 'package:dio/dio.dart';
import 'package:vikunja_api/src/auth/auth_interceptor.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _notModified = 304;

final class WriteTransport {
  new(this._dio, ServerConnection connection)
    : version = connection.preferredApiVersion,
      maxFileSizeBytes = connection.info.maxFileSizeBytes,
      _patchRefusesSubscription =
          connection.preferredApiVersion == ApiVersion.v2 &&
          !(connection.info.version?.isAtLeast(2, 5) ?? true),
      _base = connection.apiBaseUri(connection.preferredApiVersion);

  final Dio _dio;
  final ApiVersion version;

  /// The server's upload limit; null when `/info` names none it parses.
  final int? maxFileSizeBytes;

  /// Vikunja 2.4 applies a merge-patch to the object as it answers it,
  /// whose `subscription` it then refuses (422, an entity name where its
  /// schema wants a number) on anything the user follows.
  final bool _patchRefusesSubscription;
  final Uri _base;

  String get createMethod => switch (version) {
    ApiVersion.v2 => 'POST',
    ApiVersion.v1 => 'PUT',
  };

  /// The verb of the kanban move and position writes, the reverse of
  /// [createMethod].
  String get updateMethod => switch (version) {
    ApiVersion.v2 => 'PUT',
    ApiVersion.v1 => 'POST',
  };

  Future<Response<Object?>> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    String? contentType,
    bool acceptNotModified = false,
  }) async {
    try {
      final response = await _dio.requestUri<Object?>(
        _base.replace(path: '${_base.path}$path', queryParameters: query),
        data: body == null ? null : _withoutNul(body),
        options: Options(
          method: method,
          responseType: ResponseType.json,
          contentType: contentType,
          headers: {'Accept': 'application/json'},
          validateStatus: acceptNotModified ? _okOrNotModified : null,
        ),
      );
      rejectNotJson(response);
      return response;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
  }

  /// A multipart request whose files are read once, see
  /// [AuthInterceptor.bodyReadOnceKey]. [timeout] bounds sending and,
  /// again, the wait for the answer.
  Future<Response<Object?>> sendForm(
    String method,
    String path,
    FormData form, {
    Duration? timeout,
    CancelToken? cancel,
  }) async {
    try {
      final response = await _dio.requestUri<Object?>(
        _base.replace(path: '${_base.path}$path'),
        data: form,
        cancelToken: cancel,
        options: Options(
          method: method,
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
          sendTimeout: timeout,
          receiveTimeout: timeout,
          extra: {AuthInterceptor.bodyReadOnceKey: true},
        ),
      );
      rejectNotJson(response);
      return response;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
  }

  /// [changes] as the merge-patch of a task or project, which the user may
  /// follow. Where the server refuses the subscription, the patch removes
  /// it from what is merged; the server keeps it all the same.
  Map<String, Object?> followablePatch(Map<String, Object?> changes) =>
      _patchRefusesSubscription ? {...changes, 'subscription': null} : changes;

  /// Writes [changes] to the object at [path]: a v2 merge-patch, read when
  /// the server answers 304 for no change, or on v1 a read of the object
  /// posted back whole with [changes] overlaid. The v1 update is a full
  /// replace that clears or resets what it is not sent (a project's colour,
  /// identifier, favourite and archive state, and its position, which
  /// renumbers the siblings; a view's kind, which turns a board into a
  /// list). A [followable] object is patched through [followablePatch].
  /// The objects under [mergedObjects] take [changes] key by key on v1 as
  /// well, as the merge-patch does on v2; elsewhere v1 replaces an object
  /// whole.
  Future<Response<Object?>> patchOrReplace(
    String path,
    String what,
    Map<String, Object?> changes, {
    bool followable = false,
    Set<String> mergedObjects = const {},
  }) async {
    switch (version) {
      case ApiVersion.v2:
        final response = await send(
          'PATCH',
          path,
          body: followable ? followablePatch(changes) : changes,
          contentType: mergePatchContentType,
          acceptNotModified: true,
        );
        if (response.statusCode != _notModified) return response;
        return await send('GET', path);
      case ApiVersion.v1:
        final current = decode<Map<String, Object?>>(
          await send('GET', path),
          (json) => objectOf(json, what),
        );
        return await send(
          'POST',
          path,
          body: {
            ...current,
            ...changes,
            for (final key in mergedObjects)
              if ((current[key], changes[key]) case (
                final Map<String, Object?> stored,
                final Map<String, Object?> changed,
              ))
                key: {...stored, ...changed},
          },
        );
    }
  }

  T decode<T>(Response<Object?> response, T Function(Object?) parse) {
    try {
      return parse(response.data);
    } on MalformedJson catch (error) {
      throw UnexpectedResponse(response.statusCode, message: error.message);
    }
  }

  static bool _okOrNotModified(int? status) =>
      status != null &&
      (status >= 200 && status < 300 || status == _notModified);
}

/// Vikunja 2.8.0 refuses a JSON body with U+0000 anywhere in it, so one
/// pasted into a text would fail its write for good.
Object? _withoutNul(Object? value) => switch (value) {
  final String text => withoutNul(text),
  final Map<String, Object?> map => <String, Object?>{
    for (final MapEntry(:key, :value) in map.entries)
      withoutNul(key): _withoutNul(value),
  },
  final List<Object?> list => [for (final item in list) _withoutNul(item)],
  _ => value,
};
