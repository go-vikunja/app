import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _appId = 'io.vikunja.app';
const _appGroup = 'group.$_appId';

void main() {
  group('Android', () {
    test('applicationId and namespace are the app id', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(_assignments(gradle, 'applicationId'), [_appId]);
      expect(_assignments(gradle, 'namespace'), [_appId]);
    });

    test('every Kotlin file lives in the app id package of its folder', () {
      final files = [
        for (final root in [
          'android/app/src/main/kotlin',
          'android/app/src/test/kotlin',
        ])
          for (final path in _files(root))
            if (path.endsWith('.kt') && path != '$root/android/util/Log.kt')
              (root: root, path: path),
      ];

      expect(files, isNotEmpty);
      for (final (:root, :path) in files) {
        final relative = path.substring(root.length + 1);
        final folder = relative.substring(0, relative.lastIndexOf('/'));

        expect(relative, startsWith('io/vikunja/app/'));
        expect(_package(path), folder.replaceAll('/', '.'), reason: path);
      }
    });

    // The plugin finds the app's widget receivers by their class names.
    test('the widget plugin names receivers the app declares', () {
      final instances = [
        for (final plugin in _directories('../plugins'))
          for (final path in _files('$plugin/android'))
            if (path.endsWith('/WidgetInstances.kt')) path,
      ];
      final declared = {
        for (final path in _files('android/app/src/main/kotlin'))
          if (path.endsWith('.kt'))
            for (final match in RegExp(
              r'^(?:\w+ )*class (\w+)',
              multiLine: true,
            ).allMatches(File(path).readAsStringSync()))
              '${_package(path)}.${match[1]}',
      };

      expect(instances, hasLength(1));
      final receivers = [
        // Also the previous app's provider, with its spelling.
        for (final match in RegExp(
          r'"((?:[a-z]\w*\.)+[A-Z]\w*Re(?:ceiv|ciev)er)"',
        ).allMatches(File(instances.single).readAsStringSync()))
          match[1]!,
      ];
      expect(receivers, [
        '$_appId.widgets.TasksWidgetReceiver',
        '$_appId.widget.AppWidgetReciever',
        '$_appId.widgets.QuickAddWidgetReceiver',
      ]);
      expect(declared, containsAll(receivers));
    });

    test('the launcher label is Vikunja', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();

      expect(
        RegExp(r'<application\b[^>]*\bandroid:label="([^"]*)"')
            .firstMatch(manifest)
            ?.group(1),
        'Vikunja',
      );
    });
  });

  group('iOS', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    test('the bundle ids derive from the app id', () {
      expect(_settings(project, 'PRODUCT_BUNDLE_IDENTIFIER')..sort(), [
        for (final suffix in ['', '.RunnerTests', '.widgets'])
          for (var i = 0; i < 3; i++) '$_appId$suffix',
      ]);
    });

    test('the widget extension is named Vikunja', () {
      expect(_settings(project, 'INFOPLIST_KEY_CFBundleDisplayName'), [
        'Vikunja',
        'Vikunja',
        'Vikunja',
      ]);
    });

    test('the app is named Vikunja', () {
      expect(_plistString(infoPlist, 'CFBundleDisplayName'), 'Vikunja');
      expect(_plistString(infoPlist, 'CFBundleName'), 'Vikunja');
    });

    test('every entitlements file grants the App Group', () {
      final entitlements = [
        for (final path in _files('ios'))
          if (path.endsWith('.entitlements')) path,
      ];

      expect(entitlements.length, greaterThanOrEqualTo(2));
      for (final path in entitlements) {
        expect(
          File(path).readAsStringSync(),
          contains('<string>$_appGroup</string>'),
          reason: path,
        );
      }
    });
  });
}

List<String> _assignments(String gradle, String name) => [
  for (final match in RegExp(
    '^\\s*$name = "([^"]*)"',
    multiLine: true,
  ).allMatches(gradle))
    match[1]!,
];

List<String> _settings(String project, String name) => [
  for (final match in RegExp('\\b$name = ([^;]+);').allMatches(project))
    match[1]!.replaceAll('"', ''),
];

String? _plistString(String plist, String key) =>
    RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
        .firstMatch(plist)
        ?.group(1);

String? _package(String path) => RegExp(
  r'^package ([\w.]+)$',
  multiLine: true,
).firstMatch(File(path).readAsStringSync())?.group(1);

// Hidden folders hold tool caches and symlinks into other packages.
bool _visible(FileSystemEntity entity) =>
    !entity.path.split('/').last.startsWith('.');

List<String> _directories(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) return const [];
  return [
    for (final entity in directory.listSync().whereType<Directory>())
      if (_visible(entity)) entity.path,
  ]..sort();
}

List<String> _files(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) return const [];
  return [
    for (final entity in directory.listSync(followLinks: false))
      if (_visible(entity))
        if (entity is Directory)
          ..._files(entity.path)
        else if (entity is File)
          entity.path,
  ]..sort();
}
