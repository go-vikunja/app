import contextlib
import importlib.util
import io
import json
import os
import shutil
import struct
import tempfile
import unittest
import zlib

TOOL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(TOOL)
_spec = importlib.util.spec_from_file_location('check_store_metadata', os.path.join(TOOL, 'check_store_metadata.py'))
check_store_metadata = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check_store_metadata)
Checker = check_store_metadata.Checker

UNOFFICIAL = check_store_metadata.UNOFFICIAL
SITE = {'site_url': 'https://rurana.example/', 'contact_email': 'hello@rurana.example', 'legal_name': 'Erika Muster',
        'address_lines': ['c/o Service', '12345 Stadt'], 'country': 'Deutschland'}
EMPTY_SITE = {'site_url': '', 'contact_email': '', 'legal_name': '', 'address_lines': [], 'country': ''}


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def png(width, height, colour_type=2, transparency=False):
    header = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, colour_type, 0, 0, 0))
    extra = chunk(b'tRNS', b'\x00\x00\x00\x00\x00\x00') if transparency else b''
    return b'\x89PNG\r\n\x1a\n' + header + extra + chunk(b'IDAT', b'') + chunk(b'IEND', b'')


def jpeg(width, height):
    app0 = b'\xff\xe0' + struct.pack('>H', 16) + b'JFIF\x00' + b'\x00' * 9
    sof = b'\xff\xc0' + struct.pack('>HBHHB', 17, 8, height, width, 3) + b'\x00' * 9
    return b'\xff\xd8' + app0 + sof + b'\xff\xd9'


class Tree:
    """A complete, valid listing in a temporary repository root."""

    def __init__(self, site=EMPTY_SITE):
        self.root = tempfile.mkdtemp()
        self.write('site/site.json', json.dumps(site))
        for locale, lang in check_store_metadata.LOCALES.items():
            android = f'fastlane/metadata/android/{locale}'
            self.write(f'{android}/title.txt', 'Rurana\n')
            self.write(f'{android}/short_description.txt', 'Tasks offline, with reminders\n')
            self.write(f'{android}/full_description.txt', f'Rurana is an app.\n\n{UNOFFICIAL[lang]}\n')
            self.write(f'{android}/changelogs/.gitkeep', '')
            ios = f'fastlane/metadata/{locale}'
            self.write(f'{ios}/name.txt', 'Rurana\n')
            self.write(f'{ios}/subtitle.txt', 'Tasks on your own server\n')
            self.write(f'{ios}/description.txt', f'{UNOFFICIAL[lang]}\n')
            self.write(f'{ios}/keywords.txt', 'kanban,offline,reminders\n')
            self.write(f'{ios}/promotional_text.txt', 'Your tasks, offline.\n')
            for name in ('release_notes.txt', 'support_url.txt', 'privacy_url.txt', 'marketing_url.txt'):
                self.write(f'{ios}/{name}', '')
        self.write('fastlane/metadata/copyright.txt', '')
        self.write('fastlane/metadata/primary_category.txt', 'PRODUCTIVITY\n')
        self.write('fastlane/metadata/review_information/notes.txt', 'Tap "Try the public demo".\n')
        self.write('fastlane/metadata/review_information/demo_user.txt', 'demo\n')
        self.write('fastlane/metadata/review_information/demo_password.txt', 'demo\n')
        self.write('fastlane/metadata/review_information/email_address.txt', '')

    def write(self, name, content):
        path = os.path.join(self.root, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(content if isinstance(content, bytes) else content.encode('utf-8'))

    def screenshots(self):
        for locale in check_store_metadata.LOCALES:
            for number in (1, 2):
                self.write(f'fastlane/metadata/android/{locale}/images/phoneScreenshots/0{number}-x.png',
                           png(1080, 1920))
            self.write(f'fastlane/screenshots/{locale}/01-x-1320x2868.png', png(1320, 2868))
            self.write(f'fastlane/screenshots/{locale}/01-x-1206x2622.png', png(1206, 2622))
            self.write(f'fastlane/screenshots/{locale}/01-x-2064x2752.png', png(2064, 2752))

    def check(self, strict=False):
        return Checker(self.root, strict).run()

    def remove(self):
        shutil.rmtree(self.root)


class CheckerTest(unittest.TestCase):
    def setUp(self):
        self.tree = Tree()
        self.addCleanup(self.tree.remove)

    def errors(self, strict=False):
        return self.tree.check(strict)[0]

    def assertError(self, fragment, strict=False):
        errors = self.errors(strict)
        self.assertTrue(any(fragment in error for error in errors), errors)

    def test_the_repository_s_listing_passes(self):
        errors, _ = Checker(ROOT, strict=False).run()
        self.assertEqual(errors, [])

    def test_a_complete_listing_passes_with_notes_for_the_site_values(self):
        errors, notes = self.tree.check()
        self.assertEqual(errors, [])
        self.assertEqual(len(notes), 8)
        self.assertIn('fastlane/metadata/en-GB/privacy_url.txt: empty while site/site.json has no site_url', notes)

    def test_strict_fails_on_empty_site_values_and_missing_screenshots(self):
        errors = self.errors(strict=True)
        self.assertIn('fastlane/metadata/copyright.txt: empty while site/site.json has no legal_name', errors)
        self.assertIn('fastlane/metadata/review_information/email_address.txt: empty while site/site.json has no '
                      'contact_email', errors)
        self.assertIn('fastlane/metadata/android/de-DE/images: 0 phone screenshots, Play needs at least 2', errors)
        self.assertIn('fastlane/screenshots/en-GB: no iPad 13" screenshots', errors)

    def test_limits(self):
        cases = {
            'fastlane/metadata/android/en-GB/title.txt': 'R' * 31,
            'fastlane/metadata/android/en-GB/short_description.txt': 'a' * 81,
            'fastlane/metadata/android/de-DE/full_description.txt': UNOFFICIAL['de'] + 'a' * 4000,
            'fastlane/metadata/de-DE/subtitle.txt': 'a' * 31,
            'fastlane/metadata/en-GB/promotional_text.txt': 'a' * 171,
            'fastlane/metadata/en-GB/description.txt': UNOFFICIAL['en'] + 'a' * 4000,
        }
        for name, value in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(name, value + '\n')
                errors = tree.check()[0]
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(', the limit is ', errors[0])

    def test_keywords_and_notes_count_bytes(self):
        self.tree.write('fastlane/metadata/de-DE/keywords.txt', 'kanban,' + 'ä' * 47 + '\n')
        self.assertError('de-DE/keywords.txt: 101 bytes, the limit is 100')
        self.tree.write('fastlane/metadata/review_information/notes.txt', 'é' * 2001 + '\n')
        self.assertError('notes.txt: 4002 bytes, the limit is 4000')

    def test_no_vikunja_in_the_name_fields(self):
        for name in ('android/en-GB/title.txt', 'en-GB/name.txt', 'de-DE/subtitle.txt', 'en-GB/keywords.txt'):
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(f'fastlane/metadata/{name}', 'Rurana for Vikunja\n' if 'keywords' not in name
                           else 'tasks,vikunja\n')
                self.assertIn('names another product or company: ', ' '.join(tree.check()[0]))

    def test_vikunja_is_fine_in_descriptions(self):
        self.tree.write('fastlane/metadata/android/en-GB/short_description.txt',
                        'Unofficial app for Vikunja servers\n')
        self.assertEqual(self.errors(), [])

    def test_the_unofficial_line_is_required(self):
        self.tree.write('fastlane/metadata/de-DE/description.txt', 'Rurana ist eine App.\n')
        self.assertError('de-DE/description.txt: lacks the line')

    def test_claims_emoji_and_the_other_platform(self):
        cases = {
            'fastlane/metadata/android/en-GB/short_description.txt': ('The best task app', 'ranking, price'),
            'fastlane/metadata/de-DE/promotional_text.txt': ('Kostenlos und offline', 'ranking, price'),
            'fastlane/metadata/en-GB/subtitle.txt': ('Tasks \u2705', 'emoji'),
            'fastlane/metadata/en-GB/description.txt': (UNOFFICIAL['en'] + ' Also on Android.', 'other platform'),
            'fastlane/metadata/android/de-DE/full_description.txt': (UNOFFICIAL['de'] + ' Auch fürs iPhone.',
                                                                     'other platform'),
        }
        for name, (value, message) in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(name, value + '\n')
                self.assertIn(message, ' '.join(tree.check()[0]))

    def test_layout(self):
        os.remove(os.path.join(self.tree.root, 'fastlane/metadata/de-DE/name.txt'))
        self.tree.write('fastlane/metadata/en-GB/subtitles.txt', 'x\n')
        self.tree.write('fastlane/metadata/android/en-GB/changelogs/latest.txt', 'x\n')
        errors = self.errors()
        self.assertIn('fastlane/metadata/de-DE/name.txt: missing', errors)
        self.assertIn('fastlane/metadata/en-GB/subtitles.txt: not a file of this layout', errors)
        self.assertIn('fastlane/metadata/android/en-GB/changelogs/latest.txt: a changelog is <version code>.txt or '
                      'default.txt', errors)

    def test_values(self):
        self.tree.write('fastlane/metadata/android/en-GB/title.txt', 'Rurana\nTasks\n')
        self.tree.write('fastlane/metadata/de-DE/name.txt', ' Rurana\n')
        self.tree.write('fastlane/metadata/en-GB/promotional_text.txt', '')
        self.tree.write('fastlane/metadata/primary_category.txt', 'Productivity\n')
        self.tree.write('fastlane/metadata/android/de-DE/changelogs/1000001.txt', 'x' * 501 + '\n')
        errors = self.errors()
        self.assertIn('fastlane/metadata/android/en-GB/title.txt: must be one line', errors)
        self.assertIn('fastlane/metadata/de-DE/name.txt: leading or trailing whitespace', errors)
        self.assertIn('fastlane/metadata/en-GB/promotional_text.txt: empty', errors)
        self.assertIn('fastlane/metadata/primary_category.txt: not an App Store category id: Productivity', errors)
        self.assertIn('fastlane/metadata/android/de-DE/changelogs/1000001.txt: 501 characters, the limit is 500',
                      errors)

    def test_keywords(self):
        self.tree.write('fastlane/metadata/en-GB/keywords.txt', 'kanban, offline,to,rurana tasks,Kanban\n')
        errors = ' '.join(self.errors())
        for message in ('spaces around commas', 'keyword too short: "to"', 'the app name is indexed',
                        'repeated keyword'):
            self.assertIn(message, errors)

    def test_a_value_set_without_the_site_is_an_error(self):
        self.tree.write('fastlane/metadata/en-GB/support_url.txt', 'https://elsewhere.example/\n')
        self.assertError('en-GB/support_url.txt: set, but site/site.json has no site_url')


class FillTest(unittest.TestCase):
    def setUp(self):
        self.tree = Tree(site=SITE)
        self.addCleanup(self.tree.remove)

    def read(self, name):
        with open(os.path.join(self.tree.root, 'fastlane/metadata', name), encoding='utf-8') as f:
            return f.read()

    def test_fill_writes_the_site_values(self):
        written, console = check_store_metadata.fill(self.tree.root)
        self.assertEqual(self.read('de-DE/privacy_url.txt'), 'https://rurana.example/de/privacy/\n')
        self.assertEqual(self.read('en-GB/support_url.txt'), 'https://rurana.example/en/support/\n')
        self.assertEqual(self.read('en-GB/marketing_url.txt'), 'https://rurana.example/en/\n')
        self.assertEqual(self.read('copyright.txt'), '2026 Erika Muster and the Rurana contributors\n')
        self.assertEqual(self.read('review_information/email_address.txt'), 'hello@rurana.example\n')
        self.assertEqual(len(written), 8)
        self.assertEqual(console['Play account deletion URL'], 'https://rurana.example/en/delete-account/')
        self.assertEqual(console['Play privacy policy'], 'https://rurana.example/en/privacy/')
        self.assertEqual(self.tree.check(), ([], []))

    def test_strict_passes_once_filled_and_with_screenshots(self):
        check_store_metadata.fill(self.tree.root)
        self.tree.screenshots()
        self.assertEqual(self.tree.check(strict=True), ([], []))

    def test_unfilled_values_are_notes_and_stale_ones_errors(self):
        errors, notes = self.tree.check()
        self.assertEqual(errors, [])
        self.assertIn('fastlane/metadata/en-GB/support_url.txt: differs from site/site.json, run --fill: "" instead '
                      'of "https://rurana.example/en/support/"', notes)
        check_store_metadata.fill(self.tree.root)
        self.tree.write('site/site.json', json.dumps(dict(SITE, site_url='https://new.example')))
        errors, _ = self.tree.check()
        self.assertEqual(len(errors), 6, errors)

    def test_fill_without_values_leaves_the_files_empty(self):
        self.tree.write('site/site.json', json.dumps(EMPTY_SITE))
        check_store_metadata.fill(self.tree.root)
        self.assertEqual(self.read('en-GB/privacy_url.txt'), '')
        self.assertEqual(self.read('copyright.txt'), '')

    def test_bad_site_values_are_refused(self):
        for key, value in [('site_url', 'http://rurana.example'), ('site_url', 'https://rurana.example/?a=1'),
                           ('site_url', 'rurana.example'), ('contact_email', 'not an address'),
                           ('address_lines', 'c/o Service')]:
            with self.subTest(key=key, value=value):
                self.tree.write('site/site.json', json.dumps(dict(SITE, **{key: value})))
                with self.assertRaises(check_store_metadata.MetadataError):
                    check_store_metadata.fill(self.tree.root)
        self.tree.write('site/site.json', '[]')
        with self.assertRaisesRegex(check_store_metadata.MetadataError, 'not an object'):
            check_store_metadata.fill(self.tree.root)
        os.remove(os.path.join(self.tree.root, 'site/site.json'))
        with self.assertRaisesRegex(check_store_metadata.MetadataError, 'site/site.json'):
            check_store_metadata.fill(self.tree.root)


class ScreenshotTest(unittest.TestCase):
    def setUp(self):
        self.tree = Tree()
        self.addCleanup(self.tree.remove)

    def test_images_are_read_from_their_headers(self):
        path = os.path.join(self.tree.root, 'shot')
        for content, expected in [(png(10, 20), (10, 20, False)), (png(10, 20, colour_type=6), (10, 20, True)),
                                  (png(10, 20, transparency=True), (10, 20, True)), (jpeg(30, 40), (30, 40, False))]:
            with open(path, 'wb') as f:
                f.write(content)
            self.assertEqual(check_store_metadata.png_or_jpeg_size(path), expected)
        for broken in (png(10, 20)[:20], jpeg(30, 40)[:24], b'GIF89a'):
            with open(path, 'wb') as f:
                f.write(broken)
            with self.assertRaisesRegex(check_store_metadata.MetadataError, 'not a PNG or JPEG image'):
                check_store_metadata.png_or_jpeg_size(path)

    def test_play_rules(self):
        shots = 'fastlane/metadata/android/en-GB/images/phoneScreenshots'
        self.tree.write(f'{shots}/01.png', png(1080, 1920, colour_type=6))
        self.tree.write(f'{shots}/02.png', png(1080, 2400))
        self.tree.write(f'{shots}/03.jpg', jpeg(1080, 1920))
        self.tree.write(f'{shots}/04.webp', b'RIFF')
        self.tree.write('fastlane/metadata/android/en-GB/images/tenInchScreenshots/01.png', png(1024, 600))
        self.tree.write('fastlane/metadata/android/en-GB/images/featureGraphic.png', png(1024, 500, colour_type=6))
        self.tree.write('fastlane/metadata/android/en-GB/images/icon.png', png(512, 512, colour_type=6))
        errors = self.tree.check()[0]
        self.assertEqual(sorted(errors), sorted([
            f'{shots}/01.png: has an alpha channel',
            f'{shots}/02.png: 1080x2400: sides 320-3840 px, the long side at most twice the short',
            f'{shots}/04.webp: not a .png or .jpg file',
            'fastlane/metadata/android/en-GB/images/tenInchScreenshots/01.png: 1024x600: sides 1080-7680 px, the long '
            'side at most twice the short',
            'fastlane/metadata/android/en-GB/images/featureGraphic.png: must be 1024x500 without alpha',
        ]))

    def test_apple_rules(self):
        self.tree.write('fastlane/screenshots/en-GB/01.png', png(2868, 1320))
        self.tree.write('fastlane/screenshots/en-GB/02.png', png(1080, 1920))
        self.tree.write('fastlane/screenshots/en-GB/03.png', png(2064, 2752, colour_type=6))
        self.tree.write('fastlane/screenshots/fr-FR/01.png', png(1320, 2868))
        errors = self.tree.check()[0]
        self.assertEqual(sorted(errors), sorted([
            'fastlane/screenshots/en-GB/02.png: 1080x1920 is none of the App Store sizes used here',
            'fastlane/screenshots/en-GB/03.png: has an alpha channel',
            'fastlane/screenshots/fr-FR: not a listing language',
        ]))


class MainTest(unittest.TestCase):
    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = check_store_metadata.main(list(argv))
        return status, out.getvalue(), err.getvalue()

    def test_exit_codes(self):
        tree = Tree()
        self.addCleanup(tree.remove)
        status, out, _ = self.run_main('--root', tree.root)
        self.assertEqual(status, 0)
        self.assertIn('store metadata (normal): OK, 8 notes', out)
        status, _, err = self.run_main('--root', tree.root, '--strict')
        self.assertEqual(status, 1)
        self.assertIn('store metadata (strict): 16 errors', err)

    def test_fill(self):
        tree = Tree(site=SITE)
        self.addCleanup(tree.remove)
        tree.screenshots()
        status, out, _ = self.run_main('--root', tree.root, '--fill', '--strict')
        self.assertEqual(status, 0)
        self.assertIn('wrote fastlane/metadata/copyright.txt: 2026 Erika Muster and the Rurana contributors', out)
        self.assertIn('Play account deletion URL (enter by hand): https://rurana.example/en/delete-account/', out)
        self.assertIn('store metadata (strict): OK', out)
        tree.write('site/site.json', '{')
        status, _, err = self.run_main('--root', tree.root, '--fill')
        self.assertEqual(status, 1)
        self.assertIn('error: site/site.json: ', err)


if __name__ == '__main__':
    unittest.main()
