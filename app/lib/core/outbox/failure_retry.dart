import 'package:vikunja_domain/vikunja_domain.dart';

enum FailureRetry {
  /// Not the server's word on the request (the network, a rate limit, the
  /// session): it waits as long as that lasts.
  waits,

  /// An answer that is neither success nor the server's last word.
  counted,

  /// The server's last word, or a failure a retry would only repeat.
  never,
}

/// How the outbox retries a request that failed with [failure]. A token
/// the server rejects after the interceptor's own refresh means a session
/// that was replaced or a server that will accept the next token; the
/// session that ended for good arrives as `SessionEnded`, which is never
/// retried and left to the caller. A 2xx whose body is no JSON at all is a
/// captive portal's page on a cleartext network, which waits like being
/// offline. An answer without a Vikunja error code (a proxy's redirect, an
/// access gate's 401 or 407 such as for an expired access header, a web
/// server's 404 during a deploy) is not the server's last word. A 2xx
/// whose JSON cannot be read, or an exception without a status, is final
/// where [unreadableIsFinal] (a retry would only repeat it).
FailureRetry failureRetry(
  VikunjaFailure failure, {
  required bool unreadableIsFinal,
}) => switch (failure) {
  NetworkFailure() ||
  NotJsonResponse() ||
  RateLimited() ||
  RefreshRaceLost() ||
  TokenRejected() => FailureRetry.waits,
  ServerFailure() => FailureRetry.counted,
  NotFound(:final routeAbsent) =>
    routeAbsent ? FailureRetry.counted : FailureRetry.never,
  UnexpectedResponse(statusCode: 401 || 407) => FailureRetry.counted,
  UnexpectedResponse(:final statusCode?) when statusCode >= 400 =>
    FailureRetry.never,
  UnexpectedResponse(:final statusCode?) when statusCode >= 300 =>
    FailureRetry.counted,
  UnexpectedResponse() =>
    unreadableIsFinal ? FailureRetry.never : FailureRetry.counted,
  _ => FailureRetry.never,
};
