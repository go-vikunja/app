import 'dart:io' show HttpDate, HttpException, HttpHeaders;

import 'package:dio/dio.dart';

/// How long the server asks the client to wait, from `Retry-After` (seconds
/// or an HTTP date) or, as servers before 2.7.0 send no `Retry-After`, from
/// `X-RateLimit-Reset`. Absolute times are measured against the response's
/// `Date` header, so a wrong device clock does not matter. A wait of more than
/// a week, longer than any rate-limit window, is unknown (null): such a reset
/// is in milliseconds or finer, or a value no Duration holds.
Duration? retryAfterOf(Headers headers, {DateTime Function()? now}) =>
    // The first of a repeated header, as on the socket: Headers.value throws
    // for it.
    retryAfterFromHeaders((name) => headers[name]?.firstOrNull, now: now);

/// [retryAfterOf] over a case-insensitive header lookup, e.g. of a dart:io
/// response.
Duration? retryAfterFromHeaders(
  String? Function(String name) header, {
  DateTime Function()? now,
}) {
  DateTime serverNow() =>
      _httpDate(header(HttpHeaders.dateHeader)) ??
      (now ?? DateTime.now)().toUtc();

  final retryAfter = header(HttpHeaders.retryAfterHeader)?.trim();
  if (retryAfter != null && retryAfter.isNotEmpty) {
    final seconds = int.tryParse(retryAfter);
    if (seconds != null) {
      return seconds < 0 || seconds > _longestWait.inSeconds
          ? null
          : Duration(seconds: seconds);
    }
    final date = _httpDate(retryAfter);
    if (date != null) {
      final wait = date.difference(serverNow());
      return wait > _longestWait ? null : _nonNegative(wait);
    }
  }

  final reset = int.tryParse(header('x-ratelimit-reset')?.trim() ?? '');
  if (reset == null || reset < 0) return null;
  final at = serverNow();
  // Compared in seconds: a reset in micro- or nanoseconds overflows the
  // milliseconds or leaves DateTime's range.
  if (reset > at.millisecondsSinceEpoch ~/ 1000 + _longestWait.inSeconds) {
    return null;
  }
  final resetAt = DateTime.fromMillisecondsSinceEpoch(
    reset * 1000,
    isUtc: true,
  );
  // The reset is a truncated unix second, so 2.7.0 adds one to its own
  // Retry-After as well.
  return _nonNegative(resetAt.difference(at) + const Duration(seconds: 1));
}

DateTime? _httpDate(String? value) {
  if (value == null) return null;
  try {
    return HttpDate.parse(value);
  } on HttpException {
    return null;
  }
}

const _longestWait = Duration(days: 7);

Duration _nonNegative(Duration duration) =>
    duration.isNegative ? Duration.zero : duration;
