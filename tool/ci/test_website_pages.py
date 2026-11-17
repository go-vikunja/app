"""Tests the release scripts' check of the vikunja.io pages
(check_website_pages in tool/ci/release_lib.sh) with a fake curl first on
PATH, and that its list is what the app and the store listings link."""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB = os.path.join(ROOT, 'tool/ci/release_lib.sh')
VIKUNJA_IO = re.compile(r'https://vikunja\.io(?:/[^\s`\'"<>()]*)?')

FAKE_CURL = r'''
import json
import os
import sys

argv = sys.argv[1:]
with open(os.environ['FAKE_LOG'], 'a', encoding='utf-8') as f:
    f.write(json.dumps(argv) + '\n')
url = argv[-1]
status, final, body = json.loads(os.environ['FAKE_PAGES']).get(url, ['000', url, ''])
with open(argv[argv.index('--output') + 1], 'w', encoding='utf-8') as f:
    f.write(body)
sys.stdout.write(argv[argv.index('--write-out') + 1].replace('%{http_code}', status)
                 .replace('%{url_effective}', final))
sys.exit(6 if status == '000' else 0)
'''

# The caller's refuse: a dry run's, or a real run's, which exits.
HARNESS = r'''
set -euo pipefail
source "$1"
shift
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
check_website_pages "$@"
'''


def listed_pages():
    result = subprocess.run(['bash', '-c', 'source "$1"; printf "%s\\n" "${RELEASE_WEBSITE_PAGES[@]}"', 'bash', LIB],
                            capture_output=True, text=True, check=True)
    return result.stdout.splitlines()


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8') as f:
        return f.read()


def page_of(url):
    return url.split('#', 1)[0]


def html(*ids):
    return '<!doctype html><html><body>' + ''.join(f'<h2 {i}>Section</h2>' for i in ids) + '</body></html>'


class WebsitePagesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.temp = os.path.join(self.tmp, 'temp')
        os.mkdir(self.temp)
        os.mkdir(os.path.join(self.tmp, 'bin'))
        self.log = os.path.join(self.tmp, 'curl.jsonl')
        fake = os.path.join(self.tmp, 'fake_curl.py')
        with open(fake, 'w', encoding='utf-8') as f:
            f.write(FAKE_CURL)
        curl = os.path.join(self.tmp, 'bin', 'curl')
        with open(curl, 'w', encoding='utf-8') as f:
            f.write(f'#!/bin/sh\nexec "{sys.executable}" -I "{fake}" "$@"\n')
        os.chmod(curl, 0o755)
        self.pages = listed_pages()
        self.anchors = {}
        for url in self.pages:
            if '#' in url:
                self.anchors.setdefault(page_of(url), []).append(url.split('#', 1)[1])

    def site(self, **changes):
        """Every listed page answering 200 with its anchors' ids, then the
        changes: page -> (status, final URL, body)."""
        site = {}
        for url in self.pages:
            ids = self.anchors.get(page_of(url), [])
            site[page_of(url)] = ['200', page_of(url), html(*(f'id="{i}"' for i in ids))]
        for page, answer in changes.items():
            site[page] = list(answer)
        return site

    def check(self, site, *arguments, real=False):
        env = {'PATH': os.path.join(self.tmp, 'bin') + os.pathsep + os.environ.get('PATH', os.defpath),
               'TMPDIR': self.temp, 'FAKE_LOG': self.log, 'FAKE_PAGES': json.dumps(site),
               'REAL': '1' if real else '0'}
        result = subprocess.run(['bash', '-c', HARNESS, 'bash', LIB, *arguments], env=env, capture_output=True,
                                text=True, timeout=60)
        self.assertEqual(os.listdir(self.temp), [], 'the downloaded page is left behind')
        return result

    def reasons(self, result):
        return [line[len('REASON '):] for line in result.stdout.splitlines() if line.startswith('REASON ')]

    def curl_calls(self):
        if not os.path.exists(self.log):
            return []
        with open(self.log, encoding='utf-8') as f:
            return [json.loads(line) for line in f]

    def test_pages_with_their_anchors_pass(self):
        result = self.check(self.site())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertEqual(self.reasons(result), [])
        ok = [line for line in result.stdout.splitlines() if line.startswith('OK: ')]
        self.assertEqual(len(ok), len(self.pages), result.stdout)
        self.assertIn('OK: https://vikunja.io/privacy/#mobile-app opens signed out and has the id mobile-app.', ok)
        calls = self.curl_calls()
        self.assertEqual([call[-1] for call in calls], [page_of(url) for url in self.pages])
        for call in calls:
            self.assertIn('--location', call)
            self.assertEqual(call[call.index('--proto') + 1], '=https')

    def test_the_forms_html_allows_for_an_id(self):
        for body in ('<section ID="mobile-app">', "<h2 class=x id='mobile-app'>", '<h2\nid=mobile-app>',
                     '<a id="mobile&#45;app"/>', '<div data-x id = "mobile-app" hidden>'):
            with self.subTest(body):
                result = self.check(self.site(**{'https://vikunja.io/privacy/': ('200', 'https://vikunja.io/privacy/',
                                                                                  body)}))
                self.assertEqual(self.reasons(result), [], result.stderr)

    def test_a_redirect_within_the_site_passes(self):
        result = self.check(self.site(**{'https://vikunja.io/help/mobile': (
            '200', 'https://vikunja.io/help/mobile/', html('id="delete-your-account"'))}))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.reasons(result), [])

    def test_a_missing_page_refuses(self):
        result = self.check(self.site(**{'https://vikunja.io/help/mobile': ('404', 'https://vikunja.io/help/mobile',
                                                                            'Not found')}))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.reasons(result), ['https://vikunja.io/help/mobile answered 404',
                                                'https://vikunja.io/help/mobile#delete-your-account answered 404'])
        self.assertIn('warning (dry run): https://vikunja.io/help/mobile answered 404: the app or a store listing '
                      'links it, so it must open for everyone signed out', result.stderr)

    def test_a_page_without_its_anchor_refuses(self):
        body = html('data-id="mobile-app"', 'id="mobile-apps"', 'class="mobile-app"') + '<a href="#mobile-app">'
        result = self.check(self.site(**{'https://vikunja.io/privacy/': ('200', 'https://vikunja.io/privacy/',
                                                                          body)}))
        self.assertEqual(self.reasons(result),
                         ['https://vikunja.io/privacy/#mobile-app has no element with the id mobile-app'])
        self.assertIn('OK: https://vikunja.io/privacy/ opens signed out.', result.stdout)

    def test_a_redirect_to_another_host_refuses(self):
        for final in ('https://example.com/imprint/', 'https://vikunja.io.example.com/imprint/',
                      'https://vikunja.io@example.com/imprint/', 'https://www.vikunja.io/imprint/'):
            with self.subTest(final):
                result = self.check(self.site(**{'https://vikunja.io/imprint/': ('200', final, html())}))
                self.assertEqual(self.reasons(result), [f'https://vikunja.io/imprint/ ends on {final}'])

    def test_no_answer_refuses(self):
        site = self.site()
        del site['https://vikunja.io/imprint/']
        result = self.check(site)
        self.assertEqual(self.reasons(result), ['https://vikunja.io/imprint/ answered 000'])

    def test_a_real_run_stops(self):
        result = self.check(self.site(**{'https://vikunja.io/help/mobile': ('404', 'https://vikunja.io/help/mobile',
                                                                            '')}), real=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: https://vikunja.io/help/mobile answered 404: ', result.stderr)
        self.assertEqual(len(self.curl_calls()), len(self.pages), 'every page is fetched before the refusal')

    def test_would_only_names_the_checks(self):
        result = self.check({}, '--would')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            f'Would check that {url} opens signed out'
            + (f' and has the id {url.split("#", 1)[1]}.' if '#' in url else '.') for url in self.pages])
        self.assertEqual(self.curl_calls(), [])


class WebsitePageListTest(unittest.TestCase):
    def test_the_list_is_what_the_app_and_the_listings_link(self):
        enum = re.search(r'enum WebsitePage \{(.*?);', read('app/lib/app/legal.dart'), re.S)
        self.assertIsNotNone(enum, 'no enum WebsitePage in app/lib/app/legal.dart')
        app = re.findall(r"\b\w+\(\s*'([^']*)',?\s*\)", enum.group(1))
        self.assertEqual(len(app), len(re.findall(r'(?m)^  \w+\(', enum.group(1))), 'a WebsitePage not read')
        listings = set()
        for path in glob.glob(os.path.join(ROOT, 'fastlane/metadata/**/*.txt'), recursive=True):
            with open(path, encoding='utf-8') as f:
                listings.update(url.rstrip('.,;:') for url in VIKUNJA_IO.findall(f.read()))
        self.assertIn('https://vikunja.io/help/mobile', listings)
        deletion = set(re.findall(r'Deletion URL: `([^`]+)`', read('docs/store-listing.md')))
        self.assertEqual(len(deletion), 1, deletion)
        pages = listed_pages()
        self.assertEqual(len(pages), len(set(pages)), 'a page listed twice')
        self.assertEqual(sorted(pages), sorted(set(app) | listings | deletion))

    def test_the_documented_addresses(self):
        listing = read('docs/store-listing.md')
        website = listing[listing.index('### The website'):]
        website = website[:website.index('\n### ')]
        for url in listed_pages():
            with self.subTest(url):
                self.assertIn(f'`{url}`', website)

    def test_the_release_scripts_check_the_pages(self):
        for script in ('release_build.sh', 'ios_release.sh'):
            with self.subTest(script):
                text = read(f'tool/ci/{script}')
                self.assertIn('source "$(dirname "${BASH_SOURCE[0]}")/release_lib.sh"', text)
                self.assertRegex(text, r'(?m)^  check_website_pages --would$')
                self.assertRegex(text, r'(?m)^  check_website_pages$')


if __name__ == '__main__':
    unittest.main()
