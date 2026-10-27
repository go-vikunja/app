import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vikunja_mobile/core/network/certificate_info.dart';

/// The committed dummy set (`test/fixtures/tls/README.md`); tests run with
/// the app package as the working directory.
Uint8List tlsFixture(String name) =>
    File('test/fixtures/tls/$name').readAsBytesSync();

String tlsFixtureText(String name) =>
    File('test/fixtures/tls/$name').readAsStringSync();

String get tlsFixturePassword => tlsFixtureText('client-p12-password.txt');

Map<String, Object?> _manifest(String name) =>
    ((jsonDecode(tlsFixtureText('manifest.json'))
                as Map<String, Object?>)['certificates']!
            as Map<String, Object?>)[name]!
        as Map<String, Object?>;

/// `sha256` as dart:io and the trust sheet compute it.
String tlsFixtureSha256(String name) => _manifest(name)['sha256']! as String;

CertificateInfo tlsFixtureCertificate(String name) {
  final entry = _manifest(name);
  return CertificateInfo(
    sha256: entry['sha256']! as String,
    subject: entry['subject']! as String,
    issuer: entry['issuer']! as String,
    notBefore: DateTime.parse(entry['notBefore']! as String),
    notAfter: DateTime.parse(entry['notAfter']! as String),
  );
}

SecurityContext serverContext(String certificate, String key) =>
    SecurityContext()
      ..useCertificateChainBytes(tlsFixture(certificate))
      ..usePrivateKeyBytes(tlsFixture(key));

/// An HTTPS server on loopback that answers 200 with `ok` and records each
/// request that got through the handshake.
final class RecordingTlsServer {
  new _(this._server);

  static Future<RecordingTlsServer> start({
    String certificate = 'selfsigned.pem',
    String key = 'selfsigned.key',
    InternetAddress? address,
  }) async {
    final server = await HttpServer.bindSecure(
      address ?? InternetAddress.loopbackIPv4,
      0,
      serverContext(certificate, key),
    );
    return RecordingTlsServer._(server).._listen();
  }

  final HttpServer _server;
  final List<HttpHeaders> requests = [];
  final List<String> paths = [];

  int get port => _server.port;

  void _listen() {
    _server.listen((request) {
      requests.add(request.headers);
      paths.add(request.uri.path);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('ok');
      unawaited(request.response.close());
    });
  }

  Future<void> close() => _server.close(force: true);
}

/// An mTLS server that demands a certificate from `client-ca.pem` (TLS
/// 1.3: a refusal ends the connection only after the client finished its
/// handshake). Answers 200 on a raw socket; records whether a request
/// arrived and which client certificate it saw.
final class MutualTlsServer {
  new _(this._server);

  static Future<MutualTlsServer> start() async {
    final context = serverContext('server.pem', 'server.key')
      ..setTrustedCertificatesBytes(tlsFixture('client-ca.pem'))
      ..setClientAuthoritiesBytes(tlsFixture('client-ca.pem'));
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      context,
      requestClientCertificate: true,
      requireClientCertificate: true,
    );
    return MutualTlsServer._(server).._listen();
  }

  final SecureServerSocket _server;
  final List<String> clientSubjects = [];
  int requestsReceived = 0;

  int get port => _server.port;

  void _listen() {
    _server.listen(
      (socket) {
        if (socket.peerCertificate case final certificate?) {
          clientSubjects.add(certificate.subject);
        }
        socket.listen(
          (data) {
            if (!utf8.decode(data, allowMalformed: true).contains('\r\n\r\n')) {
              return;
            }
            requestsReceived++;
            socket
              ..write(
                'HTTP/1.1 200 OK\r\ncontent-length: 2\r\n'
                'connection: close\r\n\r\nok',
              )
              ..close().ignore();
          },
          onError: (Object _) {},
          cancelOnError: true,
        );
      },
      // A refused client certificate fails the server-side handshake.
      onError: (Object _) {},
    );
  }

  Future<void> close() => _server.close();
}

/// Completes TLS handshakes (any client), then hangs up on every request
/// without an answer, like a stale keep-alive connection; it never closes
/// a connection that sends nothing.
final class HangUpTlsServer {
  new _(this._server);

  static Future<HangUpTlsServer> start() async => HangUpTlsServer._(
    await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      serverContext('server.pem', 'server.key'),
    ),
  ).._listen();

  final SecureServerSocket _server;
  final _open = <SecureSocket>[];

  int get port => _server.port;

  void _listen() {
    _server.listen((socket) {
      _open.add(socket);
      socket.listen((_) => socket.destroy(), onError: (Object _) {});
    }, onError: (Object _) {});
  }

  Future<void> close() async {
    for (final socket in _open) {
      socket.destroy();
    }
    await _server.close();
  }
}
