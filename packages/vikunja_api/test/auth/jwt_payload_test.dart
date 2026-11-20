import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/auth/jwt_payload.dart';

String _token(String payload, {bool padded = false}) {
  var encoded = base64Url.encode(utf8.encode(payload));
  if (!padded) encoded = encoded.replaceAll('=', '');
  return 'eyJhbGciOiJIUzI1NiJ9.$encoded.c2ln';
}

void main() {
  test('jwtPayload reads the middle part as a JSON object', () {
    final cases = <String, Map<String, Object?>?>{
      _token('{"id":7,"name":"x"}'): {'id': 7, 'name': 'x'},
      _token('{"a":1}', padded: true): {'a': 1},
      _token('{}'): {},
      _token('[1,2]'): null,
      _token('"text"'): null,
      _token('42'): null,
      _token('not json'): null,
      'only.two': null,
      'a.b.c.d': null,
      '': null,
      'x.%%%.y': null,
      'x.${base64Url.encode([0xff, 0xfe])}.y': null,
    };
    for (final MapEntry(key: token, value: expected) in cases.entries) {
      expect(jwtPayload(token), expected, reason: token);
    }
  });

  test('jwtInteger takes whole numbers only', () {
    final cases = <Object?, int?>{
      3: 3,
      -2: -2,
      4.0: 4,
      4.5: null,
      '4': null,
      null: null,
      true: null,
    };
    for (final MapEntry(key: value, value: expected) in cases.entries) {
      expect(jwtInteger(value), expected, reason: '$value');
    }
  });

  test('jwtTime reads seconds in UTC within what DateTime can hold', () {
    final cases = <Object?, DateTime?>{
      0: DateTime.utc(1970),
      1791533915: DateTime.fromMillisecondsSinceEpoch(
        1791533915000,
        isUtc: true,
      ),
      1.5: DateTime.fromMillisecondsSinceEpoch(1500, isUtc: true),
      8640000000000: DateTime.fromMillisecondsSinceEpoch(
        8640000000000000,
        isUtc: true,
      ),
      8640000000001: null,
      double.nan: null,
      double.infinity: null,
      '1791533915': null,
      null: null,
    };
    for (final MapEntry(key: value, value: expected) in cases.entries) {
      final time = jwtTime(value);
      expect(time, expected, reason: '$value');
      if (time != null) expect(time.isUtc, isTrue, reason: '$value');
    }
  });
}
