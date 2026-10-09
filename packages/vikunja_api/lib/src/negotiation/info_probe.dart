import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

sealed class InfoProbeResult;

/// Any HTTP response, whatever its status or body.
final class InfoAnswer extends InfoProbeResult {
  new({
    required this.requestUri,
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final Uri requestUri;
  final int statusCode;
  final Headers headers;
  final String body;

  /// The decoded body when it is a Vikunja `/info` document.
  late final Map<String, Object?>? vikunjaInfo = _decodeVikunjaInfo();

  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  bool get isHtml =>
      (header(Headers.contentTypeHeader)?.contains('html') ?? false) ||
      body.trimLeft().startsWith('<');

  Uri? get redirectTarget {
    final location = header('location');
    if (location == null) return null;
    final target = Uri.tryParse(location.trim());
    return target == null ? null : requestUri.resolveUri(target);
  }

  String? header(String name) => headers[name]?.firstOrNull;

  Map<String, Object?>? _decodeVikunjaInfo() {
    if (statusCode != 200) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    return decoded is Map<String, Object?> && decoded['version'] is String
        ? decoded
        : null;
  }
}

/// No HTTP response: connection, TLS or timeout failure.
final class InfoTransportError(final DioException exception)
    extends InfoProbeResult;

Options _probeOptions(Duration timeout) => Options(
  headers: {'Accept': 'application/json'},
  connectTimeout: timeout,
  receiveTimeout: timeout,
  followRedirects: false,
  validateStatus: (_) => true,
  receiveDataWhenStatusError: true,
  // Raw bytes, so an HTML page is seen as HTML whatever transformer the
  // caller's Dio uses.
  responseType: ResponseType.bytes,
);

/// Rethrows only cancellation.
Future<InfoProbeResult> probeInfo(
  Dio dio,
  Uri root,
  ApiVersion version, {
  required Duration timeout,
  CancelToken? cancelToken,
}) async {
  final uri = root.replace(
    path: '${root.path}/api/${version.pathSegment}/info',
  );
  try {
    final response = await dio.getUri<Object?>(
      uri,
      options: _probeOptions(timeout),
      cancelToken: cancelToken,
    );
    return _answer(uri, response);
  } on DioException catch (error) {
    if (error.type == DioExceptionType.cancel) rethrow;
    // An interceptor of the caller may still reject statuses we accept.
    final response = error.response;
    if (error.type == DioExceptionType.badResponse && response != null) {
      return _answer(uri, response);
    }
    return InfoTransportError(error);
  }
}

InfoAnswer _answer(Uri uri, Response<Object?> response) => InfoAnswer(
  requestUri: uri,
  statusCode: response.statusCode ?? 0,
  headers: response.headers,
  body: switch (response.data) {
    final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
    final String text => text,
    null => '',
    // Already decoded by a custom transformer of the caller.
    final Object decoded => jsonEncode(decoded, toEncodable: (o) => '$o'),
  },
);
