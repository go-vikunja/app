import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';

/// Logs one line per request: method, URL without query, status, duration.
/// Headers and bodies are never logged because they carry credentials.
final class RequestLogInterceptor extends Interceptor {
  new({Logger? logger}) : _log = logger ?? Logger('http');

  static const _stopwatchKey = 'vikunja_mobile.request_stopwatch';

  final Logger _log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchKey] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log.fine(_describe(response.requestOptions, '${response.statusCode}'));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final outcome = err.response?.statusCode?.toString() ?? err.type.name;
    _log.fine(_describe(err.requestOptions, outcome));
    handler.next(err);
  }

  String _describe(RequestOptions options, String outcome) {
    final stopwatch = options.extra[_stopwatchKey];
    final elapsed = stopwatch is Stopwatch
        ? ' ${stopwatch.elapsedMilliseconds} ms'
        : '';
    return '${options.method} ${describeUriForLog(options.uri)} '
        '-> $outcome$elapsed';
  }
}
