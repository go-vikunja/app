"""Tests tool/l10n_progress.py, which the release build runs (D88)."""
import contextlib
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

TOOL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(TOOL)
SCRIPT = os.path.join(TOOL, 'l10n_progress.py')
_spec = importlib.util.spec_from_file_location('l10n_progress', SCRIPT)
l10n_progress = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(l10n_progress)

TEMPLATE = {
    '@@locale': 'en',
    'save': 'Save',
    '@save': {'description': 'A button'},
    'delete': 'Delete',
    'tasks': '{count, plural, =1{{count} task} other{{count} tasks}}',
    '@tasks': {'placeholders': {'count': {'type': 'int'}}},
    'title': 'Title',
}


class L10nProgressTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)
        self.arb('en', TEMPLATE)

    def arb(self, locale, data):
        with open(os.path.join(self.dir, f'app_{locale}.arb'), 'w', encoding='utf-8') as f:
            json.dump(data, f)

    def shipped(self, text):
        path = os.path.join(self.dir, 'shipped_locales.dart')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)
        return path

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = l10n_progress.main(['--arb-dir', self.dir, *argv])
            except SystemExit as e:
                code = e.code
        return code, out.getvalue(), err.getvalue()

    def test_counts_the_template_messages_a_file_translates(self):
        self.arb('de', {'@@locale': 'de', 'save': 'Speichern', 'delete': '', 'tasks': '{count, plural, '
                        'other{{count} Aufgaben}}', 'gone': 'Nicht mehr da', '@save': {'description': 'x'}})
        self.assertEqual(l10n_progress.progress(self.dir, ['de', 'en']),
                         [('de', 2, 4, True), ('en', 4, 4, True)])

    def test_lists_every_arb_file_without_a_selection(self):
        self.arb('pt_BR', {'save': 'Salvar'})
        self.arb('pt', {})
        code, out, _ = self.run_main()
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines(), [
            'en     4 of 4  100.0 %',
            'pt     0 of 4    0.0 %',
            'pt_BR  1 of 4   25.0 %',
        ])

    def test_rounds_down(self):
        self.arb('de', {'save': 'Speichern', 'delete': 'Löschen', 'tasks': 'Aufgaben'})
        self.assertEqual(l10n_progress.report([('de', 3, 4, True)]), 'de  3 of 4   75.0 %')
        self.assertEqual(l10n_progress.report([('de', 2257, 2258, True)]), 'de  2257 of 2258   99.9 %')
        self.assertEqual(l10n_progress.report([('fr', 2, 3, True)]), 'fr  2 of 3   66.6 %')

    def test_min_fails_only_below_it(self):
        self.arb('de', {'save': 'Speichern', 'delete': 'Löschen'})
        self.assertEqual(self.run_main('--min', '50', 'de')[0], 0)
        code, out, _ = self.run_main('--min', '50.5', 'de')
        self.assertEqual(code, 1)
        self.assertEqual(out, 'de  2 of 4   50.0 %  below 50.5 %\n')
        self.assertEqual(self.run_main('--min', '100', 'en')[0], 0)
        self.assertEqual(self.run_main('--min', '100', 'de')[0], 1)
        self.assertEqual(self.run_main('de')[0], 0)

    def test_a_locale_without_a_file_has_nothing(self):
        code, out, _ = self.run_main('--min', '50', 'fr', 'pt-BR')
        self.assertEqual(code, 1)
        self.assertEqual(out.splitlines(), [
            'fr     0 of 4    0.0 %  no app_fr.arb, below 50 %',
            'pt_BR  0 of 4    0.0 %  no app_pt_BR.arb, below 50 %',
        ])

    def test_the_shipped_list(self):
        self.arb('de', {'save': 'Speichern', 'delete': 'Löschen', 'tasks': 'x', 'title': 'Titel'})
        self.arb('pt_BR', {'save': 'Salvar'})
        path = self.shipped("import 'package:flutter/widgets.dart';\n\n"
                            '/// Not Locale(\'fr\').\n'
                            'const List<Locale> shippedLocales = [\n'
                            "  Locale('en'),\n  Locale('de'),\n  Locale('pt', 'BR'),\n];\n\n"
                            'Locale shippedLocaleFor(Iterable<Locale> locales, {\n'
                            '  List<Locale> shipped = shippedLocales,\n'
                            '}) => shipped.first;\n')
        code, out, _ = self.run_main('--shipped-list', path, '--min', '50')
        self.assertEqual(code, 1)
        self.assertEqual(out.splitlines(), [
            'en     4 of 4  100.0 %',
            'de     4 of 4  100.0 %',
            'pt_BR  1 of 4   25.0 %  below 50 %',
        ])

    def test_reads_every_form_of_a_locale(self):
        text = ('final shippedLocales = <Locale>[\n'
                "  Locale('en'), // the fallback\n"
                '  const Locale("de"),\n'
                "  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),\n"
                "  Locale( 'pt' , 'BR' , ),\n"
                "  Locale.fromSubtags(countryCode: 'TW', scriptCode: 'Hant', languageCode: 'zh'),\n"
                "  Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn',),\n"
                '];\n')
        self.assertEqual(l10n_progress.shipped_locales(text),
                         ['en', 'de', 'zh_Hant', 'pt_BR', 'zh_Hant_TW', 'sr_Latn'])

    def test_refuses_a_list_it_cannot_read(self):
        for text in ('const supported = [Locale(\'en\')];\n',
                     'const shippedLocales = <Locale>[];\n',
                     "const shippedLocales = [Locale('en'), fallbackLocale];\n",
                     "const shippedLocales = [Locale('en'), ...more];\n",
                     "const shippedLocales = [Locale.fromSubtags(scriptCode: 'Hant')];\n",
                     "const shippedLocales = [Locale.fromSubtags(languageCode: 'zh', region: 'TW')];\n",
                     "const shippedLocales = [Locale('EN')];\n",
                     "const shippedLocales = [Locale('de', 'swiss')];\n"):
            with self.subTest(text):
                code, out, err = self.run_main('--shipped-list', self.shipped(text))
                self.assertEqual(code, 2)
                self.assertEqual(out, '')
                self.assertTrue(err.startswith('error: shipped_locales.dart: '), err)

    def test_unreadable_input(self):
        code, _, err = self.run_main('--shipped-list', os.path.join(self.dir, 'missing.dart'))
        self.assertEqual(code, 2)
        self.assertIn('missing.dart', err)
        with open(os.path.join(self.dir, 'app_fr.arb'), 'w', encoding='utf-8') as f:
            f.write('{"save": "Enregistrer",}')
        code, _, err = self.run_main('fr')
        self.assertEqual(code, 2)
        self.assertTrue(err.startswith('error: app_fr.arb: '), err)
        os.remove(os.path.join(self.dir, 'app_en.arb'))
        self.assertEqual(self.run_main('de')[0], 2)

    def test_arguments(self):
        for argv in (['--min', '101'], ['--min', '-1'], ['--min', 'half'], ['de', 'x y'],
                     ['--shipped-list', self.shipped("const shippedLocales = [Locale('en')];"), 'de']):
            with self.subTest(argv):
                self.assertEqual(self.run_main(*argv)[0], 2)

    def test_the_committed_shipped_list(self):
        with open(l10n_progress.SHIPPED_LIST, encoding='utf-8') as f:
            locales = l10n_progress.shipped_locales(f.read())
        self.assertEqual(locales[:1], ['en'])
        self.assertIn('de', locales)
        for locale in locales:
            with self.subTest(locale):
                self.assertTrue(os.path.isfile(os.path.join(l10n_progress.ARB_DIR, f'app_{locale}.arb')), locale)

    def test_the_release_build_call(self):
        result = subprocess.run([sys.executable, '-I', SCRIPT, '--shipped-list', '--min', '0'],
                                capture_output=True, text=True, cwd=self.dir)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r'(?m)^en +(\d+) of \1  100\.0 %$')
        self.assertRegex(result.stdout, r'(?m)^de ')


if __name__ == '__main__':
    unittest.main()
