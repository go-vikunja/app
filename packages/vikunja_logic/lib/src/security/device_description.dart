import 'package:meta/meta.dart';

enum DeviceKind { vikunjaApp, browser, dartClient, other }

/// What a session's User-Agent says about the device that signed in.
@immutable
final class DeviceDescription {
  const new({
    required this.kind,
    required this.raw,
    this.appVersion,
    this.appBuild,
    this.browserName,
    this.osName,
    this.osVersion,
  });

  final DeviceKind kind;

  /// The User-Agent as the server stored it, trimmed.
  final String raw;

  /// The app's version and build; the Dart version of a
  /// [DeviceKind.dartClient].
  final String? appVersion;
  final String? appBuild;
  final String? browserName;
  final String? osName;
  final String? osVersion;

  @override
  bool operator ==(Object other) =>
      other is DeviceDescription &&
      other.kind == kind &&
      other.raw == raw &&
      other.appVersion == appVersion &&
      other.appBuild == appBuild &&
      other.browserName == browserName &&
      other.osName == osName &&
      other.osVersion == osVersion;

  @override
  int get hashCode => Object.hash(
    kind,
    raw,
    appVersion,
    appBuild,
    browserName,
    osName,
    osVersion,
  );

  @override
  String toString() =>
      'DeviceDescription($kind, app: $appVersion+$appBuild, '
      'browser: $browserName, os: $osName $osVersion)';
}

/// Reads [raw] tolerantly; anything it does not recognise is
/// [DeviceKind.other] with [DeviceDescription.raw] only. Versions are what
/// the User-Agent claims: browsers freeze some of them (macOS 10.15.7,
/// Chrome's Android 10), so those are dropped.
DeviceDescription describeUserAgent(String raw) {
  final text = raw.trim();
  if (_vikunjaApp.firstMatch(text) case final match?) {
    final system = (match.namedGroup('system') ?? '').trim().split(' ');
    final platform = system.first;
    return DeviceDescription(
      kind: DeviceKind.vikunjaApp,
      raw: text,
      appVersion: match.namedGroup('version'),
      appBuild: match.namedGroup('build'),
      osName: platform.isEmpty
          ? null
          : _platformNames[platform.toLowerCase()] ?? platform,
      osVersion: system.length > 1 && system[1].isNotEmpty ? system[1] : null,
    );
  }
  if (_dart.firstMatch(text) case final match?) {
    return DeviceDescription(
      kind: DeviceKind.dartClient,
      raw: text,
      appVersion: match.group(1),
    );
  }
  if (!text.startsWith('Mozilla/')) {
    return DeviceDescription(kind: DeviceKind.other, raw: text);
  }
  final (:osName, :osVersion) = _systemOf(text);
  return DeviceDescription(
    kind: DeviceKind.browser,
    raw: text,
    browserName: _browserOf(text),
    osName: osName,
    osVersion: osVersion,
  );
}

final _vikunjaApp = RegExp(
  r'^Vikunja-App/(?<version>[^\s+()]+)(?:\+(?<build>[^\s()]+))?'
  r'(?:\s+\((?<system>[^()]*)\))?$',
);
final _dart = RegExp(r'^Dart/([0-9][^\s()]*)(?:\s|$)');

/// `Platform.operatingSystem` names, as the app's User-Agent sends them.
const _platformNames = {
  'android': 'Android',
  'ios': 'iOS',
  'macos': 'macOS',
  'linux': 'Linux',
  'windows': 'Windows',
  'fuchsia': 'Fuchsia',
};

/// Most specific first: Edge, Opera, Samsung and Vivaldi also name Chrome,
/// Chrome also names Safari.
const _browserTokens = [
  ('Edg/', 'Edge'),
  ('EdgA/', 'Edge'),
  ('EdgiOS/', 'Edge'),
  ('Edge/', 'Edge'),
  ('OPR/', 'Opera'),
  ('OPiOS/', 'Opera'),
  ('SamsungBrowser/', 'Samsung Internet'),
  ('Vivaldi/', 'Vivaldi'),
  ('YaBrowser/', 'Yandex Browser'),
  ('FxiOS/', 'Firefox'),
  ('Firefox/', 'Firefox'),
  ('CriOS/', 'Chrome'),
  ('Chromium/', 'Chromium'),
  ('Chrome/', 'Chrome'),
];

String? _browserOf(String text) {
  for (final (token, name) in _browserTokens) {
    if (text.contains(token)) return name;
  }
  if (text.contains('Safari/') && text.contains('Version/')) return 'Safari';
  return null;
}

final _windows = RegExp(r'Windows NT (\d+\.\d+)');
final _ios = RegExp(r'(?:iPhone|iPad|iPod).*?\bOS (\d+(?:_\d+)*)');
final _android = RegExp(r'Android (\d+(?:\.\d+)*)(;\s*K\))?');
final _mac = RegExp(r'Mac OS X (\d+(?:[_.]\d+)*)');
const _windowsVersions = {'6.1': '7', '6.2': '8', '6.3': '8.1'};
const _frozenMacVersions = {'10.15', '10.15.7'};

({String? osName, String? osVersion}) _systemOf(String text) {
  if (_windows.firstMatch(text) case final match?) {
    // NT 10.0 is Windows 10 and 11 alike.
    return (osName: 'Windows', osVersion: _windowsVersions[match.group(1)]);
  }
  if (text.contains('Windows')) return (osName: 'Windows', osVersion: null);
  if (_ios.firstMatch(text) case final match?) {
    return (osName: 'iOS', osVersion: match.group(1)!.replaceAll('_', '.'));
  }
  if (_android.firstMatch(text) case final match?) {
    final reduced = match.group(2) != null;
    return (osName: 'Android', osVersion: reduced ? null : match.group(1));
  }
  if (text.contains('Android')) return (osName: 'Android', osVersion: null);
  if (text.contains('CrOS')) return (osName: 'ChromeOS', osVersion: null);
  if (_mac.firstMatch(text) case final match?) {
    final version = match.group(1)!.replaceAll('_', '.');
    return (
      osName: 'macOS',
      osVersion: _frozenMacVersions.contains(version) ? null : version,
    );
  }
  if (text.contains('Macintosh')) return (osName: 'macOS', osVersion: null);
  if (text.contains('Linux') || text.contains('X11')) {
    return (osName: 'Linux', osVersion: null);
  }
  return (osName: null, osVersion: null);
}
