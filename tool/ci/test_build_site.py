import contextlib
import importlib.util
import io
import json
import os
import shutil
import tempfile
import unittest
from unittest import mock

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_spec = importlib.util.spec_from_file_location('build_site', os.path.join(ROOT, 'tool', 'build_site.py'))
build_site = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(build_site)
SiteError = build_site.SiteError

FILLED = {
    'site_url': 'https://rurana.example',
    'contact_email': 'contact@rurana.example',
    'legal_name': 'Example Name',
    'address_lines': ['c/o Example Service', 'Example Street 1', '12345 Example Town'],
    'country': 'Germany',
}
EMPTY = {'site_url': '', 'contact_email': '', 'legal_name': '', 'address_lines': [], 'country': ''}
PAGE_FILES = ['index.html', 'style.css'] + [f'{lang}/{path}index.html' for lang in ('en', 'de')
                                            for path in ('', 'privacy/', 'legal/', 'support/', 'delete-account/')]


class SiteTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.source = os.path.join(self.tmp, 'site')
        shutil.copytree(os.path.join(ROOT, 'site'), self.source)
        self.out = os.path.join(self.tmp, 'public')

    def write_json(self, name, data):
        with open(os.path.join(self.source, name), 'w', encoding='utf-8') as f:
            json.dump(data, f)

    def build(self, values=None, preview=False, links=None):
        if values is not None:
            self.write_json('site.json', values)
        if links is not None:
            self.write_json('links.json', links)
        return build_site.run(self.source, self.out, preview, check_only=False)

    def read(self, path):
        with open(os.path.join(self.out, path), encoding='utf-8') as f:
            return f.read()


class TheSiteTest(SiteTestCase):
    def test_builds_as_a_preview_with_marked_placeholders(self):
        missing = self.build(EMPTY, preview=True)
        self.assertEqual(missing, list(build_site.VALUES))
        for path in PAGE_FILES:
            self.assertTrue(os.path.isfile(os.path.join(self.out, path)), path)
        legal = self.read('de/legal/index.html')
        self.assertIn('<mark class="placeholder">[site.json: legal_name]</mark>', legal)
        self.assertIn('<meta name="robots" content="noindex">', legal)
        self.assertIn('class="preview"', legal)

    def test_builds_with_values(self):
        self.assertEqual(self.build(FILLED), [])
        self.assertEqual(sorted(os.listdir(self.out)), ['de', 'en', 'index.html', 'style.css'])
        for path in PAGE_FILES[2:]:
            text = self.read(path)
            self.assertNotIn('placeholder', text, path)
            self.assertNotIn('noindex', text, path)
            self.assertNotIn('{{', text, path)
        for lang in ('en', 'de'):
            legal = self.read(f'{lang}/legal/index.html')
            for line in [FILLED['legal_name'], *FILLED['address_lines'], FILLED['country']]:
                self.assertIn(line, legal)
            self.assertIn('<a href="mailto:contact@rurana.example">contact@rurana.example</a>', legal)
            self.assertIn('(rurana.example)', legal)
            privacy = self.read(f'{lang}/privacy/index.html')
            self.assertIn('Example Name', privacy)
            self.assertIn('href="../legal/"', privacy)
        self.assertRegex(self.read('en/privacy/index.html'), r'Version of \d{1,2} [A-Z][a-z]+ \d{4}\.')
        self.assertRegex(self.read('de/privacy/index.html'), r'Stand: \d{1,2}\. [A-ZÄ][a-zä]+ \d{4}\.')

    def test_dates(self):
        with open(os.path.join(ROOT, 'site', 'strings.json'), encoding='utf-8') as f:
            strings = json.load(f)
        self.assertEqual(build_site.formatted_date('2026-03-02', strings['en']), '2 March 2026')
        self.assertEqual(build_site.formatted_date('2026-03-02', strings['de']), '2. März 2026')

    def test_every_page_has_its_language_title_and_frame(self):
        self.build(FILLED)
        for lang, other in (('en', 'de'), ('de', 'en')):
            for path in ('', 'privacy/', 'legal/', 'support/', 'delete-account/'):
                text = self.read(f'{lang}/{path}index.html')
                self.assertIn(f'<html lang="{lang}">', text)
                self.assertIn(f'hreflang="{other}" lang="{other}"', text)
                self.assertEqual(text.count('aria-current="page"'), 1)
                self.assertIn('style.css', text)
        self.assertIn('<title>Privacy policy · Rurana</title>', self.read('en/privacy/index.html'))
        self.assertIn('<title>Impressum · Rurana</title>', self.read('de/legal/index.html'))
        self.assertIn('<title>Rurana</title>', self.read('de/index.html'))

    def test_the_sources_hold_no_email_address(self):
        with open(os.path.join(ROOT, 'site', 'strings.json'), encoding='utf-8') as f:
            texts = [f.read()]
        for directory, _, names in os.walk(os.path.join(ROOT, 'site')):
            for name in names:
                if name.endswith('.html'):
                    with open(os.path.join(directory, name), encoding='utf-8') as f:
                        texts.append(f.read())
        for text in texts:
            self.assertNotRegex(text, r'[\w.+-]+@[\w-]+\.[\w.]+')


class ValuesTest(SiteTestCase):
    def test_refuses_without_values(self):
        with self.assertRaises(SiteError) as raised:
            self.build(EMPTY)
        message = str(raised.exception)
        self.assertIn('site/site.json has no value yet for: site_url, contact_email, legal_name, address_lines, '
                      'country.', message)
        self.assertIn('--preview', message)
        self.assertFalse(os.path.exists(self.out))

    def test_names_only_the_missing_values(self):
        with self.assertRaisesRegex(SiteError, r'no value yet for: legal_name, country\.'):
            self.build(dict(FILLED, legal_name='', country=''))

    def test_malformed_values_fail_in_a_preview_too(self):
        cases = [
            (dict(site_url='http://rurana.example'), 'site_url must be an https address'),
            (dict(site_url='https://rurana.example/'), 'site_url must not end with a slash'),
            (dict(site_url='https://rurana.example?x=1'), 'must not carry a query or fragment'),
            (dict(site_url='https://me@rurana.example'), 'must not carry a user'),
            (dict(site_url='rurana.example'), 'site_url must be an https address'),
            (dict(contact_email='contact'), 'contact_email is not an email address'),
            (dict(contact_email='a@b'), 'contact_email is not an email address'),
            (dict(contact_email=' contact@rurana.example'), 'contact_email has spaces around it'),
            (dict(legal_name=3), 'legal_name must be a string'),
            (dict(address_lines='Example Street 1'), 'address_lines must be a list of strings'),
            (dict(address_lines=['Example Street 1']), 'at least two lines'),
            (dict(address_lines=['Example Street 1', '']), 'must not hold empty lines'),
        ]
        for change, expected in cases:
            for preview in (False, True):
                with self.subTest(change=change, preview=preview):
                    with self.assertRaisesRegex(SiteError, expected):
                        self.build(dict(FILLED, **change), preview=preview)
        values = dict(FILLED)
        del values['country']
        with self.assertRaisesRegex(SiteError, 'country is missing'):
            self.build(values, preview=True)

    def test_values_are_escaped(self):
        self.build(dict(FILLED, legal_name='A <b>&amp; "{{legal_name}}"', country='<script>x</script>'))
        legal = self.read('en/legal/index.html')
        self.assertIn('A &lt;b&gt;&amp;amp; &quot;{{legal_name}}&quot;', legal)
        self.assertIn('&lt;script&gt;x&lt;/script&gt;', legal)
        self.assertNotIn('<script>', legal)

    def test_links(self):
        self.build(FILLED)
        home, support = self.read('en/index.html'), self.read('de/support/index.html')
        self.assertIn('<li>Google Play (coming soon)</li>', home)
        self.assertIn('will be published on GitLab with the first release', home)
        self.assertIn('Sobald der Quellcode auf GitLab veröffentlicht ist', support)
        self.build(links={'source_code_url': 'https://gitlab.com/example/rurana',
                          'google_play_url': 'https://play.google.com/store/apps/details?id=x', 'app_store_url': ''})
        home, support = self.read('en/index.html'), self.read('de/support/index.html')
        self.assertIn('<a href="https://play.google.com/store/apps/details?id=x">Google Play</a>', home)
        self.assertIn('<li>App Store (coming soon)</li>', home)
        self.assertIn('href="https://gitlab.com/example/rurana/-/releases"', home)
        self.assertIn('href="https://gitlab.com/example/rurana"', home)
        self.assertIn('href="https://gitlab.com/example/rurana/-/issues"', support)

    def test_links_must_be_https(self):
        with self.assertRaisesRegex(SiteError, 'site/links.json: source_code_url must be an https address'):
            self.build(FILLED, links={'source_code_url': 'http://gitlab.example/rurana'})
        with self.assertRaisesRegex(SiteError, 'source_code_url must not end with a slash'):
            self.build(links={'source_code_url': 'https://gitlab.example/rurana/'})
        with self.assertRaisesRegex(SiteError, 'app_store_url must be an https address'):
            self.build(links={'app_store_url': 'apps.apple.com/app/id1'})


class SourcesTest(SiteTestCase):
    def edit(self, path, old, new):
        path = os.path.join(self.source, path)
        with open(path, encoding='utf-8') as f:
            text = f.read()
        self.assertIn(old, text)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text.replace(old, new, 1))

    def test_render(self):
        self.assertEqual(build_site.render('a {{x}} {{ y }}', {'x': '{{y}}', 'y': '1'}, 'here'), 'a {{y}} 1')
        with self.assertRaisesRegex(SiteError, r'here: unknown value \{\{z\}\}'):
            build_site.render('{{z}}', {}, 'here')
        for template in ('{{x', 'x}}', '{{X}}'):
            with self.subTest(template), self.assertRaisesRegex(SiteError, 'outside a'):
                build_site.render(template, {'x': ''}, 'here')

    def test_an_unknown_value_in_a_page_fails(self):
        self.edit('pages/de/support.html', '{{issues}}', '{{issue}}')
        with self.assertRaisesRegex(SiteError, r'site/pages/de/support.html: unknown value \{\{issue\}\}'):
            self.build(FILLED)

    def test_both_languages_carry_the_same_version(self):
        self.edit('pages/en/privacy.html', 'updated: 2026-11-02', 'updated: 2026-11-03')
        with self.assertRaisesRegex(SiteError, 'same updated date'):
            self.build(FILLED)

    def test_a_missing_translation_fails(self):
        os.remove(os.path.join(self.source, 'pages', 'de', 'legal.html'))
        with self.assertRaisesRegex(SiteError, 'pages/de/legal.html'):
            self.build(FILLED)

    def test_strings_in_both_languages(self):
        self.edit('strings.json', '"skip": "Zum Inhalt springen",', '')
        with self.assertRaisesRegex(SiteError, 'site/strings.json: de needs exactly the texts'):
            self.build(FILLED)

    def test_front_matter(self):
        self.edit('pages/en/legal.html', 'nav: Legal notice\n', '')
        with self.assertRaisesRegex(SiteError, 'front matter lacks nav'):
            self.build(FILLED)

    def test_anchors_must_match_between_languages(self):
        self.edit('pages/de/legal.html', 'id="scope"', 'id="geltung"')
        with self.assertRaisesRegex(SiteError, 'the anchors differ'):
            self.build(FILLED)

    def test_refuses_to_replace_another_folder(self):
        os.makedirs(self.out)
        with open(os.path.join(self.out, 'notes.txt'), 'w', encoding='utf-8') as f:
            f.write('keep')
        with self.assertRaisesRegex(SiteError, 'holds other files than a site build'):
            self.build(FILLED)
        self.assertTrue(os.path.isfile(os.path.join(self.out, 'notes.txt')))

    def test_refuses_to_replace_a_folder_with_other_files_further_down(self):
        for path in ('de/notes.txt', 'en/privacy/notes.txt', 'de/privacy/style.css', 'en/a/b/index.html'):
            with self.subTest(path=path):
                shutil.rmtree(self.out, ignore_errors=True)
                self.build(FILLED)
                other = os.path.join(self.out, *path.split('/'))
                os.makedirs(os.path.dirname(other), exist_ok=True)
                with open(other, 'w', encoding='utf-8') as f:
                    f.write('keep')
                with self.assertRaisesRegex(SiteError, 'holds other files than a site build'):
                    self.build(FILLED)
                self.assertTrue(os.path.isfile(other))

    def test_replaces_an_earlier_build(self):
        self.build(FILLED)
        stale = os.path.join(self.out, 'en', 'old', 'index.html')
        os.makedirs(os.path.dirname(stale))
        with open(stale, 'w', encoding='utf-8') as f:
            f.write('old')
        self.build(FILLED)
        self.assertFalse(os.path.exists(stale))

    def test_check_only_keeps_nothing(self):
        self.write_json('site.json', FILLED)
        self.assertEqual(build_site.run(self.source, self.out, False, check_only=True), [])
        self.assertFalse(os.path.exists(self.out))


class CheckTest(SiteTestCase):
    def setUp(self):
        super().setUp()
        self.build(FILLED)
        self.assertEqual(build_site.check(self.out, preview=False), [])

    def change(self, path, old, new):
        full = os.path.join(self.out, path)
        with open(full, encoding='utf-8') as f:
            text = f.read()
        self.assertIn(old, text)
        with open(full, 'w', encoding='utf-8') as f:
            f.write(text.replace(old, new, 1))

    def assertProblem(self, expected):
        problems = build_site.check(self.out, preview=False)
        self.assertTrue(any(expected in problem for problem in problems), problems)

    def test_a_missing_page(self):
        os.remove(os.path.join(self.out, 'de', 'support', 'index.html'))
        self.assertProblem('de/support/index.html is missing')

    def test_a_broken_link(self):
        self.change('en/support/index.html', 'href="../privacy/"', 'href="../privacy-policy/"')
        self.assertProblem('en/support/index.html: link ../privacy-policy/ leads nowhere')

    def test_a_folder_link_without_slash(self):
        self.change('en/support/index.html', 'href="../privacy/"', 'href="../privacy"')
        self.assertProblem('(a folder needs a trailing slash)')

    def test_a_missing_anchor(self):
        self.change('en/index.html', 'href="privacy/"', 'href="privacy/#nowhere"')
        self.assertProblem('names an anchor that en/privacy/index.html lacks')

    def test_links_that_leave_or_start_at_the_root(self):
        self.change('en/index.html', 'href="privacy/"', 'href="/en/privacy/"')
        self.assertProblem('starts at the domain root')
        self.change('en/index.html', 'href="support/"', 'href="../../../x/"')
        self.assertProblem('leaves the site')
        self.change('en/index.html', 'href="https://vikunja.io/"', 'href="http://vikunja.io/"')
        self.assertProblem('link http://vikunja.io/ is neither relative, https nor mailto')

    def test_nothing_from_other_servers(self):
        self.change('de/index.html', '</head>', '<link rel="stylesheet" href="https://fonts.example/a.css">\n</head>')
        self.assertProblem('<link href="https://fonts.example/a.css">: the pages load nothing but style.css')
        self.change('de/legal/index.html', '</main>', '<img src="https://pixel.example/p.gif" alt=""></main>')
        self.assertProblem('<img src="https://pixel.example/p.gif">')
        self.change('en/legal/index.html', '</main>', '<script src="x.js"></script></main>')
        self.assertProblem('<script> is not allowed')
        with open(os.path.join(self.out, 'style.css'), 'a', encoding='utf-8') as f:
            f.write('@import url("https://fonts.example/a.css");\n')
        self.assertProblem('style.css: loads a resource')

    def test_a_wrong_stylesheet_depth(self):
        self.change('en/privacy/index.html', 'href="../../style.css"', 'href="../style.css"')
        self.assertProblem('<link href="../style.css">')

    def test_language_and_counterpart(self):
        self.change('de/support/index.html', '<html lang="de">', '<html lang="en">')
        self.assertProblem('de/support/index.html: <html lang="en">, expected "de"')
        self.change('en/support/index.html', 'href="../../de/support/" hreflang="de"', 'href="../../de/" hreflang="de"')
        self.assertProblem('en/support/index.html: no link with hreflang="de" to de/support/index.html')

    def test_privacy_and_legal_notice_linked_from_every_page(self):
        self.change('de/support/index.html', '<li><a href="../legal/">Impressum</a></li>', '')
        self.assertProblem('de/support/index.html: no link to de/legal/')

    def test_headings_titles_and_ids(self):
        self.change('en/legal/index.html', '<h2 id="contact">Contact</h2>', '<h1 id="contact">Contact</h1>')
        self.assertProblem('2 <h1> headings')
        self.change('en/support/index.html', '<title>Support · Rurana</title>', '<title></title>')
        self.assertProblem('en/support/index.html: no <title>')
        self.change('de/index.html', 'id="data"', 'id="get"')
        self.assertProblem('de/index.html: an id appears twice')

    def test_placeholders_only_in_a_preview(self):
        self.change('en/legal/index.html', 'Example Name', '<mark class="placeholder">[site.json: legal_name]</mark>')
        self.assertProblem('en/legal/index.html: 1 placeholder(s) for missing values')
        self.assertEqual(build_site.check(self.out, preview=True), [])


class CommandLineTest(SiteTestCase):
    def main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(build_site, 'SOURCE', self.source), contextlib.redirect_stdout(out), \
                contextlib.redirect_stderr(err):
            code = build_site.main(list(args))
        return code, out.getvalue(), err.getvalue()

    def test_without_values_refused_and_previewed(self):
        self.write_json('site.json', EMPTY)
        out = self.out
        code, _, err = self.main('--out', out)
        self.assertEqual(code, 1)
        self.assertTrue(err.startswith('error: site/site.json has no value yet for: site_url, '), err)
        self.assertFalse(os.path.exists(out))
        code, _, err = self.main('--check')
        self.assertEqual(code, 1)
        self.assertIn('no value yet', err)
        code, printed, _ = self.main('--check', '--preview')
        self.assertEqual(code, 0)
        self.assertIn('checked; placeholders for site_url, contact_email, legal_name, address_lines, country.',
                      printed)
        code, printed, _ = self.main('--preview', '--out', out)
        self.assertEqual(code, 0)
        self.assertIn('10 pages in en and de built into', printed)
        self.assertTrue(os.path.isfile(os.path.join(out, 'de', 'delete-account', 'index.html')))

    def test_filled_values(self):
        self.write_json('site.json', FILLED)
        self.assertEqual(self.main('--check')[0], 0)
        self.assertFalse(os.path.exists(self.out))
        code, printed, _ = self.main('--out', self.out)
        self.assertEqual(code, 0)
        self.assertNotIn('placeholders', printed)
        self.assertTrue(os.path.isfile(os.path.join(self.out, 'en', 'legal', 'index.html')))

    def test_check_takes_no_out(self):
        with self.assertRaises(SystemExit) as raised:
            self.main('--check', '--out', self.tmp)
        self.assertEqual(raised.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
