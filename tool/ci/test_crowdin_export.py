"""Runs a simulated Crowdin export through the real gen-l10n, the ARB parity
test and tool/l10n_progress.py (D88), outside app/lib."""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

from test_crowdin_config import MAPPING

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
APP = os.path.join(ROOT, 'app')
PROGRESS = os.path.join(ROOT, 'tool', 'l10n_progress.py')
# gen-l10n refuses to run without the generate flag.
PUBSPEC = 'name: crowdin_export\nenvironment:\n  sdk: ^3.0.0\nflutter:\n  generate: true\n'

# Forms per language as CLDR has them, with stand-in words.
DEFAULT_FORMS = [('one', 'item'), ('other', 'items')]
PLURAL_FORMS = {
    'pt': [('one', 'tarefa'), ('many', 'de tarefas'), ('other', 'tarefas')],
    'pt_BR': [('one', 'tarefa'), ('other', 'tarefas')],
    'zh': [('other', '项任务')],
    'zh_Hant': [('other', '項任務')],
    'sr_Latn': [('one', 'zadatak'), ('few', 'zadatka'), ('other', 'zadataka')],
    'nb': [('one', 'oppgave'), ('other', 'oppgaver')],
    'fr': [('one', 'tâche'), ('many', 'de tâches'), ('other', 'tâches')],
}
# Crowdin may copy the template's @key metadata and add its own @@ keys, or
# drop the descriptions.
WITH_METADATA = {'pt', 'fr'}
SIMPLE_PLACEHOLDER = re.compile(r'\{(\w+)\}')
PLURAL = re.compile(r'\{(\w+), plural, .*\}', re.DOTALL)


def flutter():
    path = shutil.which('flutter')
    if not path:
        if os.environ.get('CI') == 'true':
            raise AssertionError('flutter is needed to run gen-l10n')
        raise unittest.SkipTest('flutter is not on PATH: export PATH="<the Flutter SDK>/bin:$PATH"')
    if not os.path.isfile(os.path.join(ROOT, '.dart_tool', 'package_config.json')):
        raise unittest.SkipTest('run flutter pub get at the repository root first')
    return path


def l10n_option(text, name):
    return re.search(rf'(?m)^{name}:\s*(\S+)\s*$', text).group(1)


def run(argv, cwd):
    return subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=300)


class CrowdinExportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.flutter = flutter()
        with open(os.path.join(APP, 'l10n.yaml'), encoding='utf-8') as f:
            cls.l10n_yaml = f.read()
        cls.arb_dir = l10n_option(cls.l10n_yaml, 'arb-dir')
        cls.output_dir = l10n_option(cls.l10n_yaml, 'output-dir')
        with open(os.path.join(APP, cls.arb_dir, l10n_option(cls.l10n_yaml, 'template-arb-file')),
                  encoding='utf-8') as f:
            cls.english = json.load(f)
        cls.total = sum(1 for key, value in cls.english.items() if not key.startswith('@') and value.strip())
        cls.sample = cls.sample_keys()
        # fr stands for the languages Crowdin names by their two-letter code,
        # eo for those exported but not shipped, as Material lacks them.
        cls.export = {name: cls.translation(name) for name in [*MAPPING.values(), 'fr', 'eo']}
        cls.temp = tempfile.mkdtemp(prefix='crowdin-export-')
        cls.addClassCleanup(shutil.rmtree, cls.temp, ignore_errors=True)
        cls.project = cls.make_project('export')
        cls.gen_l10n = run([cls.flutter, 'gen-l10n'], cls.project)

    @classmethod
    def sample_keys(cls):
        """A plural, a message with one placeholder and two plain ones."""
        plural = placeholder = None
        plain = []
        for key, value in cls.english.items():
            if key.startswith('@'):
                continue
            names = set(SIMPLE_PLACEHOLDER.findall(value))
            meta = cls.english.get(f'@{key}', {}).get('placeholders', {})
            if ((match := PLURAL.fullmatch(value)) and value.count(', plural,') == 1 and ', select,' not in value
                    and names <= {match.group(1)} and plural is None):
                plural = (key, match.group(1))
            elif (len(names) == 1 and value.count('{') == 1 and placeholder is None
                  and meta.get(next(iter(names)), {}).get('type', 'String') == 'String'):
                placeholder = (key, next(iter(names)))
            elif '{' not in value and len(plain) < 2:
                plain.append(key)
        assert plural and placeholder and len(plain) == 2, 'app_en.arb lacks a message the simulation needs'
        return plural, placeholder, plain

    @classmethod
    def translation(cls, name):
        (plural, count), (placeholder, argument), plain = cls.sample
        cases = ' '.join(f'{form}{{{{{count}}} {word}}}' for form, word in PLURAL_FORMS.get(name, DEFAULT_FORMS))
        messages = {
            plain[0]: f'Text 1 {name} ✓',
            plain[1]: f'Text 2 {name}',
            placeholder: f'{{{argument}}} ({name})',
            plural: f'{{{count}, plural, {cases}}}',
        }
        # Crowdin keeps the template's order and leaves untranslated keys out.
        data = {}
        if name in WITH_METADATA:
            data['@@last_modified'] = '2026-11-16T10:00:00+00:00'
            data['@@x-generator'] = 'Crowdin'
        for key in cls.english:
            if key in messages:
                data[key] = messages[key]
                if name in WITH_METADATA and f'@{key}' in cls.english:
                    data[f'@{key}'] = cls.english[f'@{key}']
        return data

    @classmethod
    def make_project(cls, name, change=None):
        """The app's ARB folder and l10n.yaml with the export written into
        the folder, which change(folder) may then edit."""
        project = os.path.join(cls.temp, name)
        arb = os.path.join(project, cls.arb_dir)
        shutil.copytree(os.path.join(APP, cls.arb_dir), arb)
        for locale, data in cls.export.items():
            with open(os.path.join(arb, f'app_{locale}.arb'), 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        with open(os.path.join(project, 'l10n.yaml'), 'w', encoding='utf-8') as f:
            f.write(cls.l10n_yaml)
        with open(os.path.join(project, 'pubspec.yaml'), 'w', encoding='utf-8') as f:
            f.write(PUBSPEC)
        if change:
            change(arb)
        return project

    def arb(self, project):
        return os.path.join(project, self.arb_dir)

    def parity_test(self, project):
        return run([self.flutter, 'test', '--no-pub', '--reporter', 'expanded',
                    f'--dart-define=ARB_DIR={self.arb(project)}', 'test/l10n/arb_parity_test.dart'], APP)

    def test_the_export_is_shaped_as_crowdin_writes_it(self):
        self.assertLessEqual({'pt', 'pt_BR', 'zh', 'zh_Hant', 'sr_Latn', 'nb', 'gsw', 'eo'}, set(self.export))
        self.assertTrue(os.path.isfile(os.path.join(self.arb(self.project), 'app_sr.arb')),
                        'the committed base of app_sr_Latn.arb')
        for data in self.export.values():
            self.assertNotIn('@@locale', data)

    def test_gen_l10n_builds_every_language(self):
        self.assertEqual(self.gen_l10n.returncode, 0, self.gen_l10n.stdout + self.gen_l10n.stderr)
        output = os.path.join(self.project, self.output_dir)
        code = ''
        for name in sorted(os.listdir(output)):
            with open(os.path.join(output, name), encoding='utf-8') as f:
                code += f.read()
        for locale in ['pt', 'pt_BR', 'zh', 'zh_Hant', 'sr', 'sr_Latn', 'nb', 'gsw', 'fr', 'eo']:
            with self.subTest(locale):
                class_name = 'AppLocalizations' + ''.join(part.capitalize() for part in locale.split('_'))
                self.assertRegex(code, rf'\bclass {class_name} extends ')
                if locale in self.export:
                    self.assertIn(f'Text 1 {locale} ✓', code)

    def test_the_parity_rules_accept_it(self):
        result = self.parity_test(self.project)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for locale in self.export:
            with self.subTest(locale):
                self.assertIn(f'{locale} translates only English messages', result.stdout)

    def test_l10n_progress_reports_each_share(self):
        result = run([sys.executable, '-I', PROGRESS, '--arb-dir', self.arb(self.project)], ROOT)
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = {line.split()[0]: line for line in result.stdout.splitlines()}
        self.assertEqual(set(rows), {'en', 'de', 'sr', *self.export})
        self.assertRegex(rows['sr'], rf'^sr +0 of {self.total} +0\.0 %$')
        for locale in self.export:
            with self.subTest(locale):
                self.assertRegex(rows[locale], rf'^{locale} +4 of {self.total} +0\.\d %$')
        below = run([sys.executable, '-I', PROGRESS, '--arb-dir', self.arb(self.project), '--min', '50', 'pt_BR'],
                    ROOT)
        self.assertEqual(below.returncode, 1, below.stdout + below.stderr)

    def test_a_hyphenated_file_name_fails_the_parity_rules(self):
        # Crowdin's %locale% without the mapping; gen-l10n would read it as
        # pt_BR, unchecked.
        project = self.make_project('hyphen-name', lambda arb: os.rename(
            os.path.join(arb, 'app_pt_BR.arb'), os.path.join(arb, 'app_pt-BR.arb')))
        result = self.parity_test(project)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('app_pt-BR.arb', result.stdout)

    def test_a_hyphenated_locale_code_fails_gen_l10n(self):
        # What Crowdin writes when the template has @@locale.
        def name_the_locale(arb):
            path = os.path.join(arb, 'app_pt_BR.arb')
            with open(path, encoding='utf-8') as f:
                data = json.load(f)
            with open(path, 'w', encoding='utf-8') as f:
                json.dump({'@@locale': 'pt-BR', **data}, f, ensure_ascii=False)

        result = run([self.flutter, 'gen-l10n'], self.make_project('hyphen-locale', name_the_locale))
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('Current @@locale value: pt-BR', result.stdout + result.stderr)

    def test_a_missing_base_fails_gen_l10n(self):
        for base in ('pt', 'zh', 'sr'):
            with self.subTest(base):
                project = self.make_project(f'no-{base}', lambda arb, base=base: os.remove(
                    os.path.join(arb, f'app_{base}.arb')))
                result = run([self.flutter, 'gen-l10n'], project)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(f'Arb file for a fallback, {base}, does not exist', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
