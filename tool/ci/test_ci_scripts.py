"""Checks the tool/ci scripts themselves: that they are executable, the
files they call and the lockfiles osv.sh scans."""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class CiScriptsTest(unittest.TestCase):
    SOURCED = {'lib.sh', 'pins.sh', 'release_lib.sh'}

    def test_the_scripts_are_executable(self):
        for script in sorted(os.listdir(os.path.join(ROOT, 'tool/ci'))):
            if script.endswith('.sh') and script not in self.SOURCED:
                with self.subTest(script):
                    self.assertTrue(os.access(os.path.join(ROOT, 'tool/ci', script), os.X_OK), script)

    def test_the_scripts_call_existing_files(self):
        for script in sorted(os.listdir(os.path.join(ROOT, 'tool/ci'))):
            if not script.endswith('.sh'):
                continue
            with open(os.path.join(ROOT, 'tool/ci', script), encoding='utf-8') as f:
                text = f.read()
            for path in set(re.findall(r'(?:tool|test_servers)/[\w./-]+\.(?:sh|py|yaml|source)', text)):
                with self.subTest(f'{script}: {path}'):
                    self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), path)

    def test_the_scan_covers_the_committed_lockfiles(self):
        with open(os.path.join(ROOT, 'tool/ci/osv.sh'), encoding='utf-8') as f:
            text = f.read()
        files = re.findall(r'--(?:lockfile|config)=(\S+)', text)
        self.assertEqual(sorted(files), ['app/android/app/gradle.lockfile', 'app/editor/package-lock.json',
                                         'osv-scanner.toml', 'pubspec.lock'])
        for path in files:
            self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), path)


if __name__ == '__main__':
    unittest.main()
