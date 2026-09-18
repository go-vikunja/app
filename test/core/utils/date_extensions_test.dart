import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('dateFormatShort', () {
    test('combines a medium date with a 24h time', () {
      final formatted = dateFormatShort(
        'en',
      ).format(DateTime(2024, 3, 14, 15, 9));

      expect(formatted, 'Mar 14, 2024 15:09');
    });

    test('pads single digit hours and minutes', () {
      final formatted = dateFormatShort(
        'en',
      ).format(DateTime(2024, 1, 2, 3, 4));

      expect(formatted, 'Jan 2, 2024 03:04');
    });
  });

  group('DateExtensions.formatShort', () {
    test('formats the receiver with the short format', () {
      final date = DateTime(2024, 12, 31, 23, 59);

      expect(date.formatShort(), dateFormatShort().format(date));
    });
  });
}
