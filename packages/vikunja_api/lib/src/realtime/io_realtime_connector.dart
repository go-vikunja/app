import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:vikunja_api/src/realtime/realtime_codec.dart';
import 'package:vikunja_api/src/realtime/realtime_message.dart';
import 'package:vikunja_api/src/realtime/realtime_socket.dart';
import 'package:vikunja_api/src/transport/retry_after.dart';

// RFC 6455 section 1.3.
const _acceptGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

final _random = Random.secure();

/// Upgrades through [HttpClient] by hand because `WebSocket.connect` hides
/// the status and `Retry-After` of a refused upgrade. Sends no `Origin`:
/// Vikunja answers a foreign one with 403.
final class IoRealtimeConnector implements RealtimeConnector {
  const new({
    this.connectTimeout = const Duration(seconds: 15),
    this.pingInterval = const Duration(seconds: 25),
    this.createHttpClient = HttpClient.new,
  });

  /// For the whole handshake: TCP, TLS and the 101.
  final Duration connectTimeout;

  /// Notices a dead connection from this side; the server's own pings are
  /// answered regardless.
  final Duration pingInterval;

  /// Called once per [connect]; the client is closed after the upgrade. The
  /// app passes one with a server's own TLS settings (pinned certificate,
  /// trusted CA, client certificate).
  final HttpClient Function() createHttpClient;

  @override
  Future<RealtimeSocket> connect(
    Uri url, {
    Map<String, String> headers = const {},
  }) async {
    if (!url.isScheme('ws') && !url.isScheme('wss')) {
      throw ArgumentError('A realtime URL needs the ws or wss scheme');
    }
    final client = createHttpClient()..connectionTimeout = connectTimeout;
    final handshake = _upgrade(client, url, headers);
    final Socket socket;
    try {
      socket = await handshake.timeout(connectTimeout);
    } on TimeoutException {
      unawaited(
        handshake.then((orphan) => orphan.destroy(), onError: (Object _) {}),
      );
      rethrow;
    } finally {
      // The upgraded socket is detached and survives this.
      client.close(force: true);
    }
    final webSocket = WebSocket.fromUpgradedSocket(
      _ErrorAsEnd(socket),
      serverSide: false,
      compression: CompressionOptions.compressionOff,
    )..pingInterval = pingInterval;
    return _IoRealtimeSocket(webSocket);
  }

  Future<Socket> _upgrade(
    HttpClient client,
    Uri url,
    Map<String, String> headers,
  ) async {
    final key = base64.encode([
      for (var i = 0; i < 16; i++) _random.nextInt(256),
    ]);
    final request = await client.openUrl(
      'GET',
      url.replace(scheme: url.isScheme('wss') ? 'https' : 'http'),
    );
    // A redirect would carry the upgrade to wherever it points.
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set('Sec-WebSocket-Version', '13')
      ..set('Sec-WebSocket-Key', key);
    final response = await request.close();

    final status = response.statusCode;
    if (status != HttpStatus.switchingProtocols) {
      throw RealtimeUpgradeRefused(
        status,
        retryAfter: status == HttpStatus.tooManyRequests
            ? retryAfterFromHeaders((name) => response.headers[name]?.first)
            : null,
      );
    }
    final connection =
        response.headers[HttpHeaders.connectionHeader] ?? const <String>[];
    if (!connection.any((token) => token.toLowerCase() == 'upgrade') ||
        response.headers.value(HttpHeaders.upgradeHeader)?.toLowerCase() !=
            'websocket') {
      throw const WebSocketException('The 101 answer is no WebSocket upgrade');
    }
    final expectedAccept = base64.encode(
      sha1.convert(ascii.encode('$key$_acceptGuid')).bytes,
    );
    if (response.headers.value('sec-websocket-accept') != expectedAccept) {
      throw const WebSocketException('Wrong Sec-WebSocket-Accept');
    }
    return await response.detachSocket();
  }
}

final class _IoRealtimeSocket implements RealtimeSocket {
  new(this._webSocket);

  final WebSocket _webSocket;
  var _closing = false;

  @override
  late final Stream<RealtimeMessage> messages = _webSocket.map(
    decodeRealtimeMessage,
  );

  @override
  void authenticate(String token) => _send(encodeAuthFrame(token));

  @override
  void subscribe(String event) => _send(encodeSubscribeFrame(event));

  // After close() the sink throws; after the server closed, dart:io drops
  // the frame itself.
  void _send(String frame) {
    if (!_closing) _webSocket.add(frame);
  }

  @override
  int? get closeCode => switch (_webSocket.closeCode) {
    // dart:io's code for a connection that ended without a close frame; it
    // never travels in one.
    WebSocketStatus.abnormalClosure => null,
    final code => code,
  };

  @override
  String? get closeReason => closeCode == null ? null : _webSocket.closeReason;

  @override
  Future<void> close([int code = 1000]) async {
    _closing = true;
    await _webSocket.close(code);
  }
}

/// dart:io reports a read error such as a connection reset as close code
/// 1002, like a protocol error the server announced. Ending the stream
/// instead makes it the drop it is.
final class _ErrorAsEnd extends Stream<Uint8List> implements Socket {
  new(this._socket);

  final Socket _socket;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _socket
      .transform(
        StreamTransformer<Uint8List, Uint8List>.fromHandlers(
          handleError: (_, _, sink) => sink.close(),
        ),
      )
      .listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  Encoding get encoding => _socket.encoding;

  @override
  set encoding(Encoding value) => _socket.encoding = value;

  @override
  void write(Object? object) => _socket.write(object);

  @override
  void writeln([Object? object = '']) => _socket.writeln(object);

  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _socket.writeAll(objects, separator);

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _socket.addStream(stream);

  @override
  Future<void> flush() => _socket.flush();

  @override
  Future<void> close() => _socket.close();

  @override
  Future<void> get done => _socket.done;

  @override
  void destroy() => _socket.destroy();

  @override
  int get port => _socket.port;

  @override
  int get remotePort => _socket.remotePort;

  @override
  InternetAddress get address => _socket.address;

  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;

  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
}
