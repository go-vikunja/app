import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _repository = '..';

const _appStorePermission =
    '**Additional permission under GNU AGPL version 3 section 7**\n'
    '\n'
    'As an additional permission under section 7 of the GNU Affero General '
    'Public License, you may distribute the Program, or a work based on it, '
    'through an app store whose terms and conditions are incompatible with '
    "this License, such as Apple's App Store, provided that the Corresponding "
    'Source is also available under this License, with or without this '
    'permission, through a channel without such restrictions.\n';

const _logoCopies =
    'You may copy and distribute the files listed below unmodified, but only '
    'as part of a copy of this repository or of its history, or of an '
    'unmodified build of the app published by Benedikt Lesch. No other right '
    'to them is granted. An app built from modified source may not be '
    'distributed with them.';

const _logoFilesPointer =
    "The files are listed in NOTICE.md at the root of the app's source code "
    'repository.';

String _read(String path) => File('$_repository/$path').readAsStringSync();

List<String> _expandBraces(String pattern) {
  final open = pattern.indexOf('{');
  if (open < 0) return [pattern];
  final close = pattern.indexOf('}', open);
  return [
    for (final option in pattern.substring(open + 1, close).split(','))
      ..._expandBraces(
        '${pattern.substring(0, open)}$option${pattern.substring(close + 1)}',
      ),
  ];
}

RegExp _globToRegExp(String glob) {
  final pattern = glob
      .split('**/')
      .map((part) => part.split('*').map(RegExp.escape).join('[^/]*'))
      .join('(?:.*/)?');
  return RegExp('^$pattern\$');
}

bool _matchesAFile(String glob) {
  final wildcard = glob.indexOf('*');
  if (wildcard < 0) return File('$_repository/$glob').existsSync();
  final directory = glob.substring(0, glob.lastIndexOf('/', wildcard) + 1);
  final matcher = _globToRegExp(glob);
  return Directory('$_repository/$directory')
      .listSync(recursive: true)
      .whereType<File>()
      .any(
        (file) => matcher.hasMatch(file.path.substring(_repository.length + 1)),
      );
}

void main() {
  test('LICENSE is the GNU AGPL version 3 as published on gnu.org', () {
    final license = File('$_repository/LICENSE');

    expect(license.readAsLinesSync().take(2).map((line) => line.trim()), [
      'GNU AFFERO GENERAL PUBLIC LICENSE',
      'Version 3, 19 November 2007',
    ]);
    expect(
      sha256.convert(license.readAsBytesSync()).toString(),
      '0d96a4ff68ad6d4b6f1f30f713b18d5184912ba8dd389f86aa7710db079abcb0',
    );
  });

  test('the notice file has the copyright and the app store permission', () {
    final notice = _read('NOTICE.md');

    expect(
      notice,
      contains('Copyright (C) 2026 Benedikt Lesch and the Rurana contributors'),
    );
    expect(notice, contains('\n\n$_appStorePermission\n'));
  });

  test("the owner's words on the logo files and where they are listed, in "
      "the notice file and the app's notice", () {
    for (final path in ['NOTICE.md', 'app/assets/legal/rurana.md']) {
      expect(
        _read(path).replaceAll(RegExp(r'\s+'), ' '),
        contains('$_logoCopies $_logoFilesPointer'),
        reason: path,
      );
    }
  });

  test('every file the notice file names exists', () {
    final paths = RegExp(r'`([^`\s:]+/[^`\s:]+)`')
        .allMatches(_read('NOTICE.md'))
        .map((match) => match[1]!)
        .expand(_expandBraces)
        .toList();

    expect(paths, hasLength(greaterThan(40)));
    expect(paths.where((path) => !_matchesAFile(path)), isEmpty);
  });

  test('the README names the licence and links the legal files', () {
    final readme = _read('README.md');
    final section = readme.substring(readme.indexOf('\n## License\n'));

    expect(section, contains('AGPL-3.0-or-later'));
    for (final file in ['LICENSE', 'NOTICE.md', 'CONTRIBUTING.md']) {
      expect(section, contains('($file)'));
      expect(File('$_repository/$file').existsSync(), isTrue, reason: file);
    }
    expect(
      _read('CONTRIBUTING.md'),
      contains("Developer's Certificate of Origin 1.1"),
    );
  });
}
