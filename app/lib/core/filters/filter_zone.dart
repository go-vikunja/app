import 'dart:io' show Platform;

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_logic/vikunja_logic.dart' show filterLocation;

var _databaseLoaded = false;

/// The bundled zone database, loaded on first use: the names a timezone
/// setting can hold include the old aliases (`Asia/Calcutta`).
void ensureTimeZones() {
  if (_databaseLoaded) return;
  tz_data.initializeTimeZones();
  _databaseLoaded = true;
}

/// The zone a filter's relative dates (`now/d`) and bare dates are placed
/// in: the first of [names] that is a known zone, else the device's.
tz.Location locationForFilters(Iterable<String> names) {
  ensureTimeZones();
  for (final name in names) {
    if (filterLocation(name.trim()) case final location?) return location;
  }
  return deviceLocation();
}

({String key, tz.Location location})? _device;

/// Dart names the device's zone only by its abbreviation, so the zone is
/// the bundled one whose offsets equal the device's over the coming year,
/// preferring one with the same abbreviation; `TZ` decides where it is set
/// (tests, desktops). Looked up again when the device's zone changes.
tz.Location deviceLocation() {
  ensureTimeZones();
  final now = DateTime.now();
  final key = '${now.timeZoneName}/${now.timeZoneOffset.inMinutes}';
  if (_device case (key: final cached, :final location) when cached == key) {
    return location;
  }
  final location =
      filterLocation(Platform.environment['TZ'] ?? '') ??
      _matchingDeviceOffsets(now);
  _device = (key: key, location: location);
  return location;
}

tz.Location _matchingDeviceOffsets(DateTime now) {
  final samples = [
    for (var week = 0; week <= 52; week++)
      now.toUtc().add(Duration(days: 7 * week)),
  ];
  bool sameOffsets(tz.Location location) => samples.every(
    (instant) =>
        location.timeZone(instant.millisecondsSinceEpoch).offset ==
        instant.toLocal().timeZoneOffset,
  );
  final candidates = [
    for (final location in tz.timeZoneDatabase.locations.values)
      if (location.name.contains('/') &&
          !location.name.startsWith('Etc/') &&
          sameOffsets(location))
        location,
  ]..sort((a, b) => a.name.compareTo(b.name));
  final abbreviation = now.timeZoneName;
  return candidates
          .where(
            (location) =>
                location.timeZone(now.millisecondsSinceEpoch).abbreviation ==
                abbreviation,
          )
          .firstOrNull ??
      candidates.firstOrNull ??
      _fixedOffset(now.timeZoneOffset);
}

/// `Etc/GMT-2` is two hours east of Greenwich: the sign is inverted.
tz.Location _fixedOffset(Duration offset) {
  if (offset.inMinutes % 60 != 0) return tz.UTC;
  final hours = offset.inHours;
  if (hours == 0) return tz.UTC;
  return filterLocation('Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}') ??
      tz.UTC;
}
