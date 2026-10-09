import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('ServerVersion.tryParse', () {
    for (final (raw, major, minor, patch, kept) in [
      ('v2.7.0', 2, 7, 0, 'v2.7.0'),
      ('2.7.0', 2, 7, 0, '2.7.0'),
      ('v2.7.0-12-gabc', 2, 7, 0, 'v2.7.0-12-gabc'),
      ('v2.7.0-6-ge7d7f173', 2, 7, 0, 'v2.7.0-6-ge7d7f173'),
      ('v2.8.0-rc1', 2, 8, 0, 'v2.8.0-rc1'),
      ('  v1.0.0 ', 1, 0, 0, 'v1.0.0'),
      ('v0.24.6', 0, 24, 6, 'v0.24.6'),
      ('v2.4', 2, 4, 0, 'v2.4'),
      ('v10.11.12', 10, 11, 12, 'v10.11.12'),
    ]) {
      test(raw, () {
        final version = ServerVersion.tryParse(raw)!;
        expect(version.major, major);
        expect(version.minor, minor);
        expect(version.patch, patch);
        expect(version.isDevelopmentBuild, isFalse);
        expect(version.raw, kept);
        expect(version.display, '$major.$minor.$patch');
      });
    }

    for (final raw in ['dev', 'unstable', 'main', ' Unstable ']) {
      test('"$raw" is a development build', () {
        final version = ServerVersion.tryParse(raw)!;
        expect(version.isDevelopmentBuild, isTrue);
        expect(version.raw, raw.trim());
        expect(version.display, raw.trim());
      });
    }

    for (final raw in [
      'garbage',
      '',
      '   ',
      'v',
      'version 2.7.0',
      'x2.7.0',
      'v99999999999999999999.0.0',
      'v2.99999999999999999999.0',
      'v2.7.99999999999999999999',
    ]) {
      test('"$raw" is not a version', () {
        expect(ServerVersion.tryParse(raw), isNull);
      });
    }
  });

  group('ServerVersion comparison', () {
    ServerVersion parse(String raw) => ServerVersion.tryParse(raw)!;

    test('orders by major, minor, patch', () {
      final sorted = [
        parse('v2.10.0'),
        parse('v1.0.0'),
        parse('v2.7.1'),
        parse('v2.7.0'),
        parse('v0.24.6'),
      ]..sort();
      expect(sorted.map((v) => v.display), [
        '0.24.6',
        '1.0.0',
        '2.7.0',
        '2.7.1',
        '2.10.0',
      ]);
    });

    test('a build after a tag equals the tag', () {
      expect(parse('v2.7.0-12-gabc'), parse('v2.7.0'));
      expect(parse('v2.7.0-12-gabc').hashCode, parse('v2.7.0').hashCode);
    });

    test('development builds sort above every release', () {
      expect(parse('dev').compareTo(parse('v99.0.0')), greaterThan(0));
      expect(parse('v99.0.0') < parse('unstable'), isTrue);
      expect(parse('dev'), parse('unstable'));
      expect(parse('dev').hashCode, parse('unstable').hashCode);
      expect(parse('dev').isAtLeast(2, 4), isTrue);
    });

    test('isAtLeast', () {
      final version = parse('v2.4.1');
      expect(version.isAtLeast(2), isTrue);
      expect(version.isAtLeast(2, 4), isTrue);
      expect(version.isAtLeast(2, 4, 1), isTrue);
      expect(version.isAtLeast(2, 4, 2), isFalse);
      expect(version.isAtLeast(2, 5), isFalse);
      expect(version.isAtLeast(3), isFalse);
    });

    test('operators', () {
      expect(
        parse('v2.2.9') < ServerCapabilities.minimumSupportedVersion,
        isTrue,
      );
      expect(
        parse('v2.3.0') >= ServerCapabilities.minimumSupportedVersion,
        isTrue,
      );
    });
  });
}
