"""Tests tool/ci/upstream_versions.py with canned upstream lists: the version
comparison, reading the pins and the lists, and the exit codes."""
import contextlib
import io
import json
import os
import unittest
from unittest import mock

import upstream_versions

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def flutter_releases(stable, *others):
    releases = [{'hash': f'{index:040x}', 'channel': channel, 'version': name}
                for index, (channel, name) in enumerate([('stable', stable), *others], 1)]
    return json.dumps({'current_release': {'stable': f'{1:040x}', 'beta': f'{2:040x}'},
                       'releases': list(reversed(releases))}).encode()


def maven_metadata(*versions):
    listed = ''.join(f'<version>{name}</version>' for name in versions)
    return (f'<?xml version="1.0" encoding="UTF-8"?><metadata><groupId>org.chromium.net</groupId>'
            f'<artifactId>cronet-bundled</artifactId><versioning><versions>{listed}</versions>'
            '</versioning></metadata>').encode()


class VersionTest(unittest.TestCase):
    def test_numbers_not_text(self):
        version = upstream_versions.version
        newer = upstream_versions.newer
        self.assertTrue(newer(version('3.47.10'), version('3.47.9')))
        self.assertTrue(newer(version('500.10.0'), version('500.9.1')))
        self.assertTrue(newer(version('3.48.0'), version('3.47.99')))
        self.assertFalse(newer(version('3.47.9'), version('3.47.9')))
        self.assertFalse(newer(version('3.47.8'), version('3.47.9')))
        self.assertFalse(newer(version('500.1'), version('500.1.0')))
        self.assertTrue(newer(version('500.1.1'), version('500.1')))

    def test_prereleases_are_not_versions(self):
        for name in ('3.48.0-0.1.pre', '501.0.0-alpha01', '501.0.0-rc1', '', 'latest', '1..2'):
            with self.subTest(name):
                self.assertIsNone(upstream_versions.version(name))


class ListsTest(unittest.TestCase):
    def test_flutter_stable_is_the_current_stable_release(self):
        data = flutter_releases('3.47.9', ('beta', '3.48.0-0.2.pre'), ('stable', '3.47.8'))
        self.assertEqual(upstream_versions.flutter_stable(data), '3.47.9')

    def test_flutter_list_errors(self):
        for data in (b'not json', b'{}', json.dumps({'current_release': {'stable': 'x'}, 'releases': []}).encode(),
                     flutter_releases('3.48.0-0.2.pre')):
            with self.subTest(data=data[:40]):
                with self.assertRaises(upstream_versions.UpstreamError):
                    upstream_versions.flutter_stable(data)

    def test_newest_cronet_release(self):
        data = maven_metadata('141.7340.3', '500.1.0', '500.10.0', '500.9.2', '501.0.0-alpha01')
        self.assertEqual(upstream_versions.newest_release(data), '500.10.0')

    def test_cronet_list_errors(self):
        for data in (b'<metadata>', maven_metadata(), maven_metadata('501.0.0-alpha01')):
            with self.subTest(data=data[-60:]):
                with self.assertRaises(upstream_versions.UpstreamError):
                    upstream_versions.newest_release(data)

    def test_the_repository_has_both_pins(self):
        self.assertIsNotNone(upstream_versions.version(
            upstream_versions.pinned(upstream_versions.PINS, upstream_versions.FLUTTER_PIN, 'Flutter')))
        self.assertIsNotNone(upstream_versions.version(
            upstream_versions.pinned(upstream_versions.GRADLE, upstream_versions.CRONET_PIN, 'Cronet')))


class MainTest(unittest.TestCase):
    def run_main(self, flutter, cronet):
        flutter_pin = upstream_versions.pinned(upstream_versions.PINS, upstream_versions.FLUTTER_PIN, 'Flutter')
        cronet_pin = upstream_versions.pinned(upstream_versions.GRADLE, upstream_versions.CRONET_PIN, 'Cronet')
        lists = {upstream_versions.FLUTTER_RELEASES: flutter_releases(flutter.format(pin=flutter_pin)),
                 upstream_versions.CRONET_METADATA: maven_metadata(cronet_pin, cronet.format(pin=cronet_pin))}

        def fetch(url):
            return lists[url]

        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(upstream_versions, 'fetch', fetch), contextlib.redirect_stdout(out), \
                contextlib.redirect_stderr(err):
            code = upstream_versions.main()
        return code, out.getvalue(), err.getvalue(), flutter_pin, cronet_pin

    def test_both_current(self):
        code, out, err, flutter_pin, cronet_pin = self.run_main('{pin}', '{pin}')
        self.assertEqual(code, 0, err)
        self.assertIn(f'Flutter: {flutter_pin} is the newest.', out)
        self.assertIn(f'cronet-bundled: {cronet_pin} is the newest.', out)
        self.assertEqual(err, '')

    def test_newer_flutter_fails(self):
        code, out, err, flutter_pin, _ = self.run_main('99.0.0', '{pin}')
        self.assertEqual(code, 1)
        self.assertIn(f'error: Flutter 99.0.0 is out, tool/ci/pins.sh pins {flutter_pin}. Raise FLUTTER_VERSION', err)

    def test_newer_cronet_fails(self):
        code, out, err, _, cronet_pin = self.run_main('{pin}', '999.0.0')
        self.assertEqual(code, 1)
        self.assertIn(f'error: cronet-bundled 999.0.0 is out, app/android/app/build.gradle.kts pins {cronet_pin}.',
                      err)
        self.assertIn('docs/releasing.md#raising-cronet', err)

    def test_an_unreadable_list_fails(self):
        def fetch(url):
            raise upstream_versions.UpstreamError(f'{url}: timed out')

        err = io.StringIO()
        with mock.patch.object(upstream_versions, 'fetch', fetch), contextlib.redirect_stderr(err):
            self.assertEqual(upstream_versions.main(), 2)
        self.assertIn('timed out', err.getvalue())


if __name__ == '__main__':
    unittest.main()
