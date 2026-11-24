import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/auth/link_share_claims.dart';
import 'package:vikunja_api/src/auth/link_share_codes.dart';
import 'package:vikunja_api/src/errors/error_body.dart';
import 'package:vikunja_api/src/errors/streamed_error_body.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Turns the answers to a request made with a link share token whose share
/// is gone into a [LinkShareGone]: v1 400 code 13003 and v2 401 without a
/// code in Vikunja's JSON body (a user token never gets the latter taken for
/// it), and a 500 that [confirmGone] confirms. Requests with any other token
/// are left alone, so it may sit in every account's client; pass it to
/// `createAuthenticatedDio` as one of its `interceptors`. [onGone] runs once
/// per such answer.
final class LinkShareGoneInterceptor extends Interceptor {
  new({this.onGone, this.confirmGone});

  final void Function(LinkShareGone failure)? onGone;

  /// Asked with the token of a request answered with a 500, which is v1's
  /// answer to a gone share's token before 2.7 as well as to a real server
  /// error: the share's [LinkShareGone] when the server confirms that it is
  /// gone, else null, which leaves the answer as it is. Must not throw.
  final Future<LinkShareGone?> Function(String token)? confirmGone;

  static const _bearerPrefix = 'Bearer ';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final status = response?.statusCode;
    final confirm = confirmGone;
    final confirmable = status == 500 && confirm != null;
    if (response == null ||
        (status != 400 && status != 401 && !confirmable) ||
        err.error is VikunjaFailure) {
      return handler.next(err);
    }
    final token = _linkShareToken(err.requestOptions);
    if (token == null) return handler.next(err);
    if (confirmable) {
      return _pass(err, handler, await confirm(token));
    }
    if (response.data case final ResponseBody body) {
      response.data = await readErrorBody(body) ?? Uint8List(0);
    }
    final body = ErrorBody.tryParse(response.data);
    // A proxy's or access gate's own 401 page, or a body that broke off,
    // says nothing about the share (decision log: Accounts and sign-in).
    if (body == null) return handler.next(err);
    final gone = switch ((status, body.code)) {
      (400, LinkShareCodes.tokenInvalid) ||
      (401, null) => LinkShareGone(code: body.code, message: body.message),
      _ => null,
    };
    _pass(err, handler, gone);
  }

  void _pass(
    DioException err,
    ErrorInterceptorHandler handler,
    LinkShareGone? gone,
  ) {
    if (gone == null) return handler.next(err);
    onGone?.call(gone);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: DioExceptionType.badResponse,
        error: gone,
        stackTrace: err.stackTrace,
      ),
    );
  }

  static String? _linkShareToken(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith(_bearerPrefix)) return null;
    final token = header.substring(_bearerPrefix.length);
    return LinkShareClaims.tryParse(token) == null ? null : token;
  }
}
