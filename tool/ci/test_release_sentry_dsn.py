"""Tests check_sentry_dsn of tool/ci/release_lib.sh, the release builds' rule
for the crash reports' DSN: unset or empty means no crash reports, anything
else must be an https DSN on sentry.io, and a value that is not is never
printed (decision log: Diagnostics). The DSNs here are made up."""
import os
import subprocess
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB = os.path.join(ROOT, 'tool/ci/release_lib.sh')

HARNESS = r'''
set -euo pipefail
source "$1"
check_sentry_dsn
echo "CHECKED"
'''

# Parts of the refused values, none of which may show up in the output.
MARKERS = ('k3ymarker', 's3cretmarker', 'hostmarker', 'pathmarker', 'projectmarker', '9876543', 'o1.ingest')


def check(dsn=None):
    env = {name: value for name, value in os.environ.items() if name != 'VIKUNJA_APP_SENTRY_DSN'}
    if dsn is not None:
        env['VIKUNJA_APP_SENTRY_DSN'] = dsn
    return subprocess.run(['bash', '-c', HARNESS, 'bash', LIB], env=env, capture_output=True, text=True,
                          timeout=60)


class CheckSentryDsnTest(unittest.TestCase):
    def test_no_dsn_builds_without_crash_reports(self):
        for dsn in (None, ''):
            with self.subTest(dsn=dsn):
                result = check(dsn)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('notice: VIKUNJA_APP_SENTRY_DSN is not set, so this build has no crash reports',
                              result.stdout)
                self.assertIn('CHECKED', result.stdout)

    def test_an_https_dsn_on_sentry_io_passes_unprinted(self):
        for dsn in ('https://k3ymarker@o1.ingest.sentry.io/9876543',
                    'https://0123456789abcdef0123456789abcdef@o4500000000000001.ingest.us.sentry.io/9876543',
                    'https://k3ymarker@o1.ingest.de.sentry.io/9876543',
                    'https://k3ymarker@sentry.io/9876543'):
            with self.subTest(dsn=dsn):
                result = check(dsn)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('OK: VIKUNJA_APP_SENTRY_DSN is an https DSN on sentry.io', result.stdout)
                self.assertIn('CHECKED', result.stdout)
                for marker in MARKERS:
                    self.assertNotIn(marker, result.stdout + result.stderr)

    def test_any_other_dsn_fails_without_a_part_of_it_in_the_output(self):
        for dsn in ('http://k3ymarker@o1.ingest.sentry.io/9876543',
                    'https://k3ymarker@o1.ingest.sentry.io:443/9876543',
                    'https://k3ymarker:s3cretmarker@o1.ingest.sentry.io/9876543',
                    'https://@o1.ingest.sentry.io/9876543',
                    'https://o1.ingest.sentry.io/9876543',
                    'https://k3ymarker@o1.ingest.sentry.io/pathmarker/9876543',
                    'https://k3ymarker@o1.ingest.sentry.io/9876543/',
                    'https://k3ymarker@o1.ingest.sentry.io/9876543?pathmarker=1',
                    'https://k3ymarker@o1.ingest.sentry.io/9876543#pathmarker',
                    'https://k3ymarker@o1.ingest.sentry.io/projectmarker',
                    'https://k3ymarker@hostmarker-sentry.io/9876543',
                    'https://k3ymarker@sentry.io.hostmarker.example/9876543',
                    'https://k3ymarker@hostmarker.example/9876543',
                    'https://k3ymarker@hostmarker.example/sentry.io/9876543',
                    'https://k3ymarker@hostmarker.example#@o1.ingest.sentry.io/9876543',
                    'https://k3ymarker@.sentry.io/9876543',
                    'https://k3ymarker@O1.INGEST.SENTRY.IO/9876543',
                    ' https://k3ymarker@o1.ingest.sentry.io/9876543',
                    'https://k3ymarker@o1.ingest.sentry.io/9876543\n',
                    'https://public@example.invalid/1'):
            with self.subTest(dsn=dsn):
                result = check(dsn)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn('error: VIKUNJA_APP_SENTRY_DSN must be https://<key>@<host>/<project id>, the host '
                              'sentry.io or a subdomain of it, without a port, a password, spaces, line breaks or '
                              'anything after the id (decision log: Diagnostics); its value is not shown', result.stderr)
                self.assertNotIn('CHECKED', result.stdout)
                for marker in MARKERS + ('public@', 'example.invalid'):
                    self.assertNotIn(marker, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
