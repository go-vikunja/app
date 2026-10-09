import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';

import '../helpers/jwt.dart';

String _withPayload(Object payload, {bool padded = false}) {
  var encoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
  if (!padded) encoded = encoded.replaceAll('=', '');
  return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$encoded.c2ln';
}

void main() {
  test('reads a 2.7.0 user token', () {
    final claims = JwtClaims.tryParse(
      fakeJwt(
        id: 42,
        username: 'bob',
        sid: 'session-1',
        issuedAt: DateTime.utc(2026, 10, 9, 8),
        expiresAt: DateTime.utc(2026, 10, 9, 8, 10),
      ),
    )!;

    expect(claims.userId, 42);
    expect(claims.username, 'bob');
    expect(claims.sessionId, 'session-1');
    expect(claims.issuedAt, DateTime.utc(2026, 10, 9, 8));
    expect(claims.expiresAt, DateTime.utc(2026, 10, 9, 8, 10));
    expect(claims.expiresAt.isUtc, isTrue);
  });

  test('2.3.0 and 2.4.0 tokens have no iat', () {
    final claims = JwtClaims.tryParse(
      _withPayload({
        'exp': 1791533915,
        'id': 3,
        'jti': '0b6f3c1e',
        'sid': 'session-2',
        'type': 1,
        'username': 'carol',
      }),
    )!;

    expect(claims.issuedAt, isNull);
    expect(
      claims.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1791533915000, isUtc: true),
    );
  });

  test('padding in the payload is tolerated', () {
    for (final username in ['a', 'ab', 'abc']) {
      final payload = {
        'exp': 1791533915,
        'id': 1,
        'sid': 's',
        'type': 1,
        'username': username,
      };
      expect(
        JwtClaims.tryParse(_withPayload(payload, padded: true))?.username,
        username,
      );
      expect(JwtClaims.tryParse(_withPayload(payload))?.username, username);
    }
  });

  test('numeric claims may be floating point', () {
    final claims = JwtClaims.tryParse(
      _withPayload({
        'exp': 1791533915.5,
        'iat': 1791533315.0,
        'id': 1.0,
        'sid': 's',
        'type': 1.0,
        'username': 'u',
      }),
    )!;

    expect(claims.userId, 1);
    expect(
      claims.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1791533915500, isUtc: true),
    );
  });

  final valid = {
    'exp': 1791533915,
    'id': 1,
    'sid': 's',
    'type': 1,
    'username': 'u',
  };
  for (final (description, token) in [
    ('a link share token', fakeJwt(type: 2)),
    ('an API token', 'tk_0123456789abcdef'),
    ('a token without sid', fakeJwt(sid: null)),
    ('an empty sid', _withPayload({...valid, 'sid': ''})),
    ('no exp', _withPayload({...valid}..remove('exp'))),
    ('an exp beyond DateTime', _withPayload({...valid, 'exp': 1e20})),
    ('a string id', _withPayload({...valid, 'id': '1'})),
    ('a fractional id', _withPayload({...valid, 'id': 1.5})),
    ('no username', _withPayload({...valid}..remove('username'))),
    ('a JSON array payload', _withPayload([1, 2])),
    ('two segments', 'a.b'),
    ('garbage base64', 'a.!!!.c'),
    ('a payload that is not JSON', 'a.${base64Url.encode(utf8.encode('{'))}.c'),
    ('a payload that is not UTF-8', 'a.${base64Url.encode([0xff, 0xfe])}.c'),
    ('an empty string', ''),
  ]) {
    test('rejects $description', () {
      expect(JwtClaims.tryParse(token), isNull);
    });
  }

  test('toString shows no token material', () {
    final claims = JwtClaims.tryParse(fakeJwt())!;

    expect('$claims', isNot(contains('alice')));
    expect('$claims', contains('${claims.userId}'));
  });
}
