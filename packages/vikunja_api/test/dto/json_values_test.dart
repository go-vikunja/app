import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/dto/json_values.dart';

void main() {
  group('dateOf', () {
    test('converts the server zone to UTC', () {
      expect(
        dateOf('2026-10-08T14:00:00+02:00'),
        DateTime.utc(2026, 10, 8, 12),
      );
      expect(dateOf('2026-10-08T14:00:00Z'), DateTime.utc(2026, 10, 8, 14));
      expect(dateOf('2026-10-08T14:00:00Z')!.isUtc, isTrue);
    });

    test('treats the zero date and years up to 1 as no date', () {
      expect(dateOf('0001-01-01T00:00:00Z'), isNull);
      expect(dateOf('0001-01-01T01:00:00+01:00'), isNull);
      expect(dateOf('0000-12-31T23:00:00Z'), isNull);
    });

    test('ignores non-dates', () {
      expect(dateOf(null), isNull);
      expect(dateOf(''), isNull);
      expect(dateOf('yesterday'), isNull);
      expect(dateOf(1760000000), isNull);
    });
  });

  group('hexColorOf', () {
    test('strips the hash and lowercases', () {
      expect(hexColorOf('#FF00aa'), 'ff00aa');
      expect(hexColorOf('1973FF'), '1973ff');
      expect(hexColorOf(' #4caf50 '), '4caf50');
    });

    test('expands the short form', () {
      expect(hexColorOf('abc'), 'aabbcc');
      expect(hexColorOf('#F0A'), 'ff00aa');
    });

    test('is empty for anything else', () {
      expect(hexColorOf(''), '');
      expect(hexColorOf(null), '');
      expect(hexColorOf('xyz123'), '');
      expect(hexColorOf('#1234567'), '');
      expect(hexColorOf('12345'), '');
      expect(hexColorOf(0xff00aa), '');
    });
  });

  test('lenient accessors fall back on the wrong type', () {
    final json = <String, Object?>{
      'n': '5',
      'd': 1,
      'b': 'true',
      's': 2,
      'list': 'nope',
      'items': [
        1,
        'a',
        <String, Object?>{'id': 1},
      ],
    };

    expect(intOr(json, 'n', 7), 7);
    expect(doubleOr(json, 'd', 0), 1.0);
    expect(boolOr(json, 'b', fallback: true), isTrue);
    expect(stringOr(json, 's', 'x'), 'x');
    expect(objectListOf(json['list']), isEmpty);
    expect(objectListOf(json['items']), [
      {'id': 1},
    ]);
    expect(stringListOf(json['items']), ['a']);
  });

  test('required accessors name the entity and the field', () {
    expect(
      () => requireInt({'id': '1'}, 'id', 'task'),
      throwsA(
        isA<MalformedJson>().having(
          (e) => e.message,
          'message',
          'task without id',
        ),
      ),
    );
    expect(
      () => requireString({}, 'title', 'label'),
      throwsA(isA<MalformedJson>()),
    );
    expect(() => objectOf([], 'project'), throwsA(isA<MalformedJson>()));
  });
}
