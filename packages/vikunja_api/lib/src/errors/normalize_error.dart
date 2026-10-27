import 'package:dio/dio.dart';
import 'package:vikunja_api/src/errors/error_body.dart';
import 'package:vikunja_api/src/negotiation/transport_failure.dart';
import 'package:vikunja_api/src/transport/retry_after.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Maps a `DioException` (or anything else thrown by a request) to a
/// [VikunjaFailure]. Cancellations are not failures: they are rethrown by
/// callers, so this must not be called for them.
VikunjaFailure normalizeError(Object error) => switch (error) {
  final VikunjaFailure failure => failure,
  DioException(error: final VikunjaFailure failure) => failure,
  final DioException exception => _fromDioException(exception),
  _ => switch (connectionSettingsProblemOf(error)) {
    final problem? => NetworkFailure(problem, cause: error),
    // Never the error's text: a FormatException quotes its input, which can
    // be a token.
    null => UnexpectedResponse(null, message: '${error.runtimeType}'),
  },
};

VikunjaFailure _fromDioException(DioException exception) {
  final response = exception.response;
  switch (exception.type) {
    case DioExceptionType.cancel:
      throw ArgumentError.value(
        exception,
        'error',
        'A cancelled request is not a failure',
      );
    case DioExceptionType.badResponse when response?.statusCode != null:
      return failureFromResponse(response!);
    case DioExceptionType.badResponse:
      return const UnexpectedResponse(null);
    case DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout:
      return NetworkFailure(NetworkProblem.timeout, cause: exception.error);
    case DioExceptionType.transformTimeout:
      return UnexpectedResponse(response?.statusCode);
    case DioExceptionType.badCertificate:
      return NetworkFailure(NetworkProblem.tls, cause: exception.error);
    case DioExceptionType.unknown
        when exception.error is FormatException || exception.error is Error:
      return UnexpectedResponse(
        response?.statusCode,
        message: '${exception.error.runtimeType}',
      );
    case DioExceptionType.connectionError || DioExceptionType.unknown:
      return NetworkFailure(
        networkProblemOf(exception),
        cause: exception.error,
      );
  }
}

/// Maps an HTTP error response of any API version to a [VikunjaFailure].
VikunjaFailure failureFromResponse(Response<Object?> response) {
  final status = response.statusCode!;
  final body = ErrorBody.tryParse(response.data);
  final code = body?.code;
  final message = body?.message ?? '';

  if (status == 429) {
    return RateLimited(
      retryAfter: retryAfterOf(response.headers),
      message: message,
    );
  }
  if (code != null) {
    if (_oauthProblems[code] case final problem?) {
      return OAuthFailure(problem, code: code, message: message);
    }
    if (_sessionEndReasons[code] case final reason?) {
      return SessionEnded(reason, code: code, message: message);
    }
    if (code == _refreshRaceLost) return RefreshRaceLost(message: message);
    if (code == _linkShareTokenInvalid) {
      return LinkShareGone(code: code, message: message);
    }
    if (status == 412 && _accountStatusReasons[code] != null) {
      return SessionEnded(
        _accountStatusReasons[code]!,
        code: code,
        message: message,
      );
    }
    if (status == 401 && code == _invalidToken) {
      return TokenRejected(message: message);
    }
  }

  final fieldErrors = body?.fieldErrors;
  return switch (status) {
    403 => Forbidden(code: code, message: message),
    404 => NotFound(code: code, message: message),
    412 || 422 when fieldErrors != null => ValidationFailed(
      fieldErrors: fieldErrors,
      code: code,
      message: message,
    ),
    >= 500 => ServerFailure(status, code: code, message: message),
    _ when code != null => DomainError(status, code: code, message: message),
    _ => UnexpectedResponse(status, message: message),
  };
}

const _invalidToken = 11;
const _refreshRaceLost = 16004;
// v1's answer to a guest whose share is gone; v2 answers 401 without a
// code, which only LinkShareGoneInterceptor can tell from a user's 401.
const _linkShareTokenInvalid = 13003;

const Map<int, OAuthProblem> _oauthProblems = {
  17001: OAuthProblem.clientMismatch,
  17002: OAuthProblem.invalidRedirectUri,
  17003: OAuthProblem.pkceMissing,
  17004: OAuthProblem.codeInvalid,
  17005: OAuthProblem.codeExpired,
  17006: OAuthProblem.pkceMismatch,
  17007: OAuthProblem.unsupportedGrant,
};

const Map<int, SessionEndReason> _sessionEndReasons = {
  16002: SessionEndReason.invalidRefreshToken,
  16003: SessionEndReason.expired,
  // No refresh cookie: only the cookie refresh endpoint sends it.
  16005: SessionEndReason.invalidRefreshToken,
};

// 1040 since 2.7.0. Before, a locked account was 1026, which 2.7.0 reuses
// for a reserved username, so 1026 is mapped only where it cannot be the
// latter (see OAuthTokenClient).
const Map<int, SessionEndReason> _accountStatusReasons = {
  1020: SessionEndReason.accountDisabled,
  1040: SessionEndReason.accountLocked,
};
