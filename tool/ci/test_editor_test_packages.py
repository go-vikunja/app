"""Tests tool/ci/editor_test_packages.py, which keeps advisories in packages
that only the editor's tests use from blocking a release (tool/ci/osv.sh)."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

import editor_test_packages

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(ROOT, 'tool/ci/editor_test_packages.py')
LOCKFILE = os.path.join(ROOT, 'app/editor/package-lock.json')


def lock(packages, dependencies=None, dev=None):
    root = {'name': 'vikunja-editor', 'dependencies': dependencies or {'@tiptap/core': '1.0.0'},
            'devDependencies': dev or {'esbuild': '1.0.0', 'jsdom': '1.0.0'}}
    return {'name': 'vikunja-editor', 'lockfileVersion': 3, 'packages': {'': root, **packages}}


class SplitTest(unittest.TestCase):
    def test_test_only_packages_and_their_own_dependencies(self):
        build, tests = editor_test_packages.split(lock({
            'node_modules/@tiptap/core': {'version': '1.0.0', 'dependencies': {'ms': '^2'}},
            'node_modules/esbuild': {'version': '1.0.0', 'dev': True,
                                     'optionalDependencies': {'@esbuild/linux-x64': '1.0.0'}},
            'node_modules/@esbuild/linux-x64': {'version': '1.0.0', 'dev': True, 'optional': True},
            'node_modules/jsdom': {'version': '1.0.0', 'dev': True, 'dependencies': {'ms': '^1', 'ws': '^8'}},
            'node_modules/jsdom/node_modules/ms': {'version': '1.0.0', 'dev': True},
            'node_modules/ws': {'version': '8.0.0', 'dev': True},
            'node_modules/ms': {'version': '2.0.0'},
        }))
        self.assertEqual(sorted(build['packages']), ['', 'node_modules/@esbuild/linux-x64', 'node_modules/@tiptap/core',
                                                     'node_modules/esbuild', 'node_modules/ms'])
        self.assertEqual(sorted(tests['packages']), ['', 'node_modules/jsdom', 'node_modules/jsdom/node_modules/ms',
                                                     'node_modules/ws'])

    def test_a_package_the_build_shares_stays_a_blocker(self):
        build, tests = editor_test_packages.split(lock({
            'node_modules/@tiptap/core': {'version': '1.0.0', 'dependencies': {'ws': '^8'}},
            'node_modules/esbuild': {'version': '1.0.0', 'dev': True},
            'node_modules/jsdom': {'version': '1.0.0', 'dev': True, 'dependencies': {'ws': '^8'}},
            'node_modules/ws': {'version': '8.0.0'},
        }))
        self.assertIn('node_modules/ws', build['packages'])
        self.assertEqual(sorted(tests['packages']), ['', 'node_modules/jsdom'])

    def test_errors(self):
        cases = (
            ({'lockfileVersion': 1, 'packages': {}}, 'not an npm lockfile'),
            (lock({}, dev={'esbuild': '1.0.0'}), 'jsdom is no devDependency'),
            (lock({'node_modules/@tiptap/core': {'version': '1.0.0', 'dependencies': {'gone': '1'}}}),
             'needs gone'),
            (lock({'node_modules/@tiptap/core': {'version': '1.0.0'}, 'node_modules/stray': {'version': '1.0.0'}}),
             'no dependency reaches node_modules/stray'),
        )
        for data, message in cases:
            with self.subTest(message):
                with self.assertRaisesRegex(editor_test_packages.LockError, message):
                    editor_test_packages.split(data)

    def test_the_committed_lockfile(self):
        with tempfile.TemporaryDirectory() as out:
            result = subprocess.run([sys.executable, '-I', SCRIPT, LOCKFILE, out], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            packages = {}
            for name in ('build', 'tests'):
                with open(os.path.join(out, name, 'package-lock.json'), encoding='utf-8') as f:
                    packages[name] = set(json.load(f)['packages']) - {''}
        with open(LOCKFILE, encoding='utf-8') as f:
            committed = json.load(f)['packages']
        self.assertEqual(packages['build'] | packages['tests'], set(committed) - {''})
        self.assertFalse(packages['build'] & packages['tests'])
        self.assertIn('node_modules/jsdom', packages['tests'])
        self.assertIn('node_modules/esbuild', packages['build'])
        for path in packages['tests']:
            self.assertTrue(committed[path].get('dev'), path)


if __name__ == '__main__':
    unittest.main()
