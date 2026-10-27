import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('WidgetLinkKey');

/// A random key per install that the links of the app's own widgets and
/// notifications carry (`k`): any app or web page can send such a link,
/// but only one with the key switches accounts without asking (D66). It
/// guards no data, so it lives in preferences, but it is never logged.
const widgetLinkKeyPreference = 'widgets.link_key';

const _keyBytes = 32;

/// For the UI start only, before the registry's first read sets the install
/// marker: a fresh install gets a new key, an existing one keeps it, and a
/// missing or broken key is replaced. Headless isolates only read it.
Future<String> prepareWidgetLinkKey(PreferencesStore preferences) async {
  final freshInstall = await preferences.getString(installMarkerKey) == null;
  return await ensureWidgetLinkKey(preferences, rotate: freshInstall);
}

Future<String> ensureWidgetLinkKey(
  PreferencesStore preferences, {
  required bool rotate,
}) async {
  if (!rotate) {
    final stored = await preferences.getString(widgetLinkKeyPreference);
    if (stored != null && _decode(stored) != null) return stored;
  }
  final key = newWidgetLinkKey();
  await preferences.setString(widgetLinkKeyPreference, key);
  return key;
}

/// 32 random bytes, base64url without padding.
String newWidgetLinkKey([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = Uint8List(_keyBytes);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = source.nextInt(256);
  }
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Null when there is none or it cannot be read: links are then built
/// without it, and the app asks before it switches.
Future<String?> readWidgetLinkKey(PreferencesStore preferences) async {
  try {
    final stored = await preferences.getString(widgetLinkKeyPreference);
    return stored != null && _decode(stored) != null ? stored : null;
  } on Object catch (error) {
    _log.warning('Could not read the widget link key: ${error.runtimeType}');
    return null;
  }
}

/// Compares in constant time; false when either is missing or malformed.
bool widgetLinkKeyMatches(String? candidate, String? key) {
  if (candidate == null || key == null) return false;
  final given = _decode(candidate);
  final expected = _decode(key);
  if (given == null || expected == null) return false;
  var difference = 0;
  for (var i = 0; i < _keyBytes; i++) {
    difference |= given[i] ^ expected[i];
  }
  return difference == 0;
}

Uint8List? _decode(String value) {
  try {
    final bytes = base64Url.decode(base64Url.normalize(value));
    return bytes.length == _keyBytes ? bytes : null;
  } on FormatException {
    return null;
  }
}
