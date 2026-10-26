import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/auth/link_share_claims.dart';
import 'package:vikunja_api/src/errors/error_body.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Turns the answers to a request made with a link share token whose share
/// is gone into a [LinkShareGone]: v1 400 code 13003 and v2 401 without a
/// code (a user token never gets the latter taken for it). Requests with
/// any other token are left alone, so it may sit in every account's client;
/// pass it to `createAuthenticatedDio` as one of its `interceptors`.
/// [onGone] runs once per such answer.
final class LinkShareGoneInterceptor extends Interceptor {
  new({this.onGone});

  final void Function(LinkShareGone failure)? onGone;

  static const _bearerPrefix = 'Bearer ';
  static const _linkShareTokenInvalid = 13003;
  static const int _maxErrorBodyBytes = 64 * 1024;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final status = response?.statusCode;
    if (response == null ||
        (status != 400 && status != 401) ||
        err.error is VikunjaFailure ||
        !_carriesLinkShareToken(err.requestOptions)) {
      return handler.next(err);
    }
    if (response.data case final ResponseBody body) {
      response.data = await _readErrorBody(body);
    }
    final body = ErrorBody.tryParse(response.data);
    final gone = switch ((status, body?.code)) {
      (400, _linkShareTokenInvalid) || (401, null) => LinkShareGone(
        code: body?.code,
        message: body?.message ?? '',
      ),
      _ => null,
    };
    if (gone == null) return handler.next(err);
    onGone?.call(gone);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: gone,
        stackTrace: err.stackTrace,
      ),
    );
  }

  static bool _carriesLinkShareToken(RequestOptions options) {
    final header = options.headers['Authorization'];
    return header is String &&
        header.startsWith(_bearerPrefix) &&
        LinkShareClaims.tryParse(header.substring(_bearerPrefix.length)) !=
            null;
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
      return Uint8List(0);
    }
    return bytes.takeBytes();
  }
}
