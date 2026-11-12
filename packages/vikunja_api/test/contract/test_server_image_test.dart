import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

void main() {
  test('an unset or empty image expects the default release', () {
    final release = testServerVersion(defaultTestServerImage);

    expect(release.isDevelopmentBuild, isFalse);
    expect(testServerVersion(null), release);
    expect(testServerVersion(''), release);
  });

  test('another image expects the release of its tag', () {
    for (final image in [
      'vikunja/vikunja:2.7.1',
      'vikunja/vikunja:v2.7.1',
      'localhost:5000/vikunja/vikunja:2.7.1',
      'vikunja/vikunja:2.7.1@sha256:0123abcd',
    ]) {
      expect(
        testServerVersion(image),
        const ServerVersion(2, 7, 1),
        reason: image,
      );
    }
  });

  test('an image without a release tag is refused', () {
    for (final image in [
      'vikunja/vikunja',
      'localhost:5000/vikunja/vikunja',
      'vikunja/vikunja@sha256:0123abcd',
      'vikunja/vikunja:latest',
      'vikunja/vikunja:unstable',
    ]) {
      expect(
        () => testServerVersion(image),
        throwsArgumentError,
        reason: image,
      );
    }
  });

  test('both Vikunja services of the compose file run the default image '
      'unless RURANA_TEST_VIKUNJA_IMAGE is set', () {
    final compose = File('../../test_servers/docker-compose.yaml')
        .readAsStringSync();
    final vikunjaImages = [
      for (final match in RegExp(
        r'^ +image: (.+)$',
        multiLine: true,
      ).allMatches(compose))
        if (!match[1]!.startsWith('caddy:')) match[1],
    ];

    const overridable =
        r'${RURANA_TEST_VIKUNJA_IMAGE:-'
        '$defaultTestServerImage}';
    expect(vikunjaImages, [overridable, overridable]);
  });
}
