import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  final root = Uri.parse('https://vikunja.example');

  test('a TLS failure names which certificate was refused', () {
    expect(
      '${TlsFailure(root, clientCertificateRefused: true)}',
      'TlsFailure(https://vikunja.example, null, certificateRejected: false, '
          'clientCertificateRefused: true)',
    );
    expect(TlsFailure(root).clientCertificateRefused, isFalse);
  });

  test('a connection settings failure names only its address and '
      'problem', () {
    final failure = ConnectionSettingsFailure(
      root,
      problem: ConnectionSettingsProblem.incomplete,
    );

    expect(failure.uri, root);
    expect(
      '$failure',
      'ConnectionSettingsFailure(https://vikunja.example, '
          'ConnectionSettingsProblem.incomplete)',
    );
  });

  test('every failure is exhaustively matchable', () {
    String describe(ServerConnectionFailure failure) => switch (failure) {
      InvalidServerAddress() => 'invalid',
      ServerUnreachable() => 'unreachable',
      ServerTimeout() => 'timeout',
      TlsFailure() => 'tls',
      ConnectionSettingsFailure() => 'settings',
      NotAVikunjaServer() => 'not vikunja',
      ServerUnavailable() => 'unavailable',
      BehindLoginProxy() => 'login proxy',
    };

    expect(
      describe(
        ConnectionSettingsFailure(
          root,
          problem: ConnectionSettingsProblem.locked,
        ),
      ),
      'settings',
    );
  });

  test('the transport exceptions print only their class and origin', () {
    const origin = 'https://vikunja.example:443';

    expect(
      [
        const CleartextBlockedException('http://vikunja.example:80'),
        const ConnectionProfileLockedException(origin),
        const ConnectionProfileIncompleteException(origin),
        const ConnectionProfilesDamagedException(),
        const ClientCertificateRefusedException(origin),
      ].map((e) => '$e'),
      [
        'CleartextBlockedException(http://vikunja.example:80)',
        'ConnectionProfileLockedException($origin)',
        'ConnectionProfileIncompleteException($origin)',
        'ConnectionProfilesDamagedException',
        'ClientCertificateRefusedException($origin)',
      ],
    );
  });
}
