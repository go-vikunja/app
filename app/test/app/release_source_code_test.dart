@Tags(['release'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/legal.dart';

// Skipped in ordinary runs (dart_test.yaml); a release build runs it with
// `flutter test --run-skipped --tags release`.
void main() {
  test('a release says where its source code is (AGPL section 6)', () {
    expect(
      sourceCodeUrl,
      isNotNull,
      reason: 'Set sourceCodeUrl in lib/app/legal.dart before a release (D67)',
    );
    final address = Uri.parse(sourceCodeUrl!);
    expect(address.isScheme('https') && address.host.isNotEmpty, isTrue);
  });
}
