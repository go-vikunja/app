import 'dart:convert';
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

    test('no usage description names Rurana', () {
      final descriptions = {
        for (final match in RegExp(
          r'<key>(NS\w+UsageDescription)</key>\s*<string>([^<]*)</string>',
        ).allMatches(infoPlist))
          match[1]!: match[2]!,
      };

      expect(descriptions, isNotEmpty);
      descriptions.forEach((key, text) {
        expect(text.toLowerCase(), isNot(contains('rurana')), reason: key);
      });
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

  test('no shipped source names the old app id', () {
    final oldId = RegExp(r'dev\.coderoftime');
    final roots = [
      'android/app/src',
      for (final folder in _directories('ios'))
        if (!const {
          'ios/RunnerTests',
          'ios/Flutter',
          'ios/Pods',
        }.contains(folder))
          folder,
      'lib',
      for (final plugin in _directories('../plugins')) ...[
        '$plugin/lib',
        '$plugin/android/src',
        '$plugin/ios',
      ],
      for (final package in _directories('../packages')) '$package/lib',
    ];
    final hits = [
      for (final root in roots)
        for (final path in _files(root))
          for (final (index, line) in LineSplitter.split(
            latin1.decode(File(path).readAsBytesSync()),
          ).indexed)
            if (oldId.hasMatch(line)) '$path:${index + 1}',
    ];

    expect(roots, containsAll(['ios/Runner', 'lib']));
    expect(hits, isEmpty);
  });

  test('the shipped sources are found', () {
    for (final root in _fixedRoots) {
      expect(_files(root), isNotEmpty, reason: root);
    }
    expect(_widgetExtensions(), hasLength(1));
  });

  test('no shipped source names Rurana, apart from the named exceptions', () {
    final hits = [
      for (final root in _shippedRoots())
        for (final path in _files(root))
          if (_oldName.hasMatch(path))
            path
          else
            for (final (index, line) in LineSplitter.split(
              _withoutExceptions(path, _read(path)),
            ).indexed)
              if (_oldName.hasMatch(line)) '$path:${index + 1}',
    ];

    expect(hits, isEmpty);
  });

  test('no shipped source puts the app under the AGPL', () {
    final agpl = RegExp(
      r'\bagpl\b|affero|app store permission',
      caseSensitive: false,
    );
    final hits = [
      for (final root in _shippedRoots())
        for (final path in _files(root))
          for (final (index, line) in LineSplitter.split(_read(path)).indexed)
            if (agpl.hasMatch(line)) '$path:${index + 1}',
    ];

    expect(hits, isEmpty);
  });

  test('every exception to the Rurana check still applies', () {
    _nameExceptions.forEach((path, patterns) {
      final text = _read(path);
      for (final pattern in patterns) {
        expect(
          pattern.hasMatch(text),
          isTrue,
          reason: '$path ${pattern.pattern}',
        );
      }
    });
  });
}

const _fixedRoots = [
  'lib',
  'android/app/src/main',
  'ios/Runner',
  'assets',
  'editor/src',
];

List<String> _widgetExtensions() => [
  for (final folder in _directories('ios'))
    if (folder.endsWith('Widgets')) folder,
];

List<String> _shippedRoots() => [
  ..._fixedRoots,
  ..._widgetExtensions(),
  for (final plugin in _directories('../plugins')) ...[
    '$plugin/lib',
    '$plugin/android/src',
    '$plugin/ios',
  ],
  for (final package in _directories('../packages')) '$package/lib',
];

final _oldName = RegExp('rurana', caseSensitive: false);

final _nameExceptions = <String, List<RegExp>>{
  'lib/app/legal.dart': [
    // Until step 38f: the app's pages on the owner's website.
    RegExp(r"'https://coderoftime\.dev/[^']*'"),
  ],
};

String _read(String path) =>
    utf8.decode(File(path).readAsBytesSync(), allowMalformed: true);

// Blanks each exception but keeps its line breaks, so hits keep their line
// numbers.
String _withoutExceptions(String path, String text) {
  var result = text;
  for (final pattern in _nameExceptions[path] ?? const <RegExp>[]) {
    result = result.replaceAllMapped(
      pattern,
      (match) => match[0]!.replaceAll(RegExp('[^\n]'), ''),
    );
  }
  return result;
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
