import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_mobile/core/filters/filter_zone.dart';

void main() {
  test('the first known zone of the names wins', () {
    expect(
      locationForFilters(['', 'Europe/Berlin', 'UTC']).name,
      'Europe/Berlin',
    );
    expect(
      locationForFilters(['Mars/Base', 'America/New_York']).name,
      'America/New_York',
    );
    expect(locationForFilters(['Asia/Calcutta']).name, 'Asia/Calcutta');
    expect(locationForFilters([' UTC ']), tz.UTC);
    expect(locationForFilters(['GMT']).timeZone(0).offset, Duration.zero);
  });

  test("without a known one it is a zone with the device's offsets over "
      'the coming year', () {
    final device = locationForFilters(['', 'Invalid/Zone']);

    for (var week = 0; week <= 52; week += 13) {
      final instant = DateTime.now().toUtc().add(Duration(days: 7 * week));
      expect(
        device.timeZone(instant.millisecondsSinceEpoch).offset,
        instant.toLocal().timeZoneOffset,
      );
    }
    expect(deviceLocation(), same(device));
  });
}
