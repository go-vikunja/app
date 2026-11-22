import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/insecure_connection_dialog.dart';

void main() {
  test('the device itself and the home network count as local', () {
    for (final host in [
      'localhost',
      'vikunja.localhost',
      '127.0.0.1',
      '127.1.2.3',
      '::1',
      '10.0.0.5',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.1.20',
      '169.254.10.1',
      'fe80::1',
      'fd12:3456::1',
      'nas.local',
      'NAS.Local.',
      'vikunja.home.arpa',
      'tasks.internal',
    ]) {
      expect(isLocalNetworkHost(host), isTrue, reason: host);
    }
  });

  test('public addresses and names do not', () {
    for (final host in [
      'tasks.example.org',
      'try.vikunja.io',
      '8.8.8.8',
      '172.15.0.1',
      '172.32.0.1',
      '192.169.1.1',
      '100.64.0.1',
      '2001:db8::1',
      'local.example.org',
      'localhost.example.org',
    ]) {
      expect(isLocalNetworkHost(host), isFalse, reason: host);
    }
  });
}
