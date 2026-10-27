import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/legal.dart';
import 'package:vikunja_mobile/core/legal/app_licenses.dart';

const _repoRoot = '..';

class _FailingBundle extends CachingAssetBundle {
  new(this.failing);

  final String failing;

  @override
  Future<ByteData> load(String key) async {
    if (key == failing) throw FlutterError('missing $key');
    return await rootBundle.load(key);
  }
}

Map<String, List<LicenseEntry>> _byPackage(List<LicenseEntry> entries) {
  final byPackage = <String, List<LicenseEntry>>{};
  for (final entry in entries) {
    for (final package in entry.packages) {
      (byPackage[package] ??= []).add(entry);
    }
  }
  return byPackage;
}

String _text(LicenseEntry entry) =>
    entry.paragraphs.map((paragraph) => paragraph.text).join('\n');

String _normalized(String text) =>
    text.replaceAll(RegExp('[*>`]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseNotices', () {
    test('takes the packages of the list right above a block', () {
      final entries = parseNotices('''
# Third-party notices

The page contains these packages.

- @tiptap/core 3.31.3 (MIT)
- prosemirror-model 1.25.11 (MIT)

```text
MIT License

Copyright (c) someone
```

- linkifyjs 4.3.3 (MIT)

```text
Another text
```
''');

      expect(entries.map((entry) => entry.packages), [
        ['@tiptap/core', 'prosemirror-model'],
        ['linkifyjs'],
      ]);
      expect(_text(entries.first), 'MIT License\nCopyright (c) someone');
    });

    test('takes the package of a heading, after a list of other things', () {
      final entries = parseNotices('''
# Third-party notices

- `lib/src/filter/fexpr.dart` follows fexpr v0.6.0 (BSD 3-Clause).

## fexpr

```text
BSD 3-Clause License
```

## go-datemath

```text
ISC
```
''');

      expect(entries.map((entry) => entry.packages), [
        ['fexpr'],
        ['go-datemath'],
      ]);
    });

    test('takes a name with spaces from the backticks it starts with', () {
      final entries = parseNotices('''
- androidx.core:core 1.18.0 (Apache-2.0)
- `URI Template Parser` (Apache-2.0) in cronet-embedded 143.7445.0

```text
Apache License
```

- `Paul Hsieh's SuperFastHash` in cronet-embedded 143.7445.0
- `` in cronet-embedded 143.7445.0

```text
MIT
```
''');

      expect(entries.map((entry) => entry.packages), [
        ['androidx.core:core', 'URI Template Parser'],
        ["Paul Hsieh's SuperFastHash", '``'],
      ]);
    });

    test('skips blocks without a package and empty blocks', () {
      final entries = parseNotices('''
```text
No package names this.
```

## empty

```text
```

- a 1 (MIT)
- b 2 (MIT)

Some prose between the list and its block.

```text
Text
```
''');

      expect(entries.map((entry) => entry.packages), [
        ['a', 'b'],
      ]);
    });
  });

  group('the committed notices', () {
    late Map<String, List<LicenseEntry>> android;
    late Map<String, List<LicenseEntry>> ios;

    setUpAll(() async {
      android = _byPackage(
        await appLicenses(
          rootBundle,
          platform: TargetPlatform.android,
        ).toList(),
      );
      ios = _byPackage(
        await appLicenses(rootBundle, platform: TargetPlatform.iOS).toList(),
      );
    });

    test("Rurana's notice, beside the AGPL that Flutter's build adds", () {
      final own = _text(android[ownLicensePackage]!.single);
      expect(own, contains(copyrightNotice));
      expect(
        own,
        contains('Additional permission under GNU AGPL version 3 section 7'),
      );
      expect(own, isNot(contains('TERMS AND CONDITIONS')));
    });

    test('the editor, the ported code and the Material Icons on both '
        'platforms', () {
      for (final packages in [android, ios]) {
        expect(
          packages.keys,
          containsAll([
            ownLicensePackage,
            '@tiptap/core',
            'prosemirror-model',
            'fexpr',
            'go-datemath',
            'Material Icons',
          ]),
        );
      }
      expect(_text(android['fexpr']!.single), contains('BSD 3-Clause'));
      expect(android['prosemirror-model'], hasLength(2));
      expect(_text(android['Material Icons']!.single), contains('Google'));
    });

    test('the Android libraries on Android only', () {
      expect(
        android.keys,
        containsAll([
          'androidx.work:work-runtime',
          'androidx.glance:glance-appwidget',
          'org.chromium.net:cronet-embedded',
          'org.chromium.net:cronet-api',
          'com.android.tools:desugar_jdk_libs',
        ]),
      );
      expect(
        _text(android['androidx.work:work-runtime']!.single),
        contains('Apache License'),
      );
      expect(
        _text(android['org.chromium.net:cronet-embedded']!.single),
        contains('The Chromium Authors'),
      );
      expect(
        android.keys.where((name) => name.startsWith('com.google.android.gms')),
        isEmpty,
      );
      expect(
        _text(android['com.android.tools:desugar_jdk_libs']!.last),
        contains('Written offer'),
      );
      expect(ios.keys.where((name) => name.startsWith('androidx.')), isEmpty);
    });

    test('the code of other projects inside embedded Cronet', () {
      expect(
        android.keys,
        containsAll([
          'BoringSSL',
          'QUICHE',
          'zlib',
          'Brotli',
          'Zstandard',
          'Abseil',
          'Protocol Buffers',
          'serde',
          'libc++',
          'libc++abi',
          'Rust standard library',
        ]),
      );
      expect(
        _text(android['libc++']!.single),
        allOf(contains('LLVM Exceptions'), contains('The libc++ library')),
      );
      expect(
        _text(android['libc++abi']!.single),
        contains('The libc++abi library'),
      );
      expect(
        _text(android['Rust standard library']!.single),
        _text(android['androidx.work:work-runtime']!.single),
      );
      expect(_text(android['BoringSSL']!.single), contains('The Go Authors'));
      expect(_text(android['zlib']!.single), contains('Jean-loup Gailly'));
      expect(
        _text(android['Protocol Buffers']!.single),
        _text(android['com.google.protobuf:protobuf-javalite']!.single),
      );
      expect(ios.keys, isNot(contains('BoringSSL')));
    });

    test('an asset that cannot be read is left out', () async {
      final packages = _byPackage(
        await appLicenses(
          _FailingBundle(LegalAssets.editor),
          platform: TargetPlatform.android,
        ).toList(),
      );

      expect(packages.keys, isNot(contains('@tiptap/core')));
      expect(packages['prosemirror-model'], hasLength(1));
      expect(packages.keys, containsAll([ownLicensePackage, 'fexpr']));
    });

    test('registered once with the LicenseRegistry', () async {
      LicenseRegistry.reset();
      addTearDown(LicenseRegistry.reset);
      registerAppLicenses();
      registerAppLicenses();

      final packages = _byPackage(await LicenseRegistry.licenses.toList());
      expect(packages[ownLicensePackage], hasLength(1));
      expect(packages.keys, contains('androidx.core:core'));
    });
  });

  group('the assets match their sources', () {
    String repoFile(String path) => File('$_repoRoot/$path').readAsStringSync();
    String appFile(String path) => File(path).readAsStringSync();

    // Flutter's build reads a NOTICES or LICENSE file beside every package
    // of package_config.json, the workspace's own included, and lists it
    // under the package's name.
    test('of the workspace, only the root package brings a licence, the AGPL '
        'under the name of the own notice', () {
      final config = File('$_repoRoot/.dart_tool/package_config.json').absolute;
      final packages =
          (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      bool hasLicenceFile(String rootUri) {
        final root = config.uri.resolve(
          rootUri.endsWith('/') ? rootUri : '$rootUri/',
        );
        return [
          'NOTICES',
          'LICENSE',
        ].any((name) => File.fromUri(root.resolve(name)).existsSync());
      }

      final inWorkspace = [
        for (final package in packages.cast<Map<String, Object?>>())
          if (package['rootUri']! as String case final rootUri
              when !rootUri.startsWith('file:'))
            (name: package['name']! as String, rootUri: rootUri),
      ];
      final licensed = [
        for (final (:name, :rootUri) in inWorkspace)
          if (hasLicenceFile(rootUri)) name,
      ];

      expect(
        inWorkspace.map((package) => package.name),
        containsAll(['vikunja_mobile', 'vikunja_logic', 'rurana_widgets']),
      );
      expect(licensed, [ownLicensePackage]);
      expect(File('$_repoRoot/NOTICES').existsSync(), isFalse);
      expect(File('$_repoRoot/LICENSE').existsSync(), isTrue);
    });

    test("Rurana's notice says what NOTICE.md says", () {
      final notice = _normalized(repoFile('NOTICE.md'));
      final own = parseNotices(appFile(LegalAssets.ownNotice)).single;

      expect(own.packages, [ownLicensePackage]);
      for (final paragraph in own.paragraphs) {
        expect(notice, contains(_normalized(paragraph.text)));
      }
    });

    test(
      'every licence block of a committed notices file has its packages',
      () {
        final files = {
          for (final asset in [
            LegalAssets.ownNotice,
            LegalAssets.editor,
            LegalAssets.materialIcons,
            LegalAssets.android,
          ])
            asset: appFile(asset),
          LegalAssets.portedCode: repoFile(LegalAssets.portedCode),
        };
        for (final MapEntry(key: path, value: notices) in files.entries) {
          final blocks = RegExp(
            r'^```text$',
            multiLine: true,
          ).allMatches(notices);
          expect(parseNotices(notices), hasLength(blocks.length), reason: path);
        }
      },
    );

    test('the Android notices name every library of the release build', () {
      final notices = appFile(LegalAssets.android);
      final released = repoFile('app/android/app/gradle.lockfile')
          .split('\n')
          .where((line) => line.contains('releaseRuntimeClasspath'))
          .map((line) => line.split('=').first);

      expect(released, isNotEmpty);
      for (final coordinates in released) {
        final split = coordinates.lastIndexOf(':');
        final artifact = coordinates.substring(0, split);
        final version = coordinates.substring(split + 1);
        expect(
          notices,
          contains('\n- $artifact $version ('),
          reason:
              'Run python3 -I tool/build_android_notices.py after the '
              'lockfile changed',
        );
      }
    });
  });
}
