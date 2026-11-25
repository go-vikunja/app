"""Tests check_german of tool/ci/release_lib.sh, the release scripts' German
check, and its override for a patch release, on a copy of the
scripts beside ARB files of the test's own (decision log: Languages)."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The caller's refuse: a dry run's, or a real run's, which exits.
HARNESS = r'''
set -euo pipefail
cd "$1"
source tool/ci/release_lib.sh
if [[ "$REAL" == 1 ]]; then
  refuse() {
    echo "error: $1" >&2
    exit 1
  }
else
  refuse() {
    echo "warning (dry run): $1" >&2
    echo "REASON $2"
  }
fi
check_german "$2"
echo "CHECKED"
'''


class CheckGermanTest(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.repo)
        os.makedirs(os.path.join(self.repo, 'tool/ci'))
        os.makedirs(os.path.join(self.repo, 'app/lib/l10n/arb'))
        shutil.copy(os.path.join(ROOT, 'tool/l10n_progress.py'), os.path.join(self.repo, 'tool'))
        shutil.copy(os.path.join(ROOT, 'tool/ci/release_lib.sh'), os.path.join(self.repo, 'tool/ci'))
        self.arb('en', {f'text{index}': f'Text {index}' for index in range(10)})

    def arb(self, locale, messages):
        with open(os.path.join(self.repo, f'app/lib/l10n/arb/app_{locale}.arb'), 'w', encoding='utf-8') as f:
            json.dump(messages, f)

    def check(self, tag, allowed=None, real=True, github=False):
        env = {name: value for name, value in os.environ.items()
               if name not in ('VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN', 'GITHUB_ACTIONS')}
        env['REAL'] = '1' if real else '0'
        if allowed is not None:
            env['VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN'] = allowed
        if github:
            env['GITHUB_ACTIONS'] = 'true'
        return subprocess.run(['bash', '-c', HARNESS, 'bash', self.repo, tag], env=env, capture_output=True,
                              text=True, timeout=60)

    def german(self, translated):
        self.arb('de', {f'text{index}': f'Text {index} auf Deutsch' for index in range(translated)})

    def test_complete_german_passes(self):
        self.german(10)
        for tag in ('v1.0.0', 'v1.0.1', 'v1.0.0-beta.1'):
            with self.subTest(tag):
                result = self.check(tag)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('CHECKED', result.stdout)
                self.assertEqual(result.stderr, '')

    def test_incomplete_german_is_refused(self):
        self.german(7)
        result = self.check('v1.0.1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: German lacks 3 of the 10 English texts: a release needs every English text in '
                      'German (decision log: Languages)', result.stderr)
        self.assertIn('VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN=v1.0.1', result.stderr)
        result = self.check('v1.0.1', real=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('REASON German incomplete', result.stdout)

    def test_a_minor_or_major_release_is_not_offered_the_override(self):
        self.german(7)
        for tag in ('v1.1.0', 'v2.0.0-beta.1'):
            with self.subTest(tag):
                result = self.check(tag)
                self.assertEqual(result.returncode, 1)
                self.assertIn(f'error: German lacks 3 of the 10 English texts: a release needs every English text in '
                              f'German (decision log: Languages), and {tag} is no patch release, so the translations must be complete',
                              result.stderr)
                self.assertNotIn('VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN', result.stderr)

    def test_a_patch_release_may_go_without(self):
        self.german(8)
        for tag in ('v1.0.1', 'v2.3.12', 'v1.0.1-beta.2'):
            with self.subTest(tag):
                result = self.check(tag, allowed=tag)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('CHECKED', result.stdout)
                self.assertIn(f'warning: German lacks 2 of the 10 English texts; VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN '
                              f'releases the patch release {tag} without them', result.stderr)
                self.assertNotIn('::warning', result.stdout)
        result = self.check('v1.0.1', allowed='v1.0.1', github=True)
        self.assertIn('::warning title=German incomplete::v1.0.1 is released with 2 of 10 English texts not in German',
                      result.stdout)

    def test_the_override_is_refused_for_a_minor_or_major_release(self):
        self.german(9)
        for tag in ('v1.0.0', 'v1.1.0', 'v2.0.0-beta.1'):
            with self.subTest(tag):
                result = self.check(tag, allowed=tag)
                self.assertEqual(result.returncode, 1)
                self.assertIn(f'is for patch releases only: {tag} needs German complete', result.stderr)
                self.assertNotIn('CHECKED', result.stdout)

    def test_the_override_names_one_tag(self):
        self.german(9)
        for allowed in ('v1.0.1', 'true', 'v1.0.2 '):
            with self.subTest(allowed=allowed):
                result = self.check('v1.0.2', allowed=allowed)
                self.assertEqual(result.returncode, 1)
                self.assertIn(f'VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN names {allowed}, not v1.0.2', result.stderr)

    def test_an_unneeded_override_is_named(self):
        self.german(10)
        result = self.check('v1.0.1', allowed='v1.0.1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('German is complete: VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN (v1.0.1) is not needed', result.stdout)

    def test_an_unreadable_arb_file_is_refused(self):
        with open(os.path.join(self.repo, 'app/lib/l10n/arb/app_de.arb'), 'w', encoding='utf-8') as f:
            f.write('{')
        result = self.check('v1.0.1', allowed='v1.0.1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('could not count the German texts (exit 2)', result.stderr)


if __name__ == '__main__':
    unittest.main()
