import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_logic/vikunja_logic.dart' show filterLocation;
import 'package:vikunja_mobile/core/filters/filter_zone.dart';

@immutable
final class TimeZoneChoice {
  const new({required this.name, required this.offset});

  /// The IANA name the setting stores, e.g. `America/New_York`.
  final String name;

  /// From UTC at the moment the list was made.
  final Duration offset;

  /// As the web shows the names: `America/New York`.
  String get label => name.replaceAll('_', ' ');
}

/// Every zone of the bundled database by name; the server checks a name
/// with its own copy, so a very new zone may still be refused there.
List<TimeZoneChoice> timeZoneChoices(DateTime at) {
  ensureTimeZones();
  final instant = at.millisecondsSinceEpoch;
  return [
    for (final location in tz.timeZoneDatabase.locations.values)
      TimeZoneChoice(
        name: location.name,
        offset: location.timeZone(instant).offset,
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// The zones to offer above the full list for the account now set to
/// [current]. Dart knows the device's zone only by its offsets, which
/// dozens of zones share (Europe/Berlin with Africa/Ceuta), so: [current]
/// alone when it is one of them ([sameAsDevice]), else the zone `TZ` names
/// ([envZone], a known one), else every zone with the device's offsets.
List<String> suggestedTimeZones({
  required String current,
  required Iterable<String> sameAsDevice,
  String? envZone,
}) {
  if (sameAsDevice.contains(current)) return [current];
  if (envZone != null) return [envZone];
  final inUse = [
    for (final name in sameAsDevice)
      if (!_isOldAlias(name)) name,
  ];
  return (inUse.isEmpty ? [...sameAsDevice] : inUse)..sort();
}

/// [suggestedTimeZones] for this device.
List<String> deviceTimeZoneSuggestions(String current) {
  ensureTimeZones();
  return suggestedTimeZones(
    current: current,
    sameAsDevice: zonesWithDeviceOffsets(),
    envZone: filterLocation(Platform.environment['TZ']?.trim() ?? '')?.name,
  );
}

/// Names the zone database keeps only for compatibility; the server still
/// takes them, so the full list keeps them.
bool _isOldAlias(String name) =>
    _oldRegionPrefixes.any(name.startsWith) || _oldAliases.contains(name);

const _oldRegionPrefixes = ['Brazil/', 'Canada/', 'Chile/', 'Mexico/', 'US/'];

const _oldAliases = {
  'America/Argentina/ComodRivadavia',
  'America/Buenos_Aires',
  'America/Catamarca',
  'America/Cordoba',
  'America/Ensenada',
  'America/Fort_Wayne',
  'America/Indianapolis',
  'America/Jujuy',
  'America/Louisville',
  'America/Mendoza',
  'America/Montreal',
  'America/Nipigon',
  'America/Pangnirtung',
  'America/Rosario',
  'America/Santa_Isabel',
  'America/Thunder_Bay',
  'Antarctica/South_Pole',
  'Asia/Calcutta',
  'Asia/Katmandu',
  'Asia/Rangoon',
  'Asia/Saigon',
  'Atlantic/Faeroe',
  'Atlantic/Jan_Mayen',
  'Australia/ACT',
  'Australia/Canberra',
  'Australia/Currie',
  'Australia/NSW',
  'Australia/Tasmania',
  'Australia/Victoria',
  'Europe/Belfast',
  'Europe/Kiev',
};

/// `UTC+02:00`, `UTC−03:30`, `UTC` for no offset.
String formatUtcOffset(Duration offset) {
  if (offset == Duration.zero) return 'UTC';
  final minutes = offset.inMinutes.abs();
  final hours = (minutes ~/ 60).toString().padLeft(2, '0');
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return 'UTC${offset.isNegative ? '−' : '+'}$hours:$rest';
}
