import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cronet_http/cronet_http.dart' as cronet_http;
import 'package:cupertino_http/cupertino_http.dart' as cupertino_http;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/network/token_lock.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/widgets/string_extension.dart';

class Client {
  final log = Logger('Client logger');

  final JsonDecoder _decoder = JsonDecoder();
  final JsonEncoder _encoder = JsonEncoder();

  String _token = '';
  String _base = '';
  String? refreshCookie;
  bool ignoreCertificates = false;

  SettingsDatasource? settingsDatasource;

  Completer<bool>? _refreshCompleter;

  late http.Client _httpClient;

  String get base => _base;

  String get token => _token;

  Client({
    String? token,
    required String base,
    this.refreshCookie,
    this.settingsDatasource,
  }) {
    if (token != null) _token = token;
    base = base.replaceAll(" ", "");
    if (base.endsWith("/")) {
      base = base.substring(0, base.length - 1);
    }
    _base = base.endsWith('/api/v1') ? base : '$base/api/v1';

    _httpClient = createClient();
  }

  http.Client createClient() {
    try {
      if (Platform.isAndroid) {
        final engine = cronet_http.CronetEngine.build(
          cacheMode: cronet_http.CacheMode.memory,
          cacheMaxSize: 1000000,
        );
        return cronet_http.CronetClient.fromCronetEngine(engine);
      } else if (Platform.isIOS || Platform.isMacOS) {
        final config =
            cupertino_http
                  .URLSessionConfiguration.ephemeralSessionConfiguration()
              ..cache = cupertino_http.URLCache.withCapacity(
                memoryCapacity: 1000000,
              );
        return cupertino_http.CupertinoClient.fromSessionConfiguration(config);
      }
    } catch (e) {
      developer.log(
        "Error creating http client: $e. Falling back to default client.",
      );
    }

    return io_client.IOClient();
  }

  void setIgnoreCerts(bool val) {
    ignoreCertificates = val;
    HttpOverrides.global = IgnoreCertHttpOverrides(ignoreCertificates);
  }

  Map<String, String> getHeaders([bool? refresh = false]) {
    var headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Vikunja Mobile App',
    };

    if (refresh == true) {
      headers['Cookie'] = 'vikunja_refresh_token=$refreshCookie';
    } else {
      headers['Authorization'] = _token != '' ? 'Bearer $_token' : '';
    }

    return headers;
  }

  bool get authenticated => _token.isNotEmpty;

  void reset() {
    _token = '';
  }

  Future<Response<T>> get<T>({
    required String url,
    T Function(dynamic body)? mapper,
    Map<String, List<String>>? queryParameters,
  }) async {
    try {
      Uri uri = Uri.tryParse('$base$url')!;

      uri = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        query: uri.query,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        queryParameters: queryParameters,
        fragment: uri.fragment,
      );

      var response = await _httpClient.get(uri, headers: getHeaders());
      return _handleResponseWithRefresh(response, mapper, () {
        return _httpClient.get(uri, headers: getHeaders());
      });
    } catch (e, s) {
      return _handleException(e, s);
    }
  }

  Future<Response<T>> delete<T>({
    required String url,
    T Function(dynamic body)? mapper,
  }) async {
    try {
      var response = await _httpClient.delete(
        '$base$url'.toUri()!,
        headers: getHeaders(),
      );
      return _handleResponseWithRefresh(response, mapper, () {
        return _httpClient.delete('$base$url'.toUri()!, headers: getHeaders());
      });
    } catch (e, s) {
      return _handleException(e, s);
    }
  }

  Future<Response<T>> post<T>({
    required String url,
    T Function(dynamic body)? mapper,
    dynamic body,
  }) async {
    try {
      var encodedBody = _encoder.convert(body);
      var response = await _httpClient.post(
        '$base$url'.toUri()!,
        headers: getHeaders(),
        body: encodedBody,
      );
      return _handleResponseWithRefresh(response, mapper, () {
        return _httpClient.post(
          '$base$url'.toUri()!,
          headers: getHeaders(),
          body: encodedBody,
        );
      });
    } catch (e, s) {
      return _handleException(e, s);
    }
  }

  Future<Response<T>> put<T>({
    required String url,
    T Function(dynamic body)? mapper,
    dynamic body,
  }) async {
    try {
      var encodedBody = _encoder.convert(body);
      var response = await _httpClient.put(
        '$base$url'.toUri()!,
        headers: getHeaders(),
        body: encodedBody,
      );
      return _handleResponseWithRefresh(response, mapper, () {
        return _httpClient.put(
          '$base$url'.toUri()!,
          headers: getHeaders(),
          body: encodedBody,
        );
      });
    } catch (e, s) {
      return _handleException(e, s);
    }
  }

  io_client.IOClient _createIOClient() {
    final httpClient = HttpClient();
    if (ignoreCertificates) {
      httpClient.badCertificateCallback = (_, _, _) => true;
    }
    return io_client.IOClient(httpClient);
  }

  Future<Response<T>> postWithCookies<T>({
    required String url,
    T Function(dynamic body)? mapper,
    dynamic body,
  }) async {
    final cookieClient = _createIOClient();
    try {
      var response = await cookieClient.post(
        '$base$url'.toUri()!,
        headers: getHeaders(),
        body: _encoder.convert(body),
      );
      return _handleResponse(response, mapper);
    } catch (e, s) {
      return _handleException(e, s);
    } finally {
      cookieClient.close();
    }
  }

  Response<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic body)? mapper,
  ) {
    _extractRefreshCookie(response.headers);

    if (response.statusCode < 200 || response.statusCode >= 400) {
      Map<String, dynamic> error = _decoder.convert(response.body);

      if (response.statusCode == 401 &&
          globalNavigatorKey.currentContext != null) {
        globalNavigatorKey.currentState?.pushNamed("/login");
      }

      return ErrorResponse<T>(response.statusCode, getHeaders(), error);
    }

    var decode = utf8.decode(response.bodyBytes);

    if (mapper != null) {
      //Empty lists can be returned as "null" from the backend
      if (decode.trim() == "null") {
        return SuccessResponse<T>(
          mapper.call([]),
          response.statusCode,
          response.headers,
        );
      }

      var convert = _decoder.convert(decode);
      return SuccessResponse<T>(
        mapper.call(convert),
        response.statusCode,
        response.headers,
      );
    }

    return VoidResponse<T>();
  }

  Future<bool> tryRefreshToken() => _tryRefreshToken();

  Future<bool> _tryRefreshToken() async {
    if (refreshCookie == null || refreshCookie!.isEmpty) {
      return false;
    }

    // Prevent multiple concurrent refresh attempts
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final result = await TokenLock.synchronized(() async {
        // Check if the token was already refreshed by another isolate
        if (settingsDatasource != null) {
          final storedCookie = await settingsDatasource!.getRefreshCookie();
          if (storedCookie != null && storedCookie != refreshCookie) {
            final storedToken = await settingsDatasource!.getUserToken();
            if (storedToken != null && storedToken.isNotEmpty) {
              _token = storedToken;
              refreshCookie = storedCookie;
              return true;
            }
          }
        }

        final refreshClient = _createIOClient();
        try {
          var response = await refreshClient.post(
            '$base/user/token/refresh'.toUri()!,
            headers: getHeaders(true),
          );

          if (response.statusCode >= 200 && response.statusCode < 400) {
            var body = _decoder.convert(utf8.decode(response.bodyBytes));
            var newToken = body['token'] as String?;

            if (newToken != null && newToken.isNotEmpty) {
              _token = newToken;

              _extractRefreshCookie(response.headers);

              if (settingsDatasource != null) {
                await settingsDatasource?.saveUserToken(_token);
                await settingsDatasource?.saveRefreshCookie(refreshCookie);
              }

              return true;
            }
          }
        } finally {
          refreshClient.close();
        }

        return false;
      });

      _refreshCompleter!.complete(result);
      _refreshCompleter = null;
      return result;
    } catch (e) {
      developer.log("Error refreshing token: $e");
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(false);
      }
      _refreshCompleter = null;
      return false;
    }
  }

  void _extractRefreshCookie(Map<String, String> responseHeaders) {
    var setCookie = responseHeaders['set-cookie'];
    if (setCookie == null) return;

    var match = RegExp(r'vikunja_refresh_token=([^;]+)').firstMatch(setCookie);
    if (match != null) {
      refreshCookie = match.group(1);
    }
  }

  Future<Response<T>> _handleResponseWithRefresh<T>(
    http.Response response,
    T Function(dynamic body)? mapper,
    Future<http.Response> Function() retryRequest,
  ) async {
    _extractRefreshCookie(response.headers);

    if (response.statusCode == 401 && refreshCookie != null) {
      Map<String, dynamic> error = _decoder.convert(response.body);
      if (error.containsKey('code') && error['code'] == 11) {
        bool refreshed = await _tryRefreshToken();
        if (refreshed) {
          var retryResponse = await retryRequest();
          return _handleResponse(retryResponse, mapper);
        }
      }
    }

    return _handleResponse(response, mapper);
  }

  ExceptionResponse<T> _handleException<T>(Object e, StackTrace s) {
    if (e is! FormatException && e is! http.ClientException) {
      Sentry.captureException(e, stackTrace: s);
    }
    return ExceptionResponse<T>(e, s);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Client) return false;
    return other._token == _token;
  }

  @override
  int get hashCode => _token.hashCode;
}

class IgnoreCertHttpOverrides extends HttpOverrides {
  bool ignoreCerts = false;

  IgnoreCertHttpOverrides(bool ignore) {
    ignoreCerts = ignore;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, _, _) => ignoreCerts;
  }
}
