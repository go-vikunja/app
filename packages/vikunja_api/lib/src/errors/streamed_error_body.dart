import 'dart:typed_data';

import 'package:dio/dio.dart';

const int maxErrorBodyBytes = 64 * 1024;

/// An error answer's streamed body, read until it ends or passes
/// [maxErrorBodyBytes]: error bodies are small JSON, and a larger one is
/// cut off and fails to parse. Null when the stream breaks off.
Future<Uint8List?> readErrorBody(ResponseBody body) async {
  final bytes = BytesBuilder(copy: false);
  try {
    await for (final chunk in body.stream) {
      bytes.add(chunk);
      if (bytes.length > maxErrorBodyBytes) break;
    }
  } on Object {
    return null;
  }
  return bytes.takeBytes();
}
