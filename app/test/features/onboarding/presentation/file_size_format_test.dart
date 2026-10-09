import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/file_size_format.dart';

void main() {
  const mebibyte = 1024 * 1024;

  for (final (bytes, locale, expected) in [
    (20 * mebibyte, 'en', '20 MB'),
    (20 * mebibyte, 'de', '20 MB'),
    (1000 * mebibyte, 'en', '1,000 MB'),
    (1000 * mebibyte, 'de', '1.000 MB'),
    (1024 * mebibyte, 'en', '1 GB'),
    (1536 * mebibyte, 'en', '1.5 GB'),
    (1536 * mebibyte, 'de', '1,5 GB'),
    (2 * 1024 * 1024 * mebibyte, 'en', '2 TB'),
  ]) {
    test('$bytes bytes in $locale is $expected', () {
      expect(formatFileSize(bytes, locale), expected);
    });
  }
}
