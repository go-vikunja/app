import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/presentation/widgets/string_extension.dart';

void main() {
  group('StringExtensions.toUri', () {
    test('parses an absolute url', () {
      expect(
        'https://vikunja.io/api/v1'.toUri(),
        Uri.parse('https://vikunja.io/api/v1'),
      );
    });

    test('returns null for a string Uri cannot parse', () {
      expect('http://[invalid'.toUri(), isNull);
    });
  });
}
