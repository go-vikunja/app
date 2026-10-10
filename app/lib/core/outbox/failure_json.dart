import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';

/// A `VikunjaFailure` as stored in `outbox.last_error`. The cause of a
/// network failure is not kept: it is a platform exception without value
/// after a restart.
String encodeFailure(VikunjaFailure failure) =>
    jsonEncode(failureToJson(failure));

VikunjaFailure decodeFailure(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> map => failureFromJson(map),
  _ => const UnexpectedResponse(null, message: 'unreadable failure'),
};

Map<String, Object?> failureToJson(VikunjaFailure failure) => {
  'kind': switch (failure) {
    NetworkFailure() => 'network',
    TokenRejected() => 'token_rejected',
    SessionEnded() => 'session_ended',
    RefreshRaceLost() => 'refresh_race_lost',
    OAuthFailure() => 'oauth',
    Forbidden() => 'forbidden',
    NotFound() => 'not_found',
    ValidationFailed() => 'validation_failed',
    RateLimited() => 'rate_limited',
    ServerFailure() => 'server_failure',
    DomainError() => 'domain_error',
    UnexpectedResponse() => 'unexpected_response',
  },
  'code': ?failure.code,
  if (failure.message.isNotEmpty) 'message': failure.message,
  ...switch (failure) {
    NetworkFailure(:final problem) => {'problem': problem.name},
    SessionEnded(:final reason) => {'reason': reason.name},
    OAuthFailure(:final problem) => {'problem': problem.name},
    ValidationFailed(:final fieldErrors) => {'field_errors': fieldErrors},
    RateLimited(:final retryAfter?) => {
      'retry_after_ms': retryAfter.inMilliseconds,
    },
    ServerFailure(:final statusCode) ||
    DomainError(:final statusCode) => {'status_code': statusCode},
    UnexpectedResponse(:final statusCode?) => {'status_code': statusCode},
    _ => const <String, Object?>{},
  },
};

VikunjaFailure failureFromJson(Map<String, Object?> json) {
  final code = json['code'] as int?;
  final message = json['message'] as String? ?? '';
  final statusCode = json['status_code'] as int?;
  return switch (json['kind']) {
    'network' => NetworkFailure(
      NetworkProblem.values.asNameMap()[json['problem']] ??
          NetworkProblem.unreachable,
    ),
    'token_rejected' => TokenRejected(message: message),
    'session_ended' => SessionEnded(
      SessionEndReason.values.asNameMap()[json['reason']] ??
          SessionEndReason.invalidRefreshToken,
      code: code,
      message: message,
    ),
    'refresh_race_lost' => RefreshRaceLost(message: message),
    'oauth' => OAuthFailure(
      OAuthProblem.values.asNameMap()[json['problem']] ??
          OAuthProblem.codeInvalid,
      code: code,
      message: message,
    ),
    'forbidden' => Forbidden(code: code, message: message),
    'not_found' => NotFound(code: code, message: message),
    'validation_failed' => ValidationFailed(
      fieldErrors: _fieldErrors(json['field_errors']),
      code: code,
      message: message,
    ),
    'rate_limited' => RateLimited(
      retryAfter: switch (json['retry_after_ms']) {
        final int ms => Duration(milliseconds: ms),
        _ => null,
      },
      message: message,
    ),
    'server_failure' => ServerFailure(
      statusCode ?? 500,
      code: code,
      message: message,
    ),
    'domain_error' => DomainError(
      statusCode ?? 400,
      code: code ?? 0,
      message: message,
    ),
    _ => UnexpectedResponse(statusCode, message: message),
  };
}

Map<String, List<String>> _fieldErrors(Object? value) => {
  if (value is Map<String, Object?>)
    for (final MapEntry(:key, value: messages) in value.entries)
      key: [
        if (messages is List<Object?>)
          for (final message in messages)
            if (message is String) message,
      ],
};
