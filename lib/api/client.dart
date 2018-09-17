import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  Future<dynamic> get(String url) {
    return http
        .get('${this.base}$url', headers: _headers)
        .then(_handleResponse);
  }

  Future<dynamic> post(String url, {dynamic body}) {
    return http
        .post('${this.base}$url',
            headers: _headers, body: _encoder.convert(body))
        .then(_handleResponse);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode < 200 ||
        response.statusCode > 400 ||
        json == null) {
      throw new ApiException(
          response.statusCode, response.request.url.toString());
    }
    return _decoder.convert(response.body);
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
