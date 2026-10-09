import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/auth/access_token_source.dart';
import 'package:vikunja_api/src/errors/error_body.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Adds the account's bearer token to requests for its server and, when the
/// server answers 401 code 11, refreshes once and repeats the request once.
/// Requests to anything outside the server root, and requests that bring
/// their own `Authorization` header, are left alone. A request with the token
/// never follows a redirect, as only its first URL was checked.
final class AuthInterceptor extends Interceptor {
  new(this._dio, this._connection, this._tokens);

  static const _authorization = 'Authorization';
  static const _bearerPrefix = 'Bearer ';
  static const _managedKey = 'vikunja.auth.managed';
  static const _repeatedKey = 'vikunja.auth.repeated';
  static const _tokenRejectedCode = 11;
  static const int _maxErrorBodyBytes = 64 * 1024;

  final Dio _dio;
  final ServerConnection _connection;
  final AccessTokenSource _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final bringsOwnHeader =
        options.headers.containsKey(_authorization) &&
        options.extra[_managedKey] != true;
    if (options.extra[_repeatedKey] == true ||
        bringsOwnHeader ||
        !_isOnAccountServer(options.uri)) {
      return handler.next(options);
    }
    try {
      final token = await _tokens.validAccessToken();
      options
        ..headers[_authorization] = '$_bearerPrefix$token'
        ..extra[_managedKey] = true
        ..followRedirects = false;
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
        true,
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final response = err.response;
    if (response case Response(statusCode: 401, data: final ResponseBody body)
        when options.extra[_managedKey] == true) {
      response.data = await _readErrorBody(body);
    }
    final rejectedToken = _bearerToken(options);
    if (response?.statusCode != 401 ||
        options.extra[_managedKey] != true ||
        options.extra[_repeatedKey] == true ||
        rejectedToken == null ||
        // A stream body was consumed by the first attempt.
        options.data is Stream ||
        ErrorBody.tryParse(response?.data)?.code != _tokenRejectedCode) {
      return handler.next(err);
    }

    final String? freshToken;
    try {
      freshToken = await _tokens.refreshAfterRejection(rejectedToken);
    } on Object catch (error, stackTrace) {
      return handler.reject(
        DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
          error: error,
          stackTrace: stackTrace,
        ),
        true,
      );
    }
    if (freshToken == null || freshToken == rejectedToken) {
      return handler.next(err);
    }

    // A 401 means the server did not run the request, so repeating it is
    // safe for every method.
    final repeated = options.copyWith(
      extra: {...options.extra, _repeatedKey: true},
      data: switch (options.data) {
        final FormData form => form.clone(),
        _ => null,
      },
    );
    repeated.headers[_authorization] = '$_bearerPrefix$freshToken';
    try {
      handler.resolve(await _dio.fetch<Object?>(repeated));
    } on DioException catch (repeatError) {
      // The repeat already went through every interceptor.
      handler.reject(repeatError);
    }
  }

  // Error bodies are small JSON; a larger one is cut off and fails to parse.
  static Future<Uint8List> _readErrorBody(ResponseBody body) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in body.stream) {
        bytes.add(chunk);
        if (bytes.length > _maxErrorBodyBytes) break;
      }
    } on Object {
      // A body that breaks off is no proof of a rejected token.
      return Uint8List(0);
    }
    return bytes.takeBytes();
  }

  bool _isOnAccountServer(Uri uri) {
    final root = _connection.rootUri;
    return uri.scheme == root.scheme &&
        uri.host == root.host &&
        uri.port == root.port &&
        (uri.path == root.path || uri.path.startsWith('${root.path}/'));
  }

  static String? _bearerToken(RequestOptions options) {
    final header = options.headers[_authorization];
    return header is String && header.startsWith(_bearerPrefix)
        ? header.substring(_bearerPrefix.length)
        : null;
  }
}
