import contextlib
import importlib.util
import io
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

URLS = {
    'support_url.txt': 'https://vikunja.io/help/mobile',
    'privacy_url.txt': 'https://vikunja.io/privacy/',
    'marketing_url.txt': 'https://vikunja.io/help/mobile',
}


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

    def __init__(self):
        self.root = tempfile.mkdtemp()
        for locale in check_store_metadata.LOCALES:
            android = f'fastlane/metadata/android/{locale}'
            self.write(f'{android}/title.txt', 'Vikunja\n')
            self.write(f'{android}/short_description.txt', 'Tasks offline, with reminders\n')
            self.write(f'{android}/full_description.txt', 'Vikunja is a task manager.\n\nThis is its app.\n')
            self.write(f'{android}/changelogs/.gitkeep', '')
            ios = f'fastlane/metadata/{locale}'
            self.write(f'{ios}/name.txt', 'Vikunja\n')
            self.write(f'{ios}/subtitle.txt', 'Tasks on your own server\n')
            self.write(f'{ios}/description.txt', 'The app for your Vikunja server.\n')
            self.write(f'{ios}/keywords.txt', 'kanban,offline,reminders\n')
            self.write(f'{ios}/promotional_text.txt', 'Your tasks, offline.\n')
            self.write(f'{ios}/release_notes.txt', '')
            for name, url in URLS.items():
                self.write(f'{ios}/{name}', url + '\n')
        self.write('fastlane/metadata/copyright.txt', '2026 Vikunja and contributors\n')
        self.write('fastlane/metadata/primary_category.txt', 'PRODUCTIVITY\n')
        self.write('fastlane/metadata/review_information/notes.txt', 'Tap "Try the public demo".\n')
        self.write('fastlane/metadata/review_information/demo_user.txt', 'demo\n')
        self.write('fastlane/metadata/review_information/demo_password.txt', 'demo\n')
        self.write('fastlane/metadata/review_information/email_address.txt', 'hello@vikunja.io\n')

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
        return self.tree.check(strict)

    def assertError(self, fragment, strict=False):
        errors = self.errors(strict)
        self.assertTrue(any(fragment in error for error in errors), errors)

    def test_the_repository_s_listing_passes(self):
        self.assertEqual(Checker(ROOT, strict=False).run(), [])

    def test_a_complete_listing_passes(self):
        self.assertEqual(self.errors(), [])

    def test_strict_fails_only_on_missing_screenshots(self):
        errors = self.errors(strict=True)
        self.assertEqual(len(errors), 8, errors)
        self.assertIn('fastlane/metadata/android/de-DE/images: 0 phone screenshots, Play needs at least 2', errors)
        self.assertIn('fastlane/screenshots/en-US: no iPad 13" screenshots', errors)
        self.tree.screenshots()
        self.assertEqual(self.errors(strict=True), [])

    def test_limits(self):
        cases = {
            'fastlane/metadata/android/en-US/title.txt': 'V' * 31,
            'fastlane/metadata/android/en-US/short_description.txt': 'a' * 81,
            'fastlane/metadata/android/de-DE/full_description.txt': 'a' * 4001,
            'fastlane/metadata/de-DE/subtitle.txt': 'a' * 31,
            'fastlane/metadata/en-US/promotional_text.txt': 'a' * 171,
            'fastlane/metadata/en-US/description.txt': 'a' * 4001,
        }
        for name, value in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(name, value + '\n')
                errors = [error for error in tree.check() if not error.endswith('must be "Vikunja"')]
                self.assertEqual(len(errors), 1, errors)
                self.assertIn(', the limit is ', errors[0])

    def test_keywords_and_notes_count_bytes(self):
        self.tree.write('fastlane/metadata/de-DE/keywords.txt', 'kanban,' + 'ä' * 47 + '\n')
        self.assertError('de-DE/keywords.txt: 101 bytes, the limit is 100')
        self.tree.write('fastlane/metadata/review_information/notes.txt', 'é' * 2001 + '\n')
        self.assertError('notes.txt: 4002 bytes, the limit is 4000')

    def test_no_other_brand_in_the_name_fields(self):
        for name in ('android/en-US/title.txt', 'en-US/name.txt', 'de-DE/subtitle.txt', 'en-US/keywords.txt'):
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(f'fastlane/metadata/{name}', 'Tasks like Todoist\n' if 'keywords' not in name
                           else 'tasks,todoist\n')
                self.assertIn('names another product or company: ', ' '.join(tree.check()))

    def test_the_title_and_the_name_are_vikunja(self):
        for name in ('android/en-US/title.txt', 'android/de-DE/title.txt', 'en-US/name.txt', 'de-DE/name.txt'):
            for value in ('Tasks', 'vikunja', 'Vikunja Tasks'):
                with self.subTest(name=name, value=value):
                    tree = Tree()
                    self.addCleanup(tree.remove)
                    tree.write(f'fastlane/metadata/{name}', value + '\n')
                    self.assertEqual(tree.check(), [f'fastlane/metadata/{name}: must be "Vikunja"'])

    def test_vikunja_is_indexed_as_the_name_and_fine_in_the_subtitle(self):
        self.tree.write('fastlane/metadata/en-US/keywords.txt', 'tasks,Vikunja tasks\n')
        self.assertEqual(self.errors(), ['fastlane/metadata/en-US/keywords.txt: the app name is indexed already'])
        self.tree.write('fastlane/metadata/en-US/keywords.txt', 'kanban,offline,reminders\n')
        self.tree.write('fastlane/metadata/de-DE/subtitle.txt', 'Für deinen Vikunja-Server\n')
        self.assertEqual(self.errors(), [])

    def test_vikunja_is_fine_in_descriptions(self):
        self.tree.write('fastlane/metadata/android/en-US/short_description.txt',
                        'The app for your Vikunja server\n')
        self.assertEqual(self.errors(), [])

    def test_no_text_calls_the_app_unofficial(self):
        cases = {
            'android/en-US/full_description.txt': 'An unofficial app for Vikunja.',
            'android/en-US/short_description.txt': 'Unofficial app for Vikunja servers',
            'android/de-DE/full_description.txt': 'Eine inoffizielle App für Vikunja.',
            'android/de-DE/short_description.txt': 'Inoffizielle App für Vikunja-Server',
            'en-US/description.txt': 'It is not affiliated with or endorsed by the Vikunja project.',
            'de-DE/description.txt': 'Sie gehört nicht zum Vikunja-Projekt.',
            'en-US/subtitle.txt': 'The unofficial task app',
            'de-DE/subtitle.txt': 'Inoffiziell, offline',
            'en-US/promotional_text.txt': 'Your tasks, offline. Unofficial.',
            'de-DE/promotional_text.txt': 'Die inoffizielle App.',
            'review_information/notes.txt': 'An unofficial client for Vikunja.',
        }
        for name, value in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(f'fastlane/metadata/{name}', value + '\n')
                self.assertEqual(tree.check(), [f'fastlane/metadata/{name}: calls the app unofficial (D83)'])

    def test_no_text_names_the_agpl(self):
        cases = {
            'android/en-US/full_description.txt': 'The app is free software under the GNU Affero General Public License.',
            'de-DE/description.txt': 'Die App steht unter der AGPL-3.0-or-later.',
            'review_information/notes.txt': 'This is its open-source (AGPL-3.0) app.',
        }
        for name, value in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(f'fastlane/metadata/{name}', value + '\n')
                self.assertEqual(tree.check(), [f'fastlane/metadata/{name}: names the AGPL, but the app is under the '
                                                'MIT License (D87)'])

    def test_the_english_texts_use_us_spelling_and_the_glossary_s_terms(self):
        cases = {
            'android/en-US/full_description.txt': ('Projects with subprojects and favourites.', 'favourit'),
            'android/en-US/short_description.txt': ("Your organisation's tasks", 'organis'),
            'en-US/description.txt': ('Due dates, priority and colour.', 'colour'),
            'en-US/promotional_text.txt': ('Tick off tasks on the Home Screen.', 'Tick'),
            'en-US/subtitle.txt': ('Tasks you tick off', 'tick'),
            'en-US/keywords.txt': ('kanban,winter tyres', 'tyre'),
            'review_information/notes.txt': ('Turn on Airplane Mode, tick off or edit a task.', 'tick'),
        }
        for name, (value, found) in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(f'fastlane/metadata/{name}', value + '\n')
                self.assertEqual(tree.check(),
                                 [f"fastlane/metadata/{name}: not the US spelling or the glossary's term: {found}"])

    def test_the_german_texts_keep_their_spelling(self):
        self.tree.write('fastlane/metadata/android/de-DE/full_description.txt',
                        'Der Server deiner Organisation, mit Farben und Favoriten.\n')
        self.tree.write('fastlane/metadata/android/en-US/full_description.txt',
                        "Your organization's server, with colors and favorites; check tasks off.\n")
        self.assertEqual(self.errors(), [])

    def test_claims_emoji_and_the_other_platform(self):
        cases = {
            'fastlane/metadata/android/en-US/short_description.txt': ('The best task app', 'ranking, price'),
            'fastlane/metadata/de-DE/promotional_text.txt': ('Kostenlos und offline', 'ranking, price'),
            'fastlane/metadata/en-US/subtitle.txt': ('Tasks \u2705', 'emoji'),
            'fastlane/metadata/en-US/description.txt': ('The app for your server. Also on Android.', 'other platform'),
            'fastlane/metadata/android/de-DE/full_description.txt': ('Die App für deinen Server. Auch fürs iPhone.',
                                                                     'other platform'),
        }
        for name, (value, message) in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(name, value + '\n')
                self.assertIn(message, ' '.join(tree.check()))

    def test_layout(self):
        os.remove(os.path.join(self.tree.root, 'fastlane/metadata/de-DE/name.txt'))
        self.tree.write('fastlane/metadata/en-US/subtitles.txt', 'x\n')
        self.tree.write('fastlane/metadata/android/en-US/changelogs/latest.txt', 'x\n')
        errors = self.errors()
        self.assertIn('fastlane/metadata/de-DE/name.txt: missing', errors)
        self.assertIn('fastlane/metadata/en-US/subtitles.txt: not a file of this layout', errors)
        self.assertIn('fastlane/metadata/android/en-US/changelogs/latest.txt: a changelog is <version code>.txt',
                      errors)

    def test_changelogs(self):
        changelogs = 'fastlane/metadata/android/{}/changelogs/{}.txt'
        for locale in check_store_metadata.LOCALES:
            self.tree.write(changelogs.format(locale, 1000001), 'This is the new app.\n\nIt may ask you to sign in.\n')
        self.tree.write(changelogs.format('en-US', 1000002), 'Fixes.\n')
        self.tree.write(changelogs.format('de-DE', 1000003), 'Fehler behoben.\n')
        self.tree.write(changelogs.format('en-US', 'default'), 'Fixes.\n')
        self.assertEqual(sorted(self.errors()), [
            f"{changelogs.format('de-DE', 1000002)}: missing, but another listing language has this changelog",
            f"{changelogs.format('en-US', 1000003)}: missing, but another listing language has this changelog",
            f"{changelogs.format('en-US', 'default')}: a changelog is <version code>.txt",
        ])

    def test_changelogs_follow_the_text_rules(self):
        changelogs = 'fastlane/metadata/android/{}/changelogs/1000001.txt'
        for en, de, (locale, message) in [
            ('Pick a colour.', 'Wähle eine Farbe.', ('en-US', "not the US spelling or the glossary's term: colour")),
            ('Fixes.', 'Jetzt auch fürs iPhone.', ('de-DE', 'names the other platform: iPhone')),
            ('An unofficial app.', 'Eine App.', ('en-US', 'calls the app unofficial (D83)')),
            ('Fixes. ', 'Fehler behoben.', ('en-US', 'leading or trailing whitespace')),
            ('', 'Fehler behoben.', ('en-US', 'empty')),
            ('a' * 501, 'Fehler behoben.', ('en-US', '501 characters, the limit is 500')),
        ]:
            with self.subTest(message=message):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(changelogs.format('en-US'), en + '\n' if en else '')
                tree.write(changelogs.format('de-DE'), de + '\n')
                self.assertEqual(tree.check(), [f'{changelogs.format(locale)}: {message}'])

    def test_values(self):
        self.tree.write('fastlane/metadata/android/en-US/title.txt', 'Vikunja\nTasks\n')
        self.tree.write('fastlane/metadata/de-DE/name.txt', ' Vikunja\n')
        self.tree.write('fastlane/metadata/en-US/promotional_text.txt', '')
        self.tree.write('fastlane/metadata/primary_category.txt', 'Productivity\n')
        self.tree.write('fastlane/metadata/android/de-DE/changelogs/1000001.txt', 'x' * 501 + '\n')
        errors = self.errors()
        self.assertIn('fastlane/metadata/android/en-US/title.txt: must be one line', errors)
        self.assertIn('fastlane/metadata/de-DE/name.txt: leading or trailing whitespace', errors)
        self.assertIn('fastlane/metadata/en-US/promotional_text.txt: empty', errors)
        self.assertIn('fastlane/metadata/primary_category.txt: not an App Store category id: Productivity', errors)
        self.assertIn('fastlane/metadata/android/de-DE/changelogs/1000001.txt: 501 characters, the limit is 500',
                      errors)

    def test_keywords(self):
        self.tree.write('fastlane/metadata/en-US/keywords.txt', 'kanban, offline,to,vikunja tasks,Kanban\n')
        errors = ' '.join(self.errors())
        for message in ('spaces around commas', 'keyword too short: "to"', 'the app name is indexed',
                        'repeated keyword'):
            self.assertIn(message, errors)

    def test_the_urls_are_the_app_s_pages_on_vikunja_io_in_both_languages(self):
        on_the_website = 'must be an https URL on vikunja.io'
        for name, value, message in [
            ('en-US/privacy_url.txt', 'http://vikunja.io/privacy/', on_the_website),
            ('en-US/support_url.txt', 'https://example.org/help/mobile', on_the_website),
            ('de-DE/support_url.txt', 'https://vikunja.io.example/help/mobile', on_the_website),
            ('de-DE/privacy_url.txt', 'https://try.vikunja.io/privacy/', on_the_website),
            ('en-US/privacy_url.txt', 'https://vikunja.io/privacy/#mobile-app', 'must be https://vikunja.io/privacy/'),
            ('de-DE/privacy_url.txt', 'https://vikunja.io/de/privacy/', 'must be https://vikunja.io/privacy/'),
            ('de-DE/support_url.txt', 'https://vikunja.io/support/', 'must be https://vikunja.io/help/mobile'),
            ('de-DE/marketing_url.txt', 'https://vikunja.io/', 'must be https://vikunja.io/help/mobile'),
            ('en-US/marketing_url.txt', '', 'empty'),
        ]:
            with self.subTest(name=name, value=value):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(f'fastlane/metadata/{name}', value + '\n' if value else '')
                self.assertEqual(tree.check(), [f'fastlane/metadata/{name}: {message}'])

    def test_the_contact_and_the_copyright(self):
        cases = {
            'review_information/email_address.txt': ('app@example.org', 'must be "hello@vikunja.io"'),
            'copyright.txt': ('2026 Vikunja', 'must be "2026 Vikunja and contributors"'),
        }
        for name, (value, message) in cases.items():
            with self.subTest(name=name):
                tree = Tree()
                self.addCleanup(tree.remove)
                tree.write(f'fastlane/metadata/{name}', value + '\n')
                self.assertEqual(tree.check(), [f'fastlane/metadata/{name}: {message}'])
                tree.write(f'fastlane/metadata/{name}', '')
                self.assertEqual(tree.check(), [f'fastlane/metadata/{name}: empty'])


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
        shots = 'fastlane/metadata/android/en-US/images/phoneScreenshots'
        self.tree.write(f'{shots}/01.png', png(1080, 1920, colour_type=6))
        self.tree.write(f'{shots}/02.png', png(1080, 2400))
        self.tree.write(f'{shots}/03.jpg', jpeg(1080, 1920))
        self.tree.write(f'{shots}/04.webp', b'RIFF')
        self.tree.write('fastlane/metadata/android/en-US/images/tenInchScreenshots/01.png', png(1024, 600))
        self.tree.write('fastlane/metadata/android/en-US/images/featureGraphic.png', png(1024, 500, colour_type=6))
        self.tree.write('fastlane/metadata/android/en-US/images/icon.png', png(512, 512, colour_type=6))
        errors = self.tree.check()
        self.assertEqual(sorted(errors), sorted([
            f'{shots}/01.png: has an alpha channel',
            f'{shots}/02.png: 1080x2400: sides 320-3840 px, the long side at most twice the short',
            f'{shots}/04.webp: not a .png or .jpg file',
            'fastlane/metadata/android/en-US/images/tenInchScreenshots/01.png: 1024x600: sides 1080-7680 px, the long '
            'side at most twice the short',
            'fastlane/metadata/android/en-US/images/featureGraphic.png: must be 1024x500 without alpha',
        ]))

    def test_apple_rules(self):
        self.tree.write('fastlane/screenshots/en-US/01.png', png(2868, 1320))
        self.tree.write('fastlane/screenshots/en-US/02.png', png(1080, 1920))
        self.tree.write('fastlane/screenshots/en-US/03.png', png(2064, 2752, colour_type=6))
        self.tree.write('fastlane/screenshots/fr-FR/01.png', png(1320, 2868))
        errors = self.tree.check()
        self.assertEqual(sorted(errors), sorted([
            'fastlane/screenshots/en-US/02.png: 1080x1920 is none of the App Store sizes used here',
            'fastlane/screenshots/en-US/03.png: has an alpha channel',
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
        self.assertIn('store metadata (normal): OK', out)
        status, _, err = self.run_main('--root', tree.root, '--strict')
        self.assertEqual(status, 1)
        self.assertIn('store metadata (strict): 8 errors', err)
        tree.screenshots()
        status, out, _ = self.run_main('--root', tree.root, '--strict')
        self.assertEqual(status, 0)
        self.assertIn('store metadata (strict): OK', out)
        tree.write('fastlane/metadata/review_information/email_address.txt', 'app@example.org\n')
        status, _, err = self.run_main('--root', tree.root)
        self.assertEqual(status, 1)
        self.assertIn('error: fastlane/metadata/review_information/email_address.txt: must be "hello@vikunja.io"', err)


if __name__ == '__main__':
    unittest.main()
