/// A [Client] stand-in that records calls instead of making them.
///
/// Data-source tests use this to pin the API contract — verb, URL, query
/// parameters, request body and the mapper applied to the response — without
/// re-testing the transport, which `test/core/network/` already owns.
library;

import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';

class RecordedCall {
  RecordedCall({
    required this.verb,
    required this.url,
    this.body,
    this.queryParameters,
  });

  final String verb;
  final String url;
  final dynamic body;
  final Map<String, List<String>>? queryParameters;

  @override
  String toString() => '$verb $url';
}

class RecordingClient extends Client {
  RecordingClient({super.base = 'https://vikunja.example.com'});

  final List<RecordedCall> calls = [];

  /// The decoded payload handed to the next mapper. Set it to whatever the API
  /// would return for the endpoint under test.
  dynamic nextBody;

  /// When set, the next call returns this instead of a mapped success.
  Response<dynamic>? nextResponse;

  RecordedCall get lastCall => calls.last;

  Response<T> _respond<T>(T Function(dynamic body)? mapper) {
    final canned = nextResponse;
    if (canned != null) {
      nextResponse = null;
      return switch (canned) {
        ErrorResponse() => ErrorResponse<T>(
          canned.statusCode,
          canned.headers,
          canned.error,
        ),
        ExceptionResponse() => ExceptionResponse<T>(
          canned.exception,
          canned.stackTrace,
        ),
        SuccessResponse() => SuccessResponse<T>(
          canned.body as T,
          canned.statusCode,
          canned.headers,
        ),
      };
    }
    if (mapper == null) return VoidResponse<T>();
    return SuccessResponse<T>(mapper(nextBody), 200, const {
      'x-pagination-total-pages': '1',
    });
  }

  @override
  Future<Response<T>> get<T>({
    required String url,
    T Function(dynamic body)? mapper,
    Map<String, List<String>>? queryParameters,
  }) async {
    calls.add(
      RecordedCall(verb: 'GET', url: url, queryParameters: queryParameters),
    );
    return _respond(mapper);
  }

  @override
  Future<Response<T>> delete<T>({
    required String url,
    T Function(dynamic body)? mapper,
  }) async {
    calls.add(RecordedCall(verb: 'DELETE', url: url));
    return _respond(mapper);
  }

  @override
  Future<Response<T>> post<T>({
    required String url,
    T Function(dynamic body)? mapper,
    dynamic body,
  }) async {
    calls.add(RecordedCall(verb: 'POST', url: url, body: body));
    return _respond(mapper);
  }

  @override
  Future<Response<T>> put<T>({
    required String url,
    T Function(dynamic body)? mapper,
    dynamic body,
  }) async {
    calls.add(RecordedCall(verb: 'PUT', url: url, body: body));
    return _respond(mapper);
  }
}
