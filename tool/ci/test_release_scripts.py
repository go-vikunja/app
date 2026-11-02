"""Checks the site URL guard of tool/ci/release.sh and tool/ci/ios_release.sh
(D76): both read site_url from site/site.json, refuse an empty or non-https
one and a site.json from which tool/build_site.py cannot build the website,
and pass it to the release test and every build beside the source URL."""
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPTS = ['tool/ci/release.sh', 'tool/ci/ios_release.sh']
GUARD_START = '# The website with the privacy policy and the legal notice, which the About\n'
GUARD_END = '    "website incomplete"\nfi\n'
FILLED = {
    'site_url': 'https://rurana.example.org',
    'contact_email': 'contact@rurana.example.org',
    'legal_name': 'Example Name',
    'address_lines': ['c/o Example Service', 'Example Street 1', '12345 Example Town'],
    'country': 'Germany',
}
# The scripts' refuse() as it behaves: a reason in the dry run, else the end.
HARNESS = '''set -euo pipefail
dry_run="$1"
not_releasable=()
refuse() {
  if ((dry_run)); then
    echo "warning (dry run): $1" >&2
    not_releasable+=("$2")
  else
    echo "error: $1" >&2
    exit 1
  fi
}
'''
REPORT = '''
printf 'site_url=%s\\n' "$site_url"
printf 'reasons=%s\\n' "${not_releasable[*]+${not_releasable[*]}}"
'''


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8') as f:
        return f.read()


def guard(path):
    text = read(path)
    start = text.index(GUARD_START)
    return text[start:text.index(GUARD_END, start) + len(GUARD_END)]


class SiteUrlGuardTest(unittest.TestCase):
    def run_guard(self, site_json, dry_run=False, script=SCRIPTS[0]):
        with tempfile.TemporaryDirectory() as directory:
            if site_json is not None:
                shutil.copytree(os.path.join(ROOT, 'site'), os.path.join(directory, 'site'))
                os.mkdir(os.path.join(directory, 'tool'))
                shutil.copy(os.path.join(ROOT, 'tool', 'build_site.py'), os.path.join(directory, 'tool'))
                with open(os.path.join(directory, 'site', 'site.json'), 'w', encoding='utf-8') as f:
                    f.write(site_json if isinstance(site_json, str) else json.dumps(site_json))
            return subprocess.run(['bash', '-c', HARNESS + guard(script) + REPORT, 'guard', '1' if dry_run else '0'],
                                  cwd=directory, capture_output=True, text=True)

    def test_both_scripts_have_the_same_guard(self):
        self.assertEqual(guard(SCRIPTS[0]), guard(SCRIPTS[1]))

    def test_a_complete_site_passes(self):
        for script in SCRIPTS:
            result = self.run_guard(FILLED, script=script)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('site_url=https://rurana.example.org\n', result.stdout)
            self.assertIn('reasons=\n', result.stdout)

    def test_a_site_that_cannot_be_built_is_refused(self):
        for site in [dict(FILLED, country=''), dict(FILLED, address_lines=[]), dict(FILLED, legal_name=''),
                     dict(FILLED, contact_email=''), dict(FILLED, site_url='https://rurana.example.org/'),
                     dict(FILLED, site_url='https://rurana.example.org/?a=b')]:
            result = self.run_guard(site)
            self.assertEqual(result.returncode, 1, site)
            self.assertIn('error: the website the app links cannot be built', result.stderr)

    def test_the_dry_run_names_an_incomplete_site(self):
        result = self.run_guard(dict(FILLED, country=''), dry_run=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('no value yet for: country', result.stderr)
        self.assertIn('reasons=website incomplete\n', result.stdout)

    def test_an_empty_or_insecure_url_is_refused(self):
        for site in [{'site_url': ''}, {}, {'site_url': None}, {'site_url': 'http://rurana.example.org'},
                     {'site_url': 'https://'}]:
            result = self.run_guard(site)
            self.assertEqual(result.returncode, 1, site)
            self.assertIn('error: the site URL', result.stderr)
            self.assertIn('set site_url in site/site.json', result.stderr)

    def test_the_dry_run_takes_a_placeholder_while_it_is_empty(self):
        result = self.run_guard({'site_url': ''}, dry_run=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('site_url=https://rurana.example\n', result.stdout)
        self.assertIn('reasons=placeholder site URL\n', result.stdout)

    def test_the_dry_run_names_an_insecure_url(self):
        result = self.run_guard({'site_url': 'http://rurana.example.org'}, dry_run=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('reasons=site URL\n', result.stdout)

    def test_a_missing_or_broken_file_stops_it(self):
        for site_json in [None, '{"site_url": ', '["https://rurana.example.org"]']:
            result = self.run_guard(site_json, dry_run=True)
            self.assertEqual(result.returncode, 1, site_json)
            self.assertIn('error: site/site.json cannot be read', result.stderr)

    def test_every_build_and_the_release_test_get_both_urls(self):
        source = '--dart-define=SOURCE_CODE_URL="$source_url"'
        both = f'{source} --dart-define=SITE_URL="$site_url"'
        for script in SCRIPTS:
            text = re.sub(r'\s*\\\n\s*', ' ', read(script))
            self.assertGreaterEqual(text.count(source), 2, script)
            self.assertEqual(text.count(source), text.count(both), script)
            self.assertIn(f'flutter test --run-skipped --tags release {both}', text, script)


if __name__ == '__main__':
    unittest.main()
