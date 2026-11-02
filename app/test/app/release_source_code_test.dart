@Tags(['release'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/legal.dart';

// Skipped in ordinary runs (dart_test.yaml); the release job runs it with
// `flutter test --run-skipped --tags release` and the build's define.
void main() {
  test('a release says where its source code is (AGPL section 6)', () {
    expect(
      sourceCodeUrl,
      isNotNull,
      reason:
          'Pass --dart-define=SOURCE_CODE_URL=<the https URL of the '
          'repository>, as tool/ci/release.sh does (D73)',
    );
    final address = Uri.parse(sourceCodeUrl!);
    expect(
      address.isScheme('https') && address.host.isNotEmpty,
      isTrue,
      reason: '$address is not an https URL',
    );
  });
}
