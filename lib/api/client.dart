import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/components/string_extension.dart';

class Client {
  final JsonDecoder _decoder = new JsonDecoder();
  final JsonEncoder _encoder = new JsonEncoder();
  final String _token;
  final String _base;

  String get base => _base;

  Client(this._token, String base)
      : _base = base.endsWith('/api/v1') ? base : '$base/api/v1';

  bool operator ==(dynamic otherClient) {
    return otherClient._token == _token;
  }

  @override
  int get hashCode => _token.hashCode;

  get _headers => {
        'Authorization': _token != null ? 'Bearer $_token' : '',
        'Content-Type': 'application/json'
      };

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
    return http.get(newUri, headers: _headers).then(_handleResponse);
  }

  Future<Response> delete(String url) {
    return http
        .delete(
          '${this.base}$url'.toUri(),
          headers: _headers,
        )
        .then(_handleResponse);
  }

  Future<Response> post(String url, {dynamic body}) {
    return http
        .post(
          '${this.base}$url'.toUri(),
          headers: _headers,
          body: _encoder.convert(body),
        )
        .then(_handleResponse);
  }

  Future<Response> put(String url, {dynamic body}) {
    return http
        .put(
          '${this.base}$url'.toUri(),
          headers: _headers,
          body: _encoder.convert(body),
        )
        .then(_handleResponse);
  }

  Response _handleResponse(http.Response response) {
    if (response.statusCode < 200 ||
        response.statusCode >= 400 ||
        json == null) {
      if (response.statusCode ~/ 100 == 4) {
        Map<String, dynamic> error = _decoder.convert(response.body);
        throw new InvalidRequestApiException(
            response.statusCode,
            response.request.url.toString(),
            error["message"] ?? "Unknown Error");
      }
      throw new ApiException(
          response.statusCode, response.request.url.toString());
    }
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
