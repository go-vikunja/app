import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/auth/link_share_claims.dart';
import 'package:vikunja_api/src/auth/link_share_codes.dart';
import 'package:vikunja_api/src/errors/error_body.dart';
import 'package:vikunja_api/src/errors/streamed_error_body.dart';
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
      response.data = await readErrorBody(body) ?? Uint8List(0);
    }
    final body = ErrorBody.tryParse(response.data);
    final gone = switch ((status, body?.code)) {
      (400, LinkShareCodes.tokenInvalid) || (401, null) => LinkShareGone(
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
}
