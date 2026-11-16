"""Checks crowdin.yml, which Crowdin's GitHub integration reads (D88)."""
import json
import os
import re
import unittest

from test_github_workflows import load

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG = os.path.join(ROOT, 'crowdin.yml')
# Crowdin's language codes and the ARB names gen-l10n reads; every other
# language keeps its two-letter code.
MAPPING = {'pt-PT': 'pt', 'pt-BR': 'pt_BR', 'zh-CN': 'zh', 'zh-TW': 'zh_Hant', 'no': 'nb', 'sr-CS': 'sr_Latn'}
# GitHub skips the push and pull_request runs of a commit that says one of
# these, and the pull request's required checks never report.
SKIP_CI = re.compile(r'(?i)\[(?:skip ci|ci skip|no ci|skip actions|actions skip)\]|skip-checks:\s*true')


def keys(value):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from keys(item)


class CrowdinConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = load(CONFIG)
        cls.l10n = load(os.path.join(ROOT, 'app', 'l10n.yaml'))
        (cls.file,) = cls.config['files']

    def test_the_project_and_no_credentials(self):
        self.assertEqual(self.config['project_id'], '462614')
        self.assertTrue(self.config['preserve_hierarchy'])
        for key in keys(self.config):
            with self.subTest(key):
                self.assertNotRegex(str(key), r'(?i)token|secret|password|api_key')
        with open(CONFIG, encoding='utf-8') as f:
            self.assertNotRegex(f.read(), r'(?i)\b(?:ghp|github_pat|gho)_\w+')

    def test_commits_and_pull_requests_run_ci(self):
        self.assertIs(self.config['append_commit_message'], False)
        for key in ('commit_message', 'pull_request_title'):
            with self.subTest(key):
                self.assertNotRegex(self.config[key], SKIP_CI)
                self.assertRegex(self.config[key], r'^chore\(i18n\): ')

    def test_the_paths(self):
        arb_dir = '/app/' + self.l10n['arb-dir']
        template = self.l10n['template-arb-file']
        self.assertEqual(self.file['source'], f'{arb_dir}/{template}')
        self.assertTrue(os.path.isfile(ROOT + self.file['source']), self.file['source'])
        self.assertEqual(self.file['translation'], f'{arb_dir}/app_%two_letters_code%.arb')
        self.assertEqual(self.file['dest'], '/app_en.arb')
        self.assertEqual(self.file['type'], 'arb')

    def test_the_options(self):
        self.assertEqual(self.file['update_option'], 'update_as_unapproved')
        self.assertIs(self.file['export_only_approved'], True)
        self.assertIs(self.file['skip_untranslated_strings'], True)
        self.assertNotIn('skip_untranslated_files', self.file)
        # Every language may translate the app; only shippedLocales decides
        # what the app offers.
        self.assertNotIn('excluded_target_languages', self.file)

    def test_the_language_mapping(self):
        self.assertEqual(self.file['languages_mapping'], {'two_letters_code': MAPPING})

    def test_every_regional_or_script_file_has_its_base(self):
        arb_dir = ROOT + '/app/' + self.l10n['arb-dir']
        for name in MAPPING.values():
            base = name.split('_')[0]
            if base != name:
                with self.subTest(name):
                    self.assertTrue(base in MAPPING.values() or os.path.isfile(f'{arb_dir}/app_{base}.arb'),
                                    f'app_{name}.arb needs app_{base}.arb')

    def test_the_template_names_no_locale(self):
        # Crowdin writes its own code into @@locale (pt-BR, zh-CN), which
        # gen-l10n refuses in a file named app_pt_BR.arb.
        with open(ROOT + self.file['source'], encoding='utf-8') as f:
            self.assertFalse('@@locale' in json.load(f), 'app_en.arb has @@locale')


if __name__ == '__main__':
    unittest.main()
