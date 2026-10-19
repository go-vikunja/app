import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/server_connection.dart';

ServerConnection _connection(String root, {bool hasV2 = true}) =>
    testConnection(root: root, hasV2: hasV2);

String _realtime(String root, {bool hasV2 = true}) =>
    realtimeUri(_connection(root, hasV2: hasV2)).toString();

void main() {
  test('https becomes wss on the v2 path', () {
    expect(
      _realtime('https://tasks.example.com'),
      'wss://tasks.example.com/api/v2/ws',
    );
  });

  test('http becomes ws', () {
    expect(
      _realtime('http://localhost:34527'),
      'ws://localhost:34527/api/v2/ws',
    );
  });

  test('a server without v2 uses the v1 path', () {
    expect(
      _realtime('https://tasks.example.com', hasV2: false),
      'wss://tasks.example.com/api/v1/ws',
    );
    expect(
      _realtime('http://192.168.1.20:3456', hasV2: false),
      'ws://192.168.1.20:3456/api/v1/ws',
    );
  });

  test('a sub-path is kept', () {
    expect(
      _realtime('https://example.com/apps/vikunja'),
      'wss://example.com/apps/vikunja/api/v2/ws',
    );
    expect(
      _realtime('https://example.com/vikunja', hasV2: false),
      'wss://example.com/vikunja/api/v1/ws',
    );
  });

  test('an explicit port is kept, a default one stays implicit', () {
    expect(
      _realtime('https://example.com:8443/vikunja'),
      'wss://example.com:8443/vikunja/api/v2/ws',
    );
    expect(_realtime('https://example.com:443'), 'wss://example.com/api/v2/ws');
    expect(_realtime('http://example.com:80'), 'ws://example.com/api/v2/ws');
  });

  test("the other scheme's default port is not dropped", () {
    final plainOn443 = realtimeUri(_connection('http://example.com:443'));
    final tlsOn80 = realtimeUri(_connection('https://example.com:80'));

    expect(plainOn443.toString(), 'ws://example.com:443/api/v2/ws');
    expect(plainOn443.port, 443);
    expect(tlsOn80.toString(), 'wss://example.com:80/api/v2/ws');
    expect(tlsOn80.port, 80);
  });

  test('IPv6 hosts keep their brackets', () {
    expect(_realtime('http://[::1]:3456'), 'ws://[::1]:3456/api/v2/ws');
    expect(
      _realtime('https://[2001:db8::7]/vikunja', hasV2: false),
      'wss://[2001:db8::7]/vikunja/api/v1/ws',
    );
  });
}
