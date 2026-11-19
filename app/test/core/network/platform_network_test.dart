import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/network/platform_network.dart';

import '../../helpers/tls_fixtures.dart';

void main() {
  test('a CA dart:io cannot read is left out', () {
    platformHttpClient((
      userCaPems: [tlsFixtureText('ca.pem'), 'not a certificate'],
      proxy: 'DIRECT',
    )).close();
  });

  test('the proxy is chosen for the handshake, an HTTP request', () {
    expect(
      handshakeUrl(Uri.parse('wss://tasks.example.org/api/v2/ws')),
      Uri.parse('https://tasks.example.org/api/v2/ws'),
    );
    expect(
      handshakeUrl(Uri.parse('ws://10.0.0.2:3456/api/v1/ws')),
      Uri.parse('http://10.0.0.2:3456/api/v1/ws'),
    );
  });

  test('only Android asks the platform', () {
    expect(platformNetworkFor(TargetPlatform.android), isNotNull);
    expect(platformNetworkFor(TargetPlatform.iOS), isNull);
  });
}
