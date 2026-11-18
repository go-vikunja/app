import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// API 37 asks for ACCESS_LOCAL_NETWORK and a Play declaration for servers on
// the local network (D76), so raising the target is a decision of its own,
// never a side effect of a Flutter update.
void main() {
  test('targetSdk is set explicitly to 36, not taken from Flutter', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifests = [
      for (final entry in Directory(
        'android/app/src',
      ).listSync(recursive: true))
        if (entry is File && entry.path.endsWith('AndroidManifest.xml'))
          entry.readAsStringSync(),
    ];

    expect(
      [
        for (final match in RegExp(
          r'^\s*targetSdk\s*=\s*(.*?)\s*$',
          multiLine: true,
        ).allMatches(gradle))
          match[1],
      ],
      ['36'],
    );
    expect(gradle, isNot(contains('targetSdkVersion')));
    expect(manifests, isNotEmpty);
    for (final manifest in manifests) {
      expect(manifest, isNot(contains('targetSdkVersion')));
    }
  });
}
