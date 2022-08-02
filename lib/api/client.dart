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

class Client {
  GlobalKey<ScaffoldMessengerState> global;
  final JsonDecoder _decoder = new JsonDecoder();
  final JsonEncoder _encoder = new JsonEncoder();
  String _token;
  String _base;
  bool authenticated;
  bool ignoreCertificates = false;

  String get base => _base;
  String get token => _token;

  String post_body;

  HttpClient client = new HttpClient();

  bool operator ==(dynamic otherClient) {
    return otherClient._token == _token;
  }

  Client(this.global, {String token, String base, bool authenticated = false})
  {
    configure(token: token, base: base, authenticated: authenticated);
    client.badCertificateCallback = (_,__,___) => ignoreCertificates;
  }

  get _headers => {
        'Authorization': _token != null ? 'Bearer $_token' : '',
        'Content-Type': 'application/json'
      };

  @override
  int get hashCode => _token.hashCode;

  void configure({String token, String base, bool authenticated}) {
    if(token != null)
      _token = token;
    if(base != null)
      _base = base.endsWith('/api/v1') ? base : '$base/api/v1';
    if(authenticated != null)
      this.authenticated = authenticated;
  }



  void reset() {
    _token = _base = null;
    authenticated = false;
  }

  Future<Response> get(String url,
      [Map<String, List<String>> queryParameters]) {
    // TODO: This could be moved to a seperate function
    var uri = Uri.parse('${this.base}$url');
    // Because these are all final values, we can't just add the queryParameters and must instead build a new Uri Object every time this method is called.
    var newUri = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        query: uri.query,
        queryParameters: queryParameters,
        // Because dart takes a Map<String, String> here, it is only possible to sort by one parameter while the api supports n parameters.
        fragment: uri.fragment);
    return client.getUrl(newUri)
        .then(_handleResponseF, onError: _handleError);
    }

  Future<Response> delete(String url) {
    return client
        .deleteUrl(
          '${this.base}$url'.toUri(),
        )
        .then(_handleResponseF, onError: _handleError);
  }

  Future<Response> post(String url, {dynamic body}) {
    post_body = _encoder.convert(body);
    return client
        .postUrl(
          '${this.base}$url'.toUri(),
        )
        .then(_handleResponseF, onError: _handleError);
  }

  Future<Response> put(String url, {dynamic body}) {
    post_body = _encoder.convert(body);
    return client
        .putUrl(
          '${this.base}$url'.toUri(),
        )
        .then(_handleResponseF, onError: _handleError);
  }

  void _handleError(dynamic e) {
    log(e.toString());
    SnackBar snackBar = SnackBar(content: Text("Error on request: " + e.toString()));
    global.currentState?.showSnackBar(snackBar);
  }

  Map<String,String> headersToMap(HttpHeaders headers) {
    Map<String,String> map = {};
    headers.forEach((name, values) {map[name] = values[0].toString();});
    return map;
  }

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
  }

  void _handleResponseErrors(Response response) {
    if (response.statusCode < 200 ||
        response.statusCode >= 400 ||
        json == null) {
      Map<String, dynamic> error = _decoder.convert(response.body);
      if (response.statusCode ~/ 100 == 4) {
        throw new InvalidRequestApiException(
            response.statusCode,
            "",
            error["message"] ?? "Unknown Error");
      }
      final SnackBar snackBar = SnackBar(
        content: Text("Error code "+response.statusCode.toString()+" received."),
        action: SnackBarAction(
          label: ("Show Details"),
          onPressed: (){
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
