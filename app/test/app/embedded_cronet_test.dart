import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _repoRoot = '..';

final _bundledCronet = RegExp(r'org\.chromium\.net:cronet-bundled:([0-9.]+)');

// Google's empty transitional Cronet artifacts, which cronet-bundled's POMs
// and cronet_http's cronetHttpNoPlay pull.
const _cronetStubs = [
  'cronet-api',
  'cronet-common',
  'cronet-embedded',
  'cronet-fallback',
  'cronet-shared',
  'httpengine-native-provider',
];

// The first cronet-bundled built from a Chrome stable release (Chromium
// 155.0.8059.16) and checked against cronet_http's Kotlin and JNI bindings.
const _firstStableBundled = '500.1.0';
const _firstStableChromium = '155.0.8059.16';

String _bundledVersion(String gradle) => _bundledCronet.firstMatch(gradle)![1]!;

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
  final notices = jsonDecode(
    File('$_repoRoot/tool/android_notices/cronet/source.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;

  test('the release build has embedded Cronet of one version and no Play '
      'services library', () {
    final released = File('$_repoRoot/app/android/app/gradle.lockfile')
        .readAsLinesSync()
        .where((line) => line.contains('releaseRuntimeClasspath'))
        .map((line) => line.split('=').first)
        .toList();
    final version = _bundledVersion(buildGradle);

    expect(released, isNotEmpty);
    expect(
      released.where(
        (library) => library.startsWith('com.google.android.gms:'),
      ),
      isEmpty,
    );
    expect(
      released.where((library) => library.startsWith('org.chromium.net:')),
      unorderedEquals([
        'org.chromium.net:cronet:$version',
        'org.chromium.net:cronet-bundled:$version',
      ]),
    );
  });

  test('every configuration of the app leaves out Play services Cronet and '
      'the transitional Cronet artifacts', () {
    expect(
      buildGradle,
      contains(
        'exclude(group = "com.google.android.gms", '
        'module = "play-services-cronet")',
      ),
    );
    expect(
      buildGradle,
      contains('exclude(group = "org.chromium.net", module = module)'),
    );
    for (final stub in _cronetStubs) {
      expect(buildGradle, contains('"$stub"'));
    }
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
    expect(
      manifest,
      contains(
        '<uses-permission '
        'android:name="android.permission.ACCESS_NETWORK_STATE" />',
      ),
    );
  });

  test('versions compare by number', () {
    expect(_compareVersions('143.7445.0', '143.7445.0'), 0);
    expect(_compareVersions('143.10000.0', '143.7445.0'), isPositive);
    expect(_compareVersions('500.1', '143.7445.0'), isPositive);
    expect(_compareVersions('143.7445', '143.7445.1'), isNegative);
    expect(_compareVersions('155.0.8059.16', '155.0.8059.9'), isPositive);
  });

  test('embedded Cronet is a build of a Chrome stable release', () {
    expect(
      _compareVersions(_bundledVersion(buildGradle), _firstStableBundled),
      greaterThanOrEqualTo(0),
    );
    expect(
      _compareVersions(notices['build']! as String, _firstStableChromium),
      greaterThanOrEqualTo(0),
    );
    expect(notices['stable_since'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('the Cronet notices belong to the declared version', () {
    final version = _bundledVersion(buildGradle);

    expect(notices['library'], 'org.chromium.net:cronet-bundled:$version');
    expect(
      notices['libraries'],
      unorderedEquals([
        'org.chromium.net:cronet:$version',
        'org.chromium.net:cronet-bundled:$version',
      ]),
    );
  });

  // cronet_http's Kotlin is built and tested against the cronet-embedded it
  // names (MAJOR.BUILD.PATCH, Chromium MAJOR.0.BUILD.PATCH); the bundled
  // Chromium may be newer.
  test('embedded Cronet is at least the Chromium build cronet_http names '
      'for cronetHttpNoPlay', () {
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
    final named = RegExp(
      r'org\.chromium\.net:cronet-embedded:(\d+)\.(\d+)\.(\d+)',
    ).firstMatch(pluginGradle)!;

    expect(
      pluginGradle,
      contains("if (dartDefines.cronetHttpNoPlay == 'true')"),
    );
    expect(
      _compareVersions(
        notices['build']! as String,
        '${named[1]}.0.${named[2]}.${named[3]}',
      ),
      greaterThanOrEqualTo(0),
    );
  });
}
