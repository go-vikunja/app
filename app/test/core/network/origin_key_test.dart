import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

void main() {
  test('scheme, lower-case host and the effective port', () {
    final origin = OriginKey.of(Uri.parse('https://Tasks.Example.ORG/vikunja'));

    expect(origin.scheme, 'https');
    expect(origin.host, 'tasks.example.org');
    expect(origin.port, 443);
    expect(origin.toString(), 'https://tasks.example.org:443');
    expect(origin.authority, 'tasks.example.org');
  });

  test('ws and wss count as http and https, with their default ports', () {
    expect(
      OriginKey.of(Uri.parse('wss://example.com/api/v2/ws')),
      OriginKey.of(Uri.parse('https://example.com:443/')),
    );
    expect(
      OriginKey.of(Uri.parse('ws://192.168.1.20:3456/api/v2/ws')).toString(),
      'http://192.168.1.20:3456',
    );
    expect(OriginKey.of(Uri.parse('ws://example.com')).port, 80);
  });

  test('two servers under different paths of one origin share it', () {
    expect(
      OriginKey.of(Uri.parse('https://example.com/a')),
      OriginKey.of(Uri.parse('https://example.com/b/')),
    );
    expect(
      OriginKey.of(Uri.parse('https://example.com')),
      isNot(OriginKey.of(Uri.parse('https://example.com:3456'))),
    );
  });

  test('an IPv6 host stays bare; the string form brackets it', () {
    final origin = OriginKey.of(Uri.parse('https://[::1]:8443/api/v1/info'));

    expect(origin.host, '::1');
    expect(origin.toString(), 'https://[::1]:8443');
    expect(origin.authority, '[::1]:8443');
    expect(OriginKey.fromString('https://[::1]:8443'), origin);
    expect(origin.uri.host, '::1');
  });

  test('a Punycode host as normalizeServerAddress produces it', () {
    final root = normalizeServerAddress('https://bücher.example').root;

    expect(OriginKey.of(root).toString(), 'https://xn--bcher-kva.example:443');
  });

  test('fromString parses exactly the string form', () {
    for (final value in [
      'https://example.com:443',
      'http://10.0.0.2:80',
      'http://[fe80::1]:3456',
    ]) {
      expect(OriginKey.fromString(value).toString(), value);
    }
    for (final value in [
      'https://example.com',
      'https://Example.com:443',
      'https://example.com:443/',
      'ftp://example.com:21',
      'https://::1:443',
      'https://example.com:99999',
      'https://example.com:0443',
    ]) {
      expect(OriginKey.tryParse(value), isNull, reason: value);
      expect(() => OriginKey.fromString(value), throwsFormatException);
    }
  });

  test('other schemes and URLs without a host are refused', () {
    expect(
      () => OriginKey.of(Uri.parse('ftp://example.com')),
      throwsArgumentError,
    );
    expect(() => OriginKey.of(Uri.parse('/relative')), throwsArgumentError);
    expect(OriginKey.tryOf(Uri.parse('mailto:a@example.com')), isNull);
    expect(OriginKey.tryOf(Uri.parse('https://example.com')), isNotNull);
  });
}
