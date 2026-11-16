import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/legal.dart';

const _repository = '..';

const _mitPermission = '''
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const _nameAndLogo =
    'The name "Vikunja" and the Vikunja logo belong to the Vikunja project '
    "and are not licensed under the MIT License. The app's icons derive from "
    "logo.svg of go-vikunja/vikunja and are used with the project's "
    'permission. A fork that distributes its own build uses its own name and '
    'logo.';

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
  test('LICENSE is the MIT License with the copyright line of the app', () {
    expect(
      _read('LICENSE'),
      'MIT License\n\n$copyrightNotice\n\n$_mitPermission',
    );
  });

  test('the notice file has the copyright line and names the MIT License', () {
    final notice = _read('NOTICE.md');

    expect(notice, contains('\n$copyrightNotice\n'));
    expect(notice, contains('licensed under the MIT License'));
  });

  test("the terms for the name and the logo, in the notice file and the app's "
      'notice', () {
    for (final path in ['NOTICE.md', 'app/assets/legal/vikunja_app.md']) {
      expect(
        _read(path).replaceAll(RegExp(r'\s+'), ' ').replaceAll('`', ''),
        contains(_nameAndLogo),
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

    expect(section, contains('MIT'));
    for (final file in ['LICENSE', 'NOTICE.md', 'CONTRIBUTING.md']) {
      expect(section, contains('($file)'));
      expect(File('$_repository/$file').existsSync(), isTrue, reason: file);
    }
  });
}
