import contextlib
import io
import os
import tempfile
import unittest

from release_version import VersionError, check_pubspec, ios_version, main, pubspec_version_name, release_version


def number(tag):
    return release_version(tag)[1]


class ReleaseVersionTest(unittest.TestCase):
    def test_betas(self):
        self.assertEqual(release_version('v1.0.0-beta.1'), ('1.0.0-beta.1', 1_000_001, 'beta'))
        self.assertEqual(release_version('v1.2.3-beta.4'), ('1.2.3-beta.4', 1_020_304, 'beta'))
        self.assertEqual(release_version('v0.1.0-beta.98'), ('0.1.0-beta.98', 10_098, 'beta'))

    def test_finals(self):
        self.assertEqual(release_version('v1.0.0'), ('1.0.0', 1_000_099, 'final'))
        self.assertEqual(release_version('v0.1.0'), ('0.1.0', 10_099, 'final'))
        self.assertEqual(release_version('v2099.99.99'), ('2099.99.99', 2_099_999_999, 'final'))
        self.assertLess(number('v2099.99.99'), 2_100_000_000)

    def test_ordering(self):
        tags = ['v1.0.0-beta.1', 'v1.0.0-beta.2', 'v1.0.0-beta.98', 'v1.0.0', 'v1.0.1-beta.1', 'v1.0.1',
                'v1.1.0-beta.1', 'v1.99.99', 'v2.0.0-beta.1', 'v2.0.0']
        numbers = [number(tag) for tag in tags]
        self.assertEqual(numbers, sorted(numbers))
        self.assertEqual(len(set(numbers)), len(numbers))
        self.assertLess(number('v1.0.0-beta.98'), number('v1.0.0'))
        self.assertLess(number('v1.0.0'), number('v1.0.1-beta.1'))
        self.assertLess(number('v1.99.99'), number('v2.0.0-beta.1'))

    def test_ios(self):
        self.assertEqual(ios_version('v1.0.0-beta.1'), ('1.0.0', 1_000_001))
        self.assertEqual(ios_version('v1.2.3-beta.4'), ('1.2.3', 1_020_304))
        self.assertEqual(ios_version('v1.2.3'), ('1.2.3', 1_020_399))
        self.assertEqual(ios_version('v2099.99.99'), ('2099.99.99', 2_099_999_999))
        with self.assertRaises(VersionError):
            ios_version('v1.0.0-rc.1')

    def test_ios_build_numbers_grow(self):
        tags = ['v1.0.0-beta.1', 'v1.0.0-beta.2', 'v1.0.0-beta.98', 'v1.0.0', 'v1.0.1-beta.1', 'v1.1.0']
        versions = [ios_version(tag) for tag in tags]
        self.assertEqual([name for name, _ in versions[:4]], ['1.0.0'] * 4)
        builds = [build for _, build in versions]
        self.assertEqual(builds, sorted(set(builds)))
        for name, build in versions:
            with self.subTest(name=name, build=build):
                self.assertRegex(name, r'\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\Z')
                self.assertRegex(str(build), r'\A[1-9][0-9]{0,9}\Z')

    def test_bad_tags(self):
        for tag in ['v1.0', '1.0.0', 'v1.0.0-rc.1', 'v01.0.0', 'v1.01.0', 'v1.0.01', 'v1.100.0', 'v1.0.100',
                    'v2100.0.0', 'v1.0.0-beta.0', 'v1.0.0-beta.99', 'v1.0.0-beta.01', 'v1.0.0-beta', 'v1.0.0-beta.1x',
                    'v1.0.0+1', ' v1.0.0', 'v1.0.0\n', 'V1.0.0', 'v1.0.0-BETA.1', 'v', '']:
            with self.subTest(tag=tag), self.assertRaises(VersionError):
                release_version(tag)

    def test_pubspec_version_name(self):
        self.assertEqual(pubspec_version_name('name: app\nversion: 0.1.0+1\n'), '0.1.0')
        self.assertEqual(pubspec_version_name('version: 1.0.0-beta.2+7 # comment\n'), '1.0.0-beta.2')
        self.assertEqual(pubspec_version_name("version: '1.0.0'\n"), '1.0.0')
        with self.assertRaises(VersionError):
            pubspec_version_name('name: app\n  version: 1.0.0\n')

    def test_pubspec_mismatch(self):
        check_pubspec('1.0.0-beta.1', 'version: 1.0.0-beta.1+3\n')
        for pubspec in ['version: 1.0.0+1\n', 'version: 1.0.0-beta.2+1\n', 'version: 1.0.1-beta.1\n']:
            with self.subTest(pubspec=pubspec), self.assertRaises(VersionError):
                check_pubspec('1.0.0-beta.1', pubspec)

    def test_main(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = os.path.join(directory, 'pubspec.yaml')
            with open(pubspec, 'w', encoding='utf-8') as f:
                f.write('name: app\nversion: 1.2.3-beta.4+1\n')
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                self.assertEqual(main(['v1.2.3-beta.4', '--pubspec', pubspec]), 0)
                self.assertEqual(main(['v1.2.3', '--pubspec', pubspec]), 1)
                self.assertEqual(main(['v1.2', '--pubspec', pubspec]), 1)
                self.assertEqual(main([]), 2)
            self.assertEqual(out.getvalue(), 'BUILD_NAME=1.2.3-beta.4\nBUILD_NUMBER=1020304\nCHANNEL=beta\n'
                             'IOS_BUILD_NAME=1.2.3\nIOS_BUILD_NUMBER=1020304\n')
            self.assertIn('bump the pubspec', err.getvalue())


if __name__ == '__main__':
    unittest.main()
