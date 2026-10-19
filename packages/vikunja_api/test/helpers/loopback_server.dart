import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// An HTTP server on a loopback port whose handler plays Vikunja's `/ws`.
final class LoopbackServer {
  new _(this._server);

  static Future<LoopbackServer> start(
    FutureOr<void> Function(HttpRequest request) handle, {
    InternetAddress? address,
  }) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      0,
    );
    final loopback = LoopbackServer._(server);
    server.listen((request) {
      loopback.requests.add(request);
      unawaited(Future.sync(() => handle(request)));
    });
    return loopback;
  }

  final HttpServer _server;
  final requests = <HttpRequest>[];

  Uri get url => Uri(
    scheme: 'ws',
    host: _server.address.address,
    port: _server.port,
    path: '/api/v2/ws',
  );

  Future<void> close() => _server.close(force: true);
}

Future<void> answer(
  HttpRequest request,
  int status, {
  Map<String, String> headers = const {},
  String body = '',
}) async {
  final response = request.response..statusCode = status;
  headers.forEach(response.headers.set);
  response.write(body);
  await response.close();
}

String webSocketAccept(String key) => base64.encode(
  sha1
      .convert(ascii.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
      .bytes,
);

/// Answers the upgrade by hand and returns the raw connection, so a test can
/// send a wrong accept, stay silent or drop the connection. An [accept]
/// that returns null sends none.
Future<Socket> acceptByHand(
  HttpRequest request, {
  String? Function(String key) accept = webSocketAccept,
  bool upgradeHeader = true,
}) async {
  final response = request.response
    ..statusCode = HttpStatus.switchingProtocols
    ..headers.set(HttpHeaders.connectionHeader, 'Upgrade');
  if (upgradeHeader) {
    response.headers.set(HttpHeaders.upgradeHeader, 'websocket');
  }
  final value = accept(request.headers.value('sec-websocket-key')!);
  if (value != null) response.headers.set('Sec-WebSocket-Accept', value);
  response.headers.contentLength = 0;
  return await response.detachSocket();
}

/// Makes the next close of [socket] send a TCP reset instead of a FIN, as a
/// phone switching networks may see. Null where the option is unknown.
Socket? withResetOnClose(Socket socket) {
  final soLinger = Platform.isMacOS || Platform.isIOS
      ? 0x80
      : Platform.isLinux || Platform.isAndroid
      ? 13
      : null;
  if (soLinger == null) return null;
  // struct linger {int l_onoff = 1; int l_linger = 0;}
  final linger = Uint8List(8)..buffer.asByteData().setInt32(0, 1, Endian.host);
  socket.setRawOption(
    RawSocketOption(RawSocketOption.levelSocket, soLinger, linger),
  );
  return socket;
}
