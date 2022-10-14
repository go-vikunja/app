import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/components/string_extension.dart';
import 'package:vikunja_app/global.dart';

import '../main.dart';


class Client {
  GlobalKey<ScaffoldMessengerState> global;
  final JsonDecoder _decoder = new JsonDecoder();
  final JsonEncoder _encoder = new JsonEncoder();
  String _token = '';
  String _base = '';
  bool authenticated = false;
  bool ignoreCertificates = false;

  String get base => _base;
  String get token => _token;

  String? post_body;

  //HttpClient client = new HttpClient();

  bool operator ==(dynamic otherClient) {
    return otherClient._token == _token;
  }

  Client(this.global,
      {String? token, String? base, bool authenticated = false}) {
    configure(token: token, base: base, authenticated: authenticated);
  }

  void reload_ignore_certs(bool? val) {
    ignoreCertificates = val ?? false;
    HttpOverrides.global = new IgnoreCertHttpOverrides(ignoreCertificates);
    VikunjaGlobal
        .of(global.currentContext!)
        .settingsManager
        .setIgnoreCertificates(ignoreCertificates);
  }

  get _headers =>
      {
        'Authorization': _token != '' ? 'Bearer $_token' : '',
        'Content-Type': 'application/json'
      };

  @override
  int get hashCode => _token.hashCode;

  void configure({String? token, String? base, bool? authenticated}) {
    if (token != null)
      _token = token;
    if (base != null)
      _base = base.endsWith('/api/v1') ? base : '$base/api/v1';
    if (authenticated != null)
      this.authenticated = authenticated;
  }


  void reset() {
    _token = _base = '';
    authenticated = false;
  }

  Future<Response?> get(String url,
      [Map<String, List<String>>? queryParameters]) {
    final uri = Uri.parse('${this.base}$url').replace(
        queryParameters: queryParameters);
    return http.get(uri, headers: _headers)
        .then(_handleResponse).catchError((error) =>
        _handleError(error, null));
  }

  Future<Response?> delete(String url) {
    return http
        .delete(
      '${this.base}$url'.toUri()!,
      headers: _headers,
    )
        .then(_handleResponse).onError((error, stackTrace) =>
        _handleError(error, stackTrace));
  }

  Future<Response?> post(String url, {dynamic body}) {
    return http
        .post(
      '${this.base}$url'.toUri()!,
      headers: _headers,
      body: _encoder.convert(body),
    )
        .then(_handleResponse).onError((error, stackTrace) =>
        _handleError(error, stackTrace));
  }

  Future<Response?> put(String url, {dynamic body}) {
    return http
        .put(
      '${this.base}$url'.toUri()!,
      headers: _headers,
      body: _encoder.convert(body),
    )
        .then(_handleResponse).onError((error, stackTrace) =>
        _handleError(error, stackTrace));
  }

  Response? _handleError(Object? e, StackTrace? st) {
    SnackBar snackBar = SnackBar(
      content: Text("Error on request: " + e.toString()),
      action: SnackBarAction(label: "Clear", onPressed: () => global.currentState?.clearSnackBars()),);
    global.currentState?.showSnackBar(snackBar);
    return null;
  }

  Map<String, String> headersToMap(HttpHeaders headers) {
    Map<String, String> map = {};
    headers.forEach((name, values) {
      map[name] = values[0].toString();
    });
    return map;
  }

  /*
  Future<Response> _handleResponseF(HttpClientRequest request) {
    _headers.forEach((k, v) => request.headers.set(k, v));
    if(post_body != "") {
      request.write(post_body);
      post_body = "";
    }

    return request.close().then((response) {
      final completer = Completer<String>();
      final contents = StringBuffer();
      response.transform(utf8.decoder).listen((data) {
        contents.write(data);
      }, onDone: () => completer.complete(contents.toString()));
      return completer.future.then((body) {

        Response res = Response(json.decode(body), response.statusCode, headersToMap(response.headers));
        _handleResponseErrors(res);
        return res;
      });
    });
    //return Response(body, statusCode, headers)
  }*/

  void _handleResponseErrors(http.Response response) {
    if (response.statusCode < 200 ||
        response.statusCode >= 400) {
      Map<String, dynamic> error;
      error = _decoder.convert(response.body);
      if (response.statusCode ~/ 100 == 4) {
        throw new InvalidRequestApiException(
            response.statusCode,
            "",
            error["message"] ?? "Unknown Error");
      }
      final SnackBar snackBar = SnackBar(
        content: Text(
            "Error code " + response.statusCode.toString() + " received."),
        action: SnackBarAction(
          label: ("Show Details"),
          onPressed: () {
            Builder(
                builder: (BuildContext context) =>
                    Dialog(
                      child: Text(error["message"]),
                    )
            );
          },
        ),
      );
      global.currentState?.showSnackBar(snackBar);
      throw new ApiException(
          response.statusCode, "");
    }
  }

  Response? _handleResponse(http.Response response) {
    _handleResponseErrors(response);
    return Response(
        _decoder.convert(response.body), response.statusCode, response.headers);
  }
}

class InvalidRequestApiException extends ApiException {
  final String message;

  InvalidRequestApiException(int errorCode, String path, this.message)
      : super(errorCode, path);

  @override
  String toString() {
    return this.message;
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
