import 'package:test/test.dart';
import 'package:vikunja_app/core/utils/validator.dart';

void main() {
  group('Email validation tests', () {
    final emailTestCases = <String?, bool>{
      // Valid emails
      'test@example.com': true,
      'user.name@domain.co.uk': true,
      'first.last+tag@subdomain.example.com': true,
      'user123@test-domain.com': true,
      'a@b.co': true,

      // Invalid emails
      'invalid-email': false,
      'test@': false,
      '@example.com': false,
      'test..email@example.com': false,
      'test@example': false,
      '': false,
      null: false,
    };

    emailTestCases.forEach((input, expected) {
      String description = input == null ? 'null' : '"$input"';
      test('$description should return $expected', () {
        expect(isEmail(input), expected);
      });
    });
  });

  group('URL validation tests', () {
    final urlTestCases = <String?, bool>{
      // Valid HTTP URLs
      'http://example.com': true,
      'http://www.example.com': true,
      'http://sub.example.com': true,
      'http://example.com:8080': true,
      'http://192.168.1.1': true,
      'http://192.168.1.1:3000': true,

      // Valid HTTPS URLs
      'https://example.com': true,
      'https://www.example.com': true,
      'https://sub.example.com': true,
      'https://example.com:8080': true,
      'https://192.168.1.1': true,
      'https://192.168.1.1:3000': true,

      // Invalid URLs
      'not-a-url': false,
      'ftp://example.com': false,
      'http://': false,
      'https://': false,
      '': false,
      null: false,
    };

    urlTestCases.forEach((input, expected) {
      String description = input == null ? 'null' : '"$input"';
      test('$description should return $expected', () {
        expect(isUrl(input), expected);
      });
    });
  });
}
