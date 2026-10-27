import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _repoRoot = '..';

final _embeddedCronet = RegExp(r'org\.chromium\.net:cronet-embedded:([0-9.]+)');

String _embeddedVersion(String gradle) =>
    _embeddedCronet.firstMatch(gradle)![1]!;

int _compareVersions(String a, String b) {
  final left = a.split('.').map(int.parse).toList();
  final right = b.split('.').map(int.parse).toList();
  for (var i = 0; i < left.length || i < right.length; i++) {
    final difference =
        (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (difference != 0) return difference;
  }
  return 0;
}

void main() {
  final buildGradle = File('$_repoRoot/app/android/app/build.gradle.kts')
      .readAsStringSync();

  test('the release build has embedded Cronet and no Play services '
      'library', () {
    final released = File('$_repoRoot/app/android/app/gradle.lockfile')
        .readAsLinesSync()
        .where((line) => line.contains('releaseRuntimeClasspath'))
        .map((line) => line.split('=').first)
        .toList();

    expect(released, isNotEmpty);
    expect(
      released.where(
        (library) => library.startsWith('com.google.android.gms:'),
      ),
      isEmpty,
    );
    expect(
      released,
      contains(
        'org.chromium.net:cronet-embedded:${_embeddedVersion(buildGradle)}',
      ),
    );
  });

  test('every configuration of the app leaves out Play services Cronet', () {
    expect(
      buildGradle,
      contains(
        'exclude(group = "com.google.android.gms", '
        'module = "play-services-cronet")',
      ),
    );
  });

  test('Cronet reads no HTTP flags from the system and sends no '
      'telemetry', () {
    final manifest = File(
      '$_repoRoot/app/android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync().replaceAll(RegExp('<!--.*?-->', dotAll: true), '');
    final holder = RegExp(
      r'<service\b([^>]*android:name="android\.net\.http\.MetaDataHolder"'
      '[^>]*)>(.*?)</service>',
      dotAll: true,
    ).firstMatch(manifest);
    String? flag(String name) => RegExp(
      '<meta-data\\s+android:name="android\\.net\\.http\\.$name"'
      r'\s+android:value="([^"]*)"',
    ).firstMatch(holder![2]!)?[1];

    expect(holder, isNotNull);
    expect(holder![1], contains('android:enabled="false"'));
    expect(holder[1], contains('android:exported="false"'));
    expect(flag('ReadHttpFlags'), 'false');
    expect(flag('EnableTelemetry'), 'false');
  });

  test('versions compare by number', () {
    expect(_compareVersions('143.7445.0', '143.7445.0'), 0);
    expect(_compareVersions('143.10000.0', '143.7445.0'), isPositive);
    expect(_compareVersions('500.1', '143.7445.0'), isPositive);
    expect(_compareVersions('143.7445', '143.7445.1'), isNegative);
  });

  // cronet_http's Kotlin is built and tested against that version; a newer
  // one may be taken for Chromium's security fixes.
  test('embedded Cronet is at least the version cronet_http names for '
      'cronetHttpNoPlay', () {
    final config = File('$_repoRoot/.dart_tool/package_config.json').absolute;
    final packages =
        (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
    final cronetHttp = packages.cast<Map<String, Object?>>().singleWhere(
      (package) => package['name'] == 'cronet_http',
    );
    final rootUri = cronetHttp['rootUri']! as String;
    final pluginGradle = File.fromUri(
      config.uri
          .resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/')
          .resolve('android/build.gradle'),
    ).readAsStringSync();

    expect(
      pluginGradle,
      contains("if (dartDefines.cronetHttpNoPlay == 'true')"),
    );
    expect(
      _compareVersions(
        _embeddedVersion(buildGradle),
        _embeddedVersion(pluginGradle),
      ),
      greaterThanOrEqualTo(0),
    );
  });
}
