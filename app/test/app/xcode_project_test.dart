import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // flutter_launcher_icons 0.14.4 rewrites this key to "AppIcon" in the Debug
  // and Release configurations whenever it regenerates the icons.
  test('asset symbol generation is not overwritten by the icon generator', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();

    expect(
      project,
      isNot(contains('GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon')),
    );
    expect(
      'GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;'.allMatches(project),
      hasLength(3),
    );
  });
}
