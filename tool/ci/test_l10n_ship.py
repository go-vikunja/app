"""Tests tool/l10n_ship.py, which the workflow "Crowdin" runs on the
translations it commits (decision log: Languages)."""
import contextlib
import importlib.util
import io
import json
import os
import re
import shutil
import tempfile
import unittest

TOOL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(TOOL)
_spec = importlib.util.spec_from_file_location('l10n_ship', os.path.join(TOOL, 'l10n_ship.py'))
l10n_ship = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(l10n_ship)

FILES = [
    l10n_ship.SHIPPED_DART, l10n_ship.ANDROID_CONFIG, *l10n_ship.IOS_PLISTS, l10n_ship.PREVIOUS_APP,
    l10n_ship.PICKER, l10n_ship.L10N, l10n_ship.STORE_TEST,
    *(path for *_, paths in l10n_ship.DESCRIPTIONS.values() for path in paths),
]
ARB_DIR = 'app/lib/l10n/arb'
KEYS = [f'key{n}' for n in range(10)]


def write(root, path, text):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(text)


def read(root, path):
    with open(os.path.join(root, path), encoding='utf-8') as f:
        return f.read()


class L10nShipTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        for path in FILES:
            if os.path.isfile(os.path.join(ROOT, path)):
                write(self.root, path, read(ROOT, path))
        self.arb('en', 10)
        self.arb('de', 10)

    def arb(self, locale, translated):
        write(self.root, f'{ARB_DIR}/app_{locale}.arb',
              json.dumps({'@@locale': locale, **{key: 'text' for key in KEYS[:translated]}}))

    def ship(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = l10n_ship.main(['--root', self.root, *argv])
        return code, out.getvalue(), err.getvalue()

    def snapshot(self):
        return {path: read(self.root, path) for path in FILES if os.path.isfile(os.path.join(self.root, path))}

    def test_nothing_to_ship_changes_nothing(self):
        before = self.snapshot()
        self.arb('fr', 4)
        self.assertEqual(self.ship(), (0, '', ''))
        self.assertEqual(self.snapshot(), before)

    def test_ships_a_language_at_half_into_every_list(self):
        self.arb('fr', 5)
        code, out, _ = self.ship()
        self.assertEqual(code, 0)
        self.assertIn('Ships: fr (French), 50.0 %', out)
        files = self.snapshot()
        self.assertIn("Locale('fr')", files[l10n_ship.SHIPPED_DART])
        self.assertIn('android:name="fr"', files[l10n_ship.ANDROID_CONFIG])
        self.assertIn('<string>fr</string>', files[l10n_ship.IOS_PLISTS[0]])
        self.assertIn('setOf("en", "de", "fr")', files[l10n_ship.PREVIOUS_APP])
        picker = files[l10n_ship.PICKER]
        self.assertIn("'fr': _FrLocalizations.new,", picker)
        self.assertIn('extends MaterialLocalizationFr', picker)
        l10n = files[l10n_ship.L10N]
        self.assertIn('AppLocalizationsFr() => AppLocalizationsFr(locale.toString()),', l10n)
        self.assertIn("import 'package:vikunja_mobile/l10n/generated/app_localizations_fr.dart';", l10n)
        self.assertLess(l10n.index('app_localizations_en.dart'), l10n.index('app_localizations_fr.dart'))
        self.assertIn("'fr': 'French'", files[l10n_ship.STORE_TEST])
        self.assertIn("'fr': 'Französisch'", files[l10n_ship.STORE_TEST])
        for locale, (label, _, _, paths) in l10n_ship.DESCRIPTIONS.items():
            for path in paths:
                line = re.search(rf'^• {label}: (.*)\.$', files[path], re.MULTILINE).group(1)
                self.assertEqual(len(re.split(', | und | and ', line)), 3, path)
        self.assertIn('• Languages: English, French and German.', files[l10n_ship.DESCRIPTIONS['en-US'][3][0]])
        self.assertIn('• Sprachen: Deutsch, Englisch und Französisch.', files[l10n_ship.DESCRIPTIONS['de-DE'][3][0]])

    def test_a_second_run_changes_nothing(self):
        self.arb('fr', 6)
        self.arb('nb', 10)
        self.ship()
        shipped = self.snapshot()
        self.assertEqual(self.ship(), (0, '', ''))
        self.assertEqual(self.snapshot(), shipped)

    def test_below_half_is_not_shipped(self):
        self.arb('fr', 4)
        before = self.snapshot()
        self.ship()
        self.assertEqual(self.snapshot(), before)

    def test_dry_run_writes_nothing(self):
        self.arb('fr', 9)
        before = self.snapshot()
        code, out, _ = self.ship('--dry-run')
        self.assertEqual(code, 0)
        self.assertIn('Ships: fr', out)
        self.assertEqual(self.snapshot(), before)

    def test_holds_back_what_a_person_decides(self):
        for locale in ('ar', 'eo', 'pt_BR', 'zh_Hant', 'xx'):
            self.arb(locale, 10)
        before = self.snapshot()
        code, out, _ = self.ship()
        self.assertEqual(code, 0)
        self.assertNotIn('Ships:', out)
        self.assertIn('Not shipped: ar, 100.0 %: right-to-left layout is not checked', out)
        self.assertIn('Not shipped: eo, 100.0 %: Material has no texts for it', out)
        self.assertIn('Not shipped: pt_BR, 100.0 %: a regional or script variant', out)
        self.assertIn('Not shipped: zh_Hant, 100.0 %: a regional or script variant', out)
        self.assertIn('Not shipped: xx, 100.0 %: no name for the store descriptions', out)
        self.assertEqual(self.snapshot(), before)

    def test_ships_several_in_order_and_keeps_the_lists_equal(self):
        self.arb('nb', 10)
        self.arb('fr', 10)
        self.ship()
        files = self.snapshot()
        codes = re.findall(r"Locale\('([a-z]+)'\)", files[l10n_ship.SHIPPED_DART])
        self.assertEqual(codes, ['en', 'de', 'fr', 'nb'])
        self.assertEqual(re.findall(r'android:name="([^"]+)"', files[l10n_ship.ANDROID_CONFIG]), codes)
        self.assertEqual(re.findall(r'"([^"]+)"', re.search(r'setOf\(([^)]*)\)', files[l10n_ship.PREVIOUS_APP]).group(1)),
                         codes)

    def test_a_list_that_fits_stays_on_one_line_like_dart_format(self):
        self.assertEqual(l10n_ship.dart_list(['en', 'de']), "const List<Locale> shippedLocales = [Locale('en'), Locale('de')];")
        self.assertEqual(l10n_ship.dart_list(['en', 'de', 'fr', 'es']),
                         "const List<Locale> shippedLocales = [\n  Locale('en'),\n  Locale('de'),\n"
                         "  Locale('fr'),\n  Locale('es'),\n];")

    def test_a_missing_place_is_an_error(self):
        self.arb('fr', 10)
        write(self.root, l10n_ship.ANDROID_CONFIG, '<locale-config></x>')
        code, _, err = self.ship()
        self.assertEqual(code, 2)
        self.assertIn('locales_config.xml: the expected place was not found', err)

    def test_every_name_is_for_a_language_the_project_can_export(self):
        for code, (english, german) in l10n_ship.NAMES.items():
            self.assertRegex(code, r'^[a-z]{2,3}$')
            self.assertTrue(english and german, code)
            self.assertNotIn(code, l10n_ship.HELD_BACK)


if __name__ == '__main__':
    unittest.main()
