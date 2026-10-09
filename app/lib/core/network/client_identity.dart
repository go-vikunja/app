import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _log = Logger('ClientIdentity');

final class ClientIdentity {
  const new({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
  });

  static const _deviceChannel = MethodChannel('dev.coderoftime.vikunja/device');

  static Future<ClientIdentity> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return ClientIdentity(
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      platform: Platform.operatingSystem,
      osVersion: await _loadOsVersion(),
    );
  }

  static Future<String> _loadOsVersion() async {
    if (Platform.isAndroid) {
      // dart:io reports the Linux kernel version on Android.
      try {
        return await _deviceChannel.invokeMethod<String>('osVersion') ?? '';
      } on Object catch (error) {
        _log.warning('Android version unavailable: $error');
        return '';
      }
    }
    return extractOsVersion(Platform.operatingSystemVersion);
  }

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;

  String get userAgent {
    final build = buildNumber.isEmpty ? '' : '+${_token(buildNumber)}';
    final system = [
      _token(platform),
      _token(osVersion),
    ].where((part) => part.isNotEmpty).join(' ');
    return 'Rurana/${_token(appVersion)}$build ($system)';
  }

  static String _token(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9.+_-]'), '');
}

/// iOS reports e.g. `Version 17.4 (Build 21E213)`.
String extractOsVersion(String raw) =>
    RegExp(r'\d+(?:\.\d+)+').firstMatch(raw)?.group(0) ?? '';
