import 'dart:convert';
import 'dart:core';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cronet_http/cronet_http.dart' as cronet_http;
import 'package:cupertino_http/cupertino_http.dart' as cupertino_http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/widgets/string_extension.dart';

class Client {
  final log = Logger('Client logger');

  final JsonDecoder _decoder = JsonDecoder();
  final JsonEncoder _encoder = JsonEncoder();

  String _token = '';
  String _base = '';
  bool ignoreCertificates = false;

  late http.Client _httpClient;

  String get base => _base;

  String get token => _token;

  Client({String? token, required String base}) {
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

  Map<String, String> get _headers => {
    'Authorization': _token != '' ? 'Bearer $_token' : '',
    'Content-Type': 'application/json',
    'User-Agent': 'Vikunja Mobile App',
  };

  Map<String, String> get headers => _headers;

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
        host: uri.host,
        port: uri.port,
        path: uri.path,
        queryParameters: queryParameters,
        fragment: uri.fragment,
      );

      var response = await _httpClient.get(uri, headers: _headers);
      return _handleResponse(response, mapper);
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
        headers: _headers,
      );
      return _handleResponse(response, mapper);
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
      var response = await _httpClient.post(
        '$base$url'.toUri()!,
        headers: _headers,
        body: _encoder.convert(body),
      );
      return _handleResponse(response, mapper);
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
      var response = await _httpClient.put(
        '$base$url'.toUri()!,
        headers: _headers,
        body: _encoder.convert(body),
      );
      return _handleResponse(response, mapper);
    } catch (e, s) {
      return _handleException(e, s);
    }
  }

  Response<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic body)? mapper,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 400) {
      Map<String, dynamic> error = _decoder.convert(response.body);

      if (response.statusCode == 401 &&
          globalNavigatorKey.currentContext != null) {
        //TODO don't do this here - complete when error handling is ready
        SettingsDatasource(FlutterSecureStorage()).saveServer(null);
        SettingsDatasource(FlutterSecureStorage()).saveUserToken(null);
        globalNavigatorKey.currentState?.pushNamed("/login");
      }

      return ErrorResponse<T>(response.statusCode, headers, error);
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

  ExceptionResponse<T> _handleException<T>(Object e, StackTrace s) {
    if (!(e is FormatException) && !(e is http.ClientException)) {
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
