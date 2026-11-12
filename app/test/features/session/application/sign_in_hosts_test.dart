import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_hosts.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/server_connections.dart';

OtherSignInHost? _other({required String root, String? frontend}) =>
    otherSignInHost(
      accountPagesServer270(
        root: root,
        frontendUrl: frontend == null ? null : Uri.parse(frontend),
      ),
    );

void main() {
  group('the sign-in page is on another host', () {
    test('not without a frontend_url, nor on the same origin under another '
        'path or in another case', () {
      expect(_other(root: 'https://tasks.example.org/vikunja'), isNull);
      expect(
        _other(
          root: 'https://tasks.example.org/vikunja',
          frontend: 'https://Tasks.Example.org:443/web/',
        ),
        isNull,
      );
    });

    test('not for an international name in Unicode, which the server '
        'address has in punycode', () {
      final root = normalizeServerAddress('https://aufgaben.müller.example');

      expect(
        _other(
          root: '${root.root}',
          frontend: 'https://aufgaben.müller.example/',
        ),
        isNull,
      );
    });

    test('not for the same host with or without its trailing dot', () {
      expect(
        _other(
          root: 'https://tasks.example.org.',
          frontend: 'https://tasks.example.org/',
        ),
        isNull,
      );
      expect(
        _other(
          root: 'https://tasks.example.org',
          frontend: 'https://tasks.example.org./',
        ),
        isNull,
      );
    });

    test("not for an https server's http frontend_url, which is not used", () {
      expect(
        _other(
          root: 'https://tasks.example.org',
          frontend: 'http://evil.example.net/',
        ),
        isNull,
      );
    });

    test('on another host, named with both hosts', () {
      final other = _other(
        root: 'https://tasks.example.org/vikunja',
        frontend: 'https://auth.example.org/',
      );

      expect(other?.server, 'tasks.example.org');
      expect(other?.signInPage, 'auth.example.org');
      expect(
        other?.origin,
        OriginKey.of(Uri.parse('https://auth.example.org')),
      );
    });

    test('on another international host, named in punycode', () {
      final other = _other(
        root: 'https://tasks.example.org',
        frontend: 'https://anmeldung.müller.example/',
      );

      expect(other?.signInPage, 'anmeldung.xn--mller-kva.example');
      expect(
        other?.origin,
        OriginKey.of(Uri.parse('https://anmeldung.xn--mller-kva.example')),
      );
    });

    test('on a host that is no UTF-8, named as it came', () {
      final other = _other(
        root: 'https://tasks.example.org',
        frontend: 'https://%ff.example.net/',
      );

      expect(other?.signInPage, '%ff.example.net');
    });

    test('on another port of the same host', () {
      final other = _other(
        root: 'https://tasks.example.org',
        frontend: 'https://tasks.example.org:8443/',
      );

      expect(other?.server, 'tasks.example.org');
      expect(other?.signInPage, 'tasks.example.org:8443');
    });

    test('in another scheme only, which the texts then show', () {
      final other = _other(
        root: 'http://192.168.1.20',
        frontend: 'https://192.168.1.20/',
      );

      expect(other?.server, 'http://192.168.1.20');
      expect(other?.signInPage, 'https://192.168.1.20');
    });

    test('at an address that is no web page, which has no origin to '
        'remember', () {
      final other = _other(
        root: 'http://192.168.1.20:3456',
        frontend: 'ftp://files.example.org/',
      );

      expect(other?.signInPage, 'ftp://files.example.org');
      expect(other?.origin, isNull);
    });
  });

  group('confirmed hosts', () {
    late MemoryPreferencesStore preferences;
    late ConfirmedSignInHosts hosts;
    final auth = _other(
      root: 'https://tasks.example.org',
      frontend: 'https://auth.example.org/',
    )!;
    final login = _other(
      root: 'https://tasks.example.org',
      frontend: 'https://login.example.net/',
    )!;

    setUp(() {
      preferences = MemoryPreferencesStore();
      hosts = ConfirmedSignInHosts(preferences);
    });

    test('hold the host each account signed in at, and only that '
        'one', () async {
      await hosts.signedIn('alice-id', auth);

      expect(await hosts.isConfirmed('alice-id', auth), isTrue);
      expect(await hosts.isConfirmed('alice-id', login), isFalse);
      expect(await hosts.isConfirmed('bob-id', auth), isFalse);

      await hosts.signedIn('alice-id', login);
      expect(await hosts.isConfirmed('alice-id', auth), isFalse);
      expect(await hosts.isConfirmed('alice-id', login), isTrue);
    });

    test('a page without an origin is never remembered', () async {
      final noWebPage = _other(
        root: 'http://192.168.1.20:3456',
        frontend: 'ftp://files.example.org/',
      )!;

      await hosts.signedIn('alice-id', noWebPage);

      expect(await hosts.isConfirmed('alice-id', noWebPage), isFalse);
      expect(preferences.values, isEmpty);
    });

    test('damaged or unreadable storage counts as not confirmed, and a '
        'sign-in replaces it', () async {
      preferences.values[confirmedSignInHostsKey] = '[1, 2';
      expect(await hosts.isConfirmed('alice-id', auth), isFalse);

      await hosts.signedIn('alice-id', auth);
      expect(await hosts.isConfirmed('alice-id', auth), isTrue);

      preferences.failNextRead.add(confirmedSignInHostsKey);
      expect(await hosts.isConfirmed('alice-id', auth), isFalse);
    });

    test("a sign-in on the server's own origin, or forgetting the account, "
        'takes its host away; the last one leaves nothing behind', () async {
      await hosts.signedIn('alice-id', auth);
      await hosts.signedIn('bob-id', login);

      await hosts.signedIn('alice-id', null);
      expect(await hosts.isConfirmed('alice-id', auth), isFalse);
      expect(await hosts.isConfirmed('bob-id', login), isTrue);

      await hosts.forget('bob-id');
      expect(await hosts.isConfirmed('bob-id', login), isFalse);
      expect(preferences.values, isNot(contains(confirmedSignInHostsKey)));
    });
  });
}
