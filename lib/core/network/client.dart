import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart' as cronet_http;
import 'package:cupertino_http/cupertino_http.dart' as cupertino_http;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/widgets/string_extension.dart';

class Client {
  final JsonDecoder _decoder = JsonDecoder();
  final JsonEncoder _encoder = JsonEncoder();
  String _token = '';
  String _base = '';
  bool ignoreCertificates = false;
  bool showSnackBar = true;

  String get base => _base;

  String get token => _token;

  String? postBody;

  @override
  bool operator ==(Object other) {
    if (other is! Client) return false;
    return other._token == _token;
  }

  Client({String? token, String? base}) {
    if (token != null) _token = token;
    if (base != null) {
      base = base.replaceAll(" ", "");
      if (base.endsWith("/")) {
        base = base.substring(0, base.length - 1);
      }
      _base = base.endsWith('/api/v1') ? base : '$base/api/v1';
    }
  }

  http.Client get httpClient {
    try {
      if (Platform.isAndroid) {
        final engine = cronet_http.CronetEngine.build(
          cacheMode: cronet_http.CacheMode.memory,
          cacheMaxSize: 1000000,
        );
        return cronet_http.CronetClient.fromCronetEngine(engine);
      }
      if (Platform.isIOS || Platform.isMacOS) {
        final config =
            cupertino_http
                  .URLSessionConfiguration.ephemeralSessionConfiguration()
              ..cache = cupertino_http.URLCache.withCapacity(
                memoryCapacity: 1000000,
              );
        return cupertino_http.CupertinoClient.fromSessionConfiguration(config);
      }
    } catch (e) {
      print("Error creating http client: $e. Falling back to default client.");
    }
    return io_client.IOClient();
  }

  void reloadIgnoreCerts(bool val) {
    ignoreCertificates = val;
    HttpOverrides.global = IgnoreCertHttpOverrides(ignoreCertificates);
  }

  Map<String, String> get _headers => {
    'Authorization': _token != '' ? 'Bearer $_token' : '',
    'Content-Type': 'application/json',
    'User-Agent': 'Vikunja Mobile App',
  };

  Map<String, String> get headers => _headers;

  @override
  int get hashCode => _token.hashCode;

  bool get authenticated => _token.isNotEmpty;

  void reset() {
    _token = '';
  }

  Future<Response?> get(
    String url, [
    Map<String, List<String>>? queryParameters,
  ]) {
    Uri uri = Uri.tryParse('$base$url')!;
    // why are we doing it like this? because Uri doesnt have setters. wtf.

    uri = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      //queryParameters: {...uri.queryParameters, ...?queryParameters},
      queryParameters: queryParameters,
      fragment: uri.fragment,
    );

    return httpClient
        .get(uri, headers: _headers)
        .then(_handleResponse)
        .onError((error, stackTrace) => _handleError(error, stackTrace));
  }

  Future<Response?> delete(String url) {
    return httpClient
        .delete('$base$url'.toUri()!, headers: _headers)
        .then(_handleResponse)
        .onError((error, stackTrace) => _handleError(error, stackTrace));
  }

  Future<Response?> post(String url, {dynamic body}) {
    return httpClient
        .post(
          '$base$url'.toUri()!,
          headers: _headers,
          body: _encoder.convert(body),
        )
        .then(_handleResponse)
        .onError((error, stackTrace) => _handleError(error, stackTrace));
  }

  Future<Response?> put(String url, {dynamic body}) {
    return httpClient
        .put(
          '$base$url'.toUri()!,
          headers: _headers,
          body: _encoder.convert(body),
        )
        .then(_handleResponse)
        .onError((error, stackTrace) => _handleError(error, stackTrace));
  }

  Response? _handleError(Object? e, StackTrace? st) {
    SnackBar snackBar = SnackBar(
      content: Text("Error on request: $e"),
      action: SnackBarAction(
        label: "Clear",
        onPressed: () => globalSnackbarKey.currentState?.clearSnackBars(),
      ),
    );
    globalSnackbarKey.currentState?.showSnackBar(snackBar);
    return null;
  }

  Map<String, String> headersToMap(HttpHeaders headers) {
    Map<String, String> map = {};
    headers.forEach((name, values) {
      map[name] = values[0].toString();
    });
    return map;
  }

  Error? _handleResponseErrors(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 400) {
      Map<String, dynamic> error;
      error = _decoder.convert(response.body);

      if (response.statusCode == 401 &&
          globalNavigatorKey.currentContext != null) {
        //TODO don't do this here - complete when error handling is ready
        SettingsDatasource(FlutterSecureStorage()).saveServer(null);
        SettingsDatasource(FlutterSecureStorage()).saveUserToken(null);
        globalNavigatorKey.currentState?.pushNamed("/login");
      }

      final SnackBar snackBar = SnackBar(
        content: Text("Error code ${response.statusCode} received."),
        action: globalNavigatorKey.currentContext == null
            ? null
            : SnackBarAction(
                label: ("Details"),
                onPressed: () {
                  showDialog(
                    context: globalNavigatorKey.currentContext!,
                    builder: (BuildContext context) => AlertDialog(
                      title: Text("Error ${response.statusCode}"),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Message: ${error["message"]}",
                            textAlign: TextAlign.start,
                          ),
                          Text("Url: ${response.request!.url.toString()}"),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
      if (showSnackBar) {
        globalSnackbarKey.currentState?.showSnackBar(snackBar);
      } else {
        print("error on request: ${error["message"]}");
      }
    }
    return null;
  }

  Response? _handleResponse(http.Response response) {
    _handleResponseErrors(response);
    return Response(
      _decoder.convert(utf8.decode(response.bodyBytes)),
      response.statusCode,
      response.headers,
    );
  }
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

class InvalidRequestApiException extends ApiException {
  final String message;

  InvalidRequestApiException(super.errorCode, super.path, this.message);

  @override
  String toString() {
    return message;
  }
}

class ApiException implements Exception {
  final int errorCode;
  final String path;

  ApiException(this.errorCode, this.path);

  @override
  String toString() {
    return "Can't fetch data from server. (Error-Code: $errorCode)";
  }
}
