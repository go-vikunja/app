import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

/// `RequestOptions.extra` key marking the `/info` probes, the only requests
/// the app's transport lets through to an `http://` origin before the user
/// allowed unencrypted connections to it. They carry no credentials.
const preConsentProbeKey = 'vikunja.preConsentProbe';

/// What a probe reads of a body at most: Vikunja's `/info` is about 2 KB, a
/// login page the classifier looks into some 100 KB.
const int maxProbeBodyBytes = 256 * 1024;

Options _probeOptions(Duration timeout) => Options(
  headers: {'Accept': 'application/json'},
  extra: {preConsentProbeKey: true},
  connectTimeout: timeout,
  receiveTimeout: timeout,
  followRedirects: false,
  validateStatus: (_) => true,
  receiveDataWhenStatusError: true,
  // Raw bytes, so an HTML page is seen as HTML whatever transformer the
  // caller's Dio uses, and read only up to [maxProbeBodyBytes].
  responseType: ResponseType.stream,
);

/// Rethrows only cancellation. The probe comes before any trust in [root],
/// so the body is cut at [maxProbeBodyBytes] and the probe ends after
/// 2 × [timeout] (connecting, then the answer), however slowly a server
/// sends.
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
  // Only a cancel closes the connection: dio does not pass the end of a
  // subscription on to the source.
  final connection = CancelToken();
  unawaited(
    cancelToken?.whenCancel.then((error) {
      if (!connection.isCancelled) connection.cancel(error.error);
    }),
  );
  final limit = timeout * 2;
  try {
    return await _probe(dio, uri, timeout, connection).timeout(limit);
  } on TimeoutException {
    connection.cancel();
    return InfoTransportError(
      DioException(
        requestOptions: RequestOptions(path: '$uri'),
        type: DioExceptionType.receiveTimeout,
        message: 'No complete answer within $limit',
      ),
    );
  }
}

Future<InfoProbeResult> _probe(
  Dio dio,
  Uri uri,
  Duration timeout,
  CancelToken connection,
) async {
  final Response<Object?> response;
  try {
    response = await dio.getUri<Object?>(
      uri,
      options: _probeOptions(timeout),
      cancelToken: connection,
    );
  } on DioException catch (error) {
    if (error.type == DioExceptionType.cancel) rethrow;
    // An interceptor of the caller may still reject statuses we accept.
    final response = error.response;
    if (error.type == DioExceptionType.badResponse && response != null) {
      return await _answer(uri, response, connection);
    }
    return InfoTransportError(error);
  }
  return await _answer(uri, response, connection);
}

Future<InfoProbeResult> _answer(
  Uri uri,
  Response<Object?> response,
  CancelToken connection,
) async {
  final String body;
  try {
    body = switch (response.data) {
      final ResponseBody stream => utf8.decode(
        await _cappedBytes(stream, response.requestOptions, connection),
        allowMalformed: true,
      ),
      final List<int> bytes => utf8.decode(
        bytes.take(maxProbeBodyBytes).toList(),
        allowMalformed: true,
      ),
      final String text => text,
      null => '',
      // Already decoded by a custom transformer of the caller.
      final Object decoded => jsonEncode(decoded, toEncodable: (o) => '$o'),
    };
  } on DioException catch (error) {
    if (error.type == DioExceptionType.cancel) rethrow;
    return InfoTransportError(error);
  }
  return InfoAnswer(
    requestUri: uri,
    statusCode: response.statusCode ?? 0,
    headers: response.headers,
    body: body,
  );
}

Future<Uint8List> _cappedBytes(
  ResponseBody body,
  RequestOptions request,
  CancelToken connection,
) async {
  final bytes = BytesBuilder(copy: false);
  try {
    await for (final chunk in body.stream) {
      bytes.add(chunk);
      if (bytes.length >= maxProbeBodyBytes) {
        connection.cancel();
        break;
      }
    }
  } on DioException {
    rethrow;
  } on Exception catch (error) {
    throw DioException(
      requestOptions: request,
      error: error,
      message: 'The answer broke off',
    );
  }
  final all = bytes.takeBytes();
  return all.length > maxProbeBodyBytes
      ? Uint8List.sublistView(all, 0, maxProbeBodyBytes)
      : all;
}
