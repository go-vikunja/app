import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/negotiation/transport_failure.dart';
import 'package:vikunja_api/src/transport/retry_after.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

typedef RetryDelay = Future<void> Function(Duration delay);

/// Retries idempotent requests (GET, HEAD) that failed on the network, with
/// 502, 503 or 504, or with 429. Waits [initialBackoff] × 2^attempt with
/// jitter, or as long as `Retry-After` asks.
final class RetryInterceptor extends Interceptor {
  new(
    this._dio, {
    this.maxRetries = 2,
    this.initialBackoff = const Duration(milliseconds: 500),
    this.maxRetryAfter = const Duration(seconds: 30),
    RetryDelay? delay,
    Random? random,
  }) : _delay = delay ?? _sleep,
       _random = random ?? Random();

  static const _attemptKey = 'vikunja.retry.attempt';

  final Dio _dio;
  final int maxRetries;
  final Duration initialBackoff;

  /// A longer `Retry-After` is not waited for: the failure goes to the caller,
  /// which can schedule the work for later instead of blocking.
  final Duration maxRetryAfter;
  final RetryDelay _delay;
  final Random _random;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = switch (options.extra[_attemptKey]) {
      final int attempt => attempt,
      _ => 0,
    };
    final wait = attempt < maxRetries ? _waitBeforeRetry(err, attempt) : null;
    if (wait == null) return handler.next(err);

    await Future.any([
      _delay(wait),
      if (options.cancelToken case final token?) token.whenCancel,
    ]);
    try {
      final response = await _dio.fetch<Object?>(
        options.copyWith(extra: {...options.extra, _attemptKey: attempt + 1}),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      // The retry already went through every interceptor.
      handler.reject(retryError);
    }
  }

  Duration? _waitBeforeRetry(DioException err, int attempt) {
    final method = err.requestOptions.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') return null;
    if (err.error is VikunjaFailure) return null;

    switch (err.type) {
      case DioExceptionType.badResponse:
        final response = err.response;
        final status = response?.statusCode;
        if (response == null || !_retriedStatuses.contains(status)) {
          return null;
        }
        final retryAfter = retryAfterOf(response.headers);
        if (retryAfter == null) return _backoff(attempt);
        return retryAfter > maxRetryAfter ? null : retryAfter;
      case DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError:
        return networkProblemOf(err) == NetworkProblem.tls
            ? null
            : _backoff(attempt);
      // The native adapters fail with http `ClientException`s, which are not
      // `IOException`s.
      case DioExceptionType.unknown
          when err.error is! FormatException && err.error is! Error:
        return networkProblemOf(err) == NetworkProblem.tls
            ? null
            : _backoff(attempt);
      case DioExceptionType.unknown ||
          DioExceptionType.badCertificate ||
          DioExceptionType.transformTimeout ||
          DioExceptionType.cancel:
        return null;
    }
  }

  Duration _backoff(int attempt) {
    final ceiling = initialBackoff * pow(2, attempt);
    return ceiling * (0.5 + _random.nextDouble() / 2);
  }

  static Future<void> _sleep(Duration delay) => Future.delayed(delay);
}

const _retriedStatuses = {429, 502, 503, 504};
