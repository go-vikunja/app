import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';

final _log = Logger('DioFactory');

Dio createDio({
  required String userAgent,
  HttpClientAdapter? httpClientAdapter,
  bool logRequests = kDebugMode,
  Duration receiveTimeout = const Duration(seconds: 15),
}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: receiveTimeout,
      sendTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': userAgent},
    ),
  )..httpClientAdapter = httpClientAdapter ?? createPlatformHttpAdapter();
  if (logRequests) dio.interceptors.add(RequestLogInterceptor());
  return dio;
}

/// Cronet on Android and NSURLSession on iOS honour system proxies, VPNs and
/// user-installed CAs, which dart:io does not on Android.
HttpClientAdapter createPlatformHttpAdapter() {
  try {
    return NativeAdapter(
      // Auth handles cookies explicitly and tokens live only in secure
      // storage, so NSURLSession must neither store nor replay cookies.
      createCupertinoConfiguration: () =>
          URLSessionConfiguration.ephemeralSessionConfiguration()
            ..httpShouldSetCookies = false
            ..httpCookieAcceptPolicy =
                NSHTTPCookieAcceptPolicy.NSHTTPCookieAcceptPolicyNever,
      createFallbackAdapter: (error, _) {
        _log.warning('Cronet unavailable, using dart:io instead: $error');
        return IOHttpClientAdapter();
      },
    );
  } on Object catch (error) {
    _log.warning('Native HTTP adapter failed, using dart:io instead: $error');
    return IOHttpClientAdapter();
  }
}
