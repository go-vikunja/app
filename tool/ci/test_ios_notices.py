import contextlib
import gzip
import io
import json
import os
import tempfile
import unittest
from unittest import mock

import ios_notices
from ios_notices import NoticeError, check, licence_sections, main

SEPARATOR = '\n' + '-' * 80 + '\n'
AGPL = 'GNU AFFERO GENERAL PUBLIC LICENSE\nVersion 3, 19 November 2007\n'
FLUTTER = 'Copyright 2014 The Flutter Authors. All rights reserved.\n'
BSD = 'Copyright 2013 The Flutter Authors\n\nRedistribution and use in source and binary forms.\n'
APP_LICENSES = """\
abstract final class LegalAssets {
  /// The app's own notice.
  static const ownNotice = 'assets/legal/rurana.md';

  static const portedCode = 'packages/vikunja_logic/THIRD_PARTY_NOTICES.md';
}

const ownLicensePackage = 'rurana';
"""


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = 'wb' if isinstance(content, bytes) else 'w'
    with open(path, mode) as f:
        f.write(content)


class LicenceSectionsTest(unittest.TestCase):
    def test_a_single_licence_is_the_package_s(self):
        self.assertEqual(licence_sections(BSD, 'url_launcher_ios'), [(['url_launcher_ios'], BSD)])

    def test_several_licences_name_their_packages(self):
        text = 'image_picker\n\nlicence one' + SEPARATOR + 'aFileChooser\nother\n\nlicence two' + SEPARATOR + 'bare'
        self.assertEqual(licence_sections(text, 'image_picker_ios'), [
            (['image_picker'], 'licence one'),
            (['aFileChooser', 'other'], 'licence two'),
            (['image_picker_ios'], 'bare'),
        ])


class CheckTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = os.path.join(directory.name, 'repo')
        self.sdk = os.path.join(directory.name, 'flutter')
        self.cache = os.path.join(directory.name, 'pub-cache')
        self.app = os.path.join(directory.name, 'Runner.app')
        self.assets = os.path.join(self.app, 'Frameworks/App.framework/flutter_assets')
        self.packages = {
            'rurana': '../',
            'vikunja_logic': '../packages/vikunja_logic',
            'flutter': f'file://{self.sdk}/packages/flutter',
            'flutter_test': f'file://{self.sdk}/packages/flutter_test',
            'image_picker_ios': f'file://{self.cache}/image_picker_ios-1.0.0',
            'objective_c': f'file://{self.cache}/objective_c-9.0.0',
        }
        write(os.path.join(self.root, 'LICENSE'), AGPL)
        write(os.path.join(self.sdk, 'LICENSE'), FLUTTER)
        write(os.path.join(self.sdk, 'packages/flutter/LICENSE'), FLUTTER)
        write(os.path.join(self.cache, 'image_picker_ios-1.0.0/LICENSE'),
              'image_picker\n\n' + BSD + SEPARATOR + 'aFileChooser\n\nMIT')
        write(os.path.join(self.cache, 'objective_c-9.0.0/LICENSE'), BSD)
        write(os.path.join(self.root, 'app/lib/core/legal/app_licenses.dart'), APP_LICENSES)
        for key, source in [('assets/legal/rurana.md', 'app/assets/legal/rurana.md'),
                            ('packages/vikunja_logic/THIRD_PARTY_NOTICES.md',
                             'packages/vikunja_logic/THIRD_PARTY_NOTICES.md')]:
            write(os.path.join(self.root, source), f'# {key}\n')
            write(os.path.join(self.assets, key), f'# {key}\n')
        self.notices = {'rurana': AGPL, 'flutter': FLUTTER, 'image_picker': BSD, 'aFileChooser': 'MIT',
                        'objective_c': BSD}
        os.makedirs(os.path.join(self.app, 'Frameworks/Flutter.framework'))
        os.makedirs(os.path.join(self.app, 'Frameworks/objective_c.framework'))
        write(os.path.join(self.assets, 'NativeAssetsManifest.json'), json.dumps({
            'format-version': [1, 0, 0],
            'native-assets': {'ios_arm64': {
                'package:objective_c/objective_c.dylib': ['absolute', 'objective_c.framework/objective_c'],
                'package:sqlite3/src/ffi/libsqlite3.g.dart': ['system', '/usr/lib/libsqlite3.dylib'],
            }},
        }))

    def errors(self):
        config = {'configVersion': 2, 'flutterRoot': f'file://{self.sdk}',
                  'packages': [{'name': name, 'rootUri': uri, 'packageUri': 'lib/'}
                               for name, uri in self.packages.items()]}
        write(os.path.join(self.root, '.dart_tool/package_config.json'), json.dumps(config))
        texts = {}
        for name, text in self.notices.items():
            texts.setdefault(text, []).append(name)
        blocks = ['\n'.join(sorted(names)) + '\n\n' + text for text, names in texts.items()]
        write(os.path.join(self.assets, 'NOTICES.Z'), gzip.compress(SEPARATOR.join(blocks).encode()))
        return check(self.app, self.root)[0]

    def test_complete(self):
        self.assertEqual(self.errors(), [])

    def test_a_licence_missing_from_the_notices(self):
        del self.notices['aFileChooser']
        self.assertEqual(self.errors(), [
            f'NOTICES.Z lacks the licence of aFileChooser from {self.cache}/image_picker_ios-1.0.0/LICENSE'])

    def test_the_sdk_licence_covers_sdk_packages_without_a_file(self):
        del self.notices['flutter']
        self.assertEqual(self.errors(), [
            f'NOTICES.Z lacks the licence of flutter from {self.sdk}/packages/flutter/LICENSE',
            f'NOTICES.Z lacks the licence of flutter_test from {self.sdk}/LICENSE',
        ])

    def test_whitespace_does_not_count(self):
        self.notices['objective_c'] = '  ' + BSD.replace('\n', '\n ') + '\n'
        self.assertEqual(self.errors(), [])

    def test_a_package_without_a_licence_file(self):
        self.packages['vendored'] = f'file://{self.cache}/vendored-1.0.0'
        os.makedirs(os.path.join(self.cache, 'vendored-1.0.0'))
        errors = self.errors()
        self.assertEqual(len(errors), 1)
        self.assertIn('vendored', errors[0])
        self.assertIn('has no LICENSE or NOTICES file', errors[0])

    def test_notices_file_comes_first(self):
        write(os.path.join(self.cache, 'objective_c-9.0.0/NOTICES'), 'objective_c\n\nZlib' + SEPARATOR + 'x\n\nMIT')
        self.assertEqual(self.errors(), [
            f'NOTICES.Z lacks the licence of objective_c from {self.cache}/objective_c-9.0.0/NOTICES'])

    def test_the_repository_s_licence_under_another_name(self):
        self.notices['vikunja_mobile'] = self.notices.pop('rurana')
        self.assertEqual(self.errors(), [
            "NOTICES.Z does not list the repository's LICENSE under rurana (ownLicensePackage in "
            "app/lib/core/legal/app_licenses.dart) but under vikunja_mobile"])

    def test_a_framework_from_no_package(self):
        os.makedirs(os.path.join(self.app, 'Frameworks/Vendor.framework/Frameworks/Inner.framework'))
        os.makedirs(os.path.join(self.app, 'PlugIns/Widgets.appex/Frameworks/Other.framework'))
        self.assertEqual(self.errors(), [
            'Frameworks/Vendor.framework comes from no pub package, so no notice on the licence page covers it',
            'PlugIns/Widgets.appex/Frameworks/Other.framework comes from no pub package, so no notice on the licence '
            'page covers it',
        ])

    def test_a_native_asset_package_outside_the_workspace(self):
        del self.packages['objective_c']
        del self.notices['objective_c']
        self.assertEqual(self.errors(), ['the native asset package objective_c is not in the pub workspace'])

    def test_a_legal_asset_missing_or_stale(self):
        os.remove(os.path.join(self.assets, 'assets/legal/rurana.md'))
        write(os.path.join(self.assets, 'packages/vikunja_logic/THIRD_PARTY_NOTICES.md'), 'old\n')
        self.assertEqual(self.errors(), [
            'the legal asset assets/legal/rurana.md is not bundled, so the licence page leaves it out',
            f'the bundled packages/vikunja_logic/THIRD_PARTY_NOTICES.md differs from '
            f'{self.root}/packages/vikunja_logic/THIRD_PARTY_NOTICES.md',
        ])

    def test_no_notices(self):
        self.errors()
        os.remove(os.path.join(self.assets, 'NOTICES.Z'))
        with self.assertRaisesRegex(NoticeError, 'NOTICES.Z is missing'):
            check(self.app, self.root)

    def test_no_legal_assets_class(self):
        write(os.path.join(self.root, 'app/lib/core/legal/app_licenses.dart'), 'const ownLicensePackage = \'x\';\n')
        with self.assertRaisesRegex(NoticeError, 'no LegalAssets class'):
            self.errors()


class MainTest(unittest.TestCase):
    def run_main(self, arguments):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(arguments)
        return code, out.getvalue(), err.getvalue()

    def test_not_a_bundle(self):
        code, _, err = self.run_main(['/nonexistent/Runner.app'])
        self.assertEqual(code, 1)
        self.assertIn('is not a bundle', err)
        self.assertEqual(self.run_main([])[0], 2)

    def test_errors_and_summary(self):
        with tempfile.TemporaryDirectory() as app:
            with mock.patch.object(ios_notices, 'check', return_value=(['one', 'two'], 'summary')):
                self.assertEqual(self.run_main([app]), (1, '', 'error: one\nerror: two\n'))
            with mock.patch.object(ios_notices, 'check', return_value=([], 'summary')):
                self.assertEqual(self.run_main([app]), (0, 'summary\n', ''))

if __name__ == '__main__':
    unittest.main()
