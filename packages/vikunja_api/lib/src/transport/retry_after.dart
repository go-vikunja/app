import 'dart:io' show HttpDate, HttpException, HttpHeaders;

import 'package:dio/dio.dart';

/// How long the server asks the client to wait, from `Retry-After` (seconds
/// or an HTTP date) or, as servers before 2.7.0 send no `Retry-After`, from
/// `X-RateLimit-Reset`. Absolute times are measured against the response's
/// `Date` header, so a wrong device clock does not matter.
Duration? retryAfterOf(Headers headers, {DateTime Function()? now}) {
  DateTime serverNow() =>
      _httpDate(headers.value(HttpHeaders.dateHeader)) ??
      (now ?? DateTime.now)().toUtc();

  final retryAfter = headers.value(HttpHeaders.retryAfterHeader)?.trim();
  if (retryAfter != null && retryAfter.isNotEmpty) {
    final seconds = int.tryParse(retryAfter);
    if (seconds != null) return seconds < 0 ? null : Duration(seconds: seconds);
    final date = _httpDate(retryAfter);
    if (date != null) return _nonNegative(date.difference(serverNow()));
  }

  final reset = int.tryParse(headers.value('x-ratelimit-reset')?.trim() ?? '');
  if (reset == null) return null;
  final resetAt = DateTime.fromMillisecondsSinceEpoch(
    reset * 1000,
    isUtc: true,
  );
  // The reset is a truncated unix second, so 2.7.0 adds one to its own
  // Retry-After as well.
  return _nonNegative(
    resetAt.difference(serverNow()) + const Duration(seconds: 1),
  );
}

DateTime? _httpDate(String? value) {
  if (value == null) return null;
  try {
    return HttpDate.parse(value);
  } on HttpException {
    return null;
  }
}

Duration _nonNegative(Duration duration) =>
    duration.isNegative ? Duration.zero : duration;
