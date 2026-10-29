import contextlib
import io
import os
import plistlib
import tempfile
import unittest
from unittest import mock

import required_reason_apis
from required_reason_apis import (BOOT_TIME, DISK_SPACE, FILE_TIMESTAMP, KEYBOARDS, USER_DEFAULTS, ScanError,
                                  declared, main, scan, uses)

MACH_O = b'\xcf\xfa\xed\xfe' + b'\0' * 28


def write_manifest(path, categories):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    entries = [{'NSPrivacyAccessedAPIType': category, 'NSPrivacyAccessedAPITypeReasons': reasons}
               for category, reasons in categories.items()]
    with open(path, 'wb') as f:
        plistlib.dump({'NSPrivacyTracking': False, 'NSPrivacyAccessedAPITypes': entries}, f)


def write_binary(path, extra=b''):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(MACH_O + extra)


class UsesTest(unittest.TestCase):
    def test_symbols(self):
        found = uses(['_statfs', '_fstatfs', '_stat', '_lstat$INODE64', '_OBJC_CLASS_$_NSUserDefaults',
                      '_mach_absolute_time', '_free', '', '/x (for architecture arm64):'], b'')
        self.assertEqual(found, {
            DISK_SPACE: ['fstatfs', 'statfs'],
            FILE_TIMESTAMP: ['lstat', 'stat'],
            USER_DEFAULTS: ['OBJC_CLASS_$_NSUserDefaults'],
            BOOT_TIME: ['mach_absolute_time'],
        })

    def test_getattrlist_is_in_two_categories(self):
        self.assertEqual(uses(['_getattrlist'], b''), {FILE_TIMESTAMP: ['getattrlist'], DISK_SPACE: ['getattrlist']})

    def test_selectors(self):
        self.assertEqual(uses([], b'\0systemUptime\0activeInputModes\0'),
                         {BOOT_TIME: ['systemUptime'], KEYBOARDS: ['activeInputModes']})
        self.assertEqual(uses([], b'\0systemUptimeLabel\0setActiveInputModes:\0_activeInputModes\0'), {})

    def test_nothing(self):
        self.assertEqual(uses(['_malloc', '_NSFileSize'], b'statfs'), {})


class DeclaredTest(unittest.TestCase):
    def test_categories_with_reasons(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = os.path.join(directory, 'PrivacyInfo.xcprivacy')
            write_manifest(manifest, {FILE_TIMESTAMP: ['C617.1'], DISK_SPACE: []})
            self.assertEqual(declared(manifest), {FILE_TIMESTAMP})

    def test_unreadable(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = os.path.join(directory, 'PrivacyInfo.xcprivacy')
            with open(manifest, 'w', encoding='utf-8') as f:
                f.write('not a plist')
            with self.assertRaises(ScanError):
                declared(manifest)


class ScanTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = os.path.join(self.directory.name, 'Runner.app')
        self.symbols = {}

    def binary(self, relative, symbols=(), extra=b''):
        path = os.path.join(self.app, relative)
        write_binary(path, extra)
        self.symbols[path] = list(symbols)

    def missing(self):
        report = scan(self.app, symbols_of=lambda path: self.symbols[path])
        return {os.path.relpath(path, self.app): missing for path, _, missing in report}

    def test_each_binary_against_its_manifests(self):
        write_manifest(os.path.join(self.app, 'PrivacyInfo.xcprivacy'), {FILE_TIMESTAMP: ['C617.1']})
        write_manifest(os.path.join(self.app, 'plugin.bundle/PrivacyInfo.xcprivacy'), {USER_DEFAULTS: ['CA92.1']})
        write_manifest(os.path.join(self.app, 'Frameworks/Flutter.framework/PrivacyInfo.xcprivacy'),
                       {FILE_TIMESTAMP: ['0A2A.1'], BOOT_TIME: ['35F9.1']})
        self.binary('Runner', ['_stat', '_OBJC_CLASS_$_NSUserDefaults'], b'\0systemUptime\0')
        self.binary('Frameworks/Flutter.framework/Flutter', ['_stat'], b'\0systemUptime\0')
        self.binary('Frameworks/sqlite3.framework/sqlite3', ['_stat', '_statfs', '_fstatfs'])
        self.binary('Frameworks/objective_c.framework/objective_c', ['_objc_msgSend'])
        for info in ['Info.plist', 'Frameworks/sqlite3.framework/Info.plist']:
            with open(os.path.join(self.app, info), 'wb') as f:
                plistlib.dump({'CFBundleExecutable': 'x'}, f)

        self.assertEqual(self.missing(), {
            'Runner': {BOOT_TIME: ['systemUptime']},
            'Frameworks/Flutter.framework/Flutter': {},
            'Frameworks/sqlite3.framework/sqlite3': {DISK_SPACE: ['fstatfs', 'statfs'], FILE_TIMESTAMP: ['stat']},
            'Frameworks/objective_c.framework/objective_c': {},
        })

    def test_an_extension_is_a_bundle_of_its_own(self):
        write_manifest(os.path.join(self.app, 'PrivacyInfo.xcprivacy'), {USER_DEFAULTS: ['CA92.1']})
        write_manifest(os.path.join(self.app, 'PlugIns/Widgets.appex/PrivacyInfo.xcprivacy'),
                       {FILE_TIMESTAMP: ['C617.1']})
        self.binary('Runner', ['_OBJC_CLASS_$_NSUserDefaults'])
        self.binary('PlugIns/Widgets.appex/Widgets', ['_OBJC_CLASS_$_NSUserDefaults', '_NSFileModificationDate'])

        missing = self.missing()
        self.assertEqual(missing['Runner'], {})
        self.assertEqual(missing['PlugIns/Widgets.appex/Widgets'], {USER_DEFAULTS: ['OBJC_CLASS_$_NSUserDefaults']})

    def test_symlinks_are_skipped(self):
        self.binary('Runner')
        os.symlink(os.path.join(self.app, 'Runner'), os.path.join(self.app, 'link'))
        self.assertEqual(list(self.missing()), ['Runner'])


class MainTest(unittest.TestCase):
    def run_main(self, arguments, report=()):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(required_reason_apis, 'scan', return_value=list(report)), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(arguments)
        return code, out.getvalue(), err.getvalue()

    def test_declared(self):
        with tempfile.TemporaryDirectory() as directory:
            app = os.path.join(directory, 'Runner.app')
            os.mkdir(app)
            code, out, err = self.run_main([app], [(os.path.join(app, 'Runner'), {FILE_TIMESTAMP: ['stat']}, {}),
                                                   (os.path.join(app, 'Other'), {}, {})])
        self.assertEqual(code, 0)
        self.assertEqual(out, 'Runner.app/Runner: FileTimestamp\nRunner.app/Other: none\n')
        self.assertEqual(err, '')

    def test_undeclared(self):
        with tempfile.TemporaryDirectory() as directory:
            app = os.path.join(directory, 'Runner.app')
            os.mkdir(app)
            binary = os.path.join(app, 'Frameworks/sqlite3.framework/sqlite3')
            used = {DISK_SPACE: ['statfs'], FILE_TIMESTAMP: ['stat']}
            code, out, err = self.run_main([app], [(binary, used, {DISK_SPACE: ['statfs']})])
        self.assertEqual(code, 1)
        self.assertEqual(out, 'Runner.app/Frameworks/sqlite3.framework/sqlite3: DiskSpace, FileTimestamp\n')
        self.assertIn('sqlite3.framework/sqlite3 uses DiskSpace (statfs)', err)

    def test_not_a_bundle(self):
        code, _, err = self.run_main(['/nonexistent/Runner.app'])
        self.assertEqual(code, 1)
        self.assertIn('is not a bundle', err)
        self.assertEqual(self.run_main([])[0], 2)


if __name__ == '__main__':
    unittest.main()
