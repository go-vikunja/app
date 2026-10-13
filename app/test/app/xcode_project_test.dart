import 'dart:convert';
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

  group('app icon set', () {
    final directory = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    final images =
        ((jsonDecode(File('${directory.path}/Contents.json').readAsStringSync())
                    as Map<String, Object?>)['images']!
                as List<Object?>)
            .cast<Map<String, Object?>>();

    // With a scale key, actool no longer treats the universal 1024 pt entries
    // as single-size icons: it warns about missing 60 and 76 pt icons and
    // drops CFBundleIconFiles. flutter_launcher_icons 0.14.4 writes the key.
    test('universal 1024 entries carry no scale', () {
      final universal1024 = images.where(
        (image) =>
            image['idiom'] == 'universal' && image['size'] == '1024x1024',
      );

      expect(universal1024, hasLength(3));
      expect(
        universal1024.where((image) => image.containsKey('scale')),
        isEmpty,
      );
    });

    test('references exactly the PNGs in the folder', () {
      final referenced = images.map((image) => image['filename']! as String);
      final present = directory
          .listSync()
          .map((entity) => entity.uri.pathSegments.last)
          .where((name) => name.endsWith('.png'));

      expect(present.toSet(), referenced.toSet());
    });
  });
}
