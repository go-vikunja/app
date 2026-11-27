"""Tests tool/ci/crowdin_sync.sh in a copy of the repository's scripts with a
real git repository, a bare one as origin, and fake crowdin and gh first on
PATH (decision log: Languages)."""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPTS = ('crowdin_sync.sh', 'lib.sh', 'pins.sh', 'release_lib.sh')
ARB = 'app/lib/l10n/arb'
SHIPPING_FILES = [
    'app/lib/app/l10n/shipped_locales.dart', 'app/android/app/src/main/res/xml/locales_config.xml',
    'app/ios/Runner/Info.plist', 'app/ios/VikunjaWidgets/Info.plist',
    'app/android/app/src/main/kotlin/io/vikunja/app/PreviousApp.kt', 'app/lib/app/l10n/picker_localizations.dart',
    'app/lib/app/l10n/l10n.dart', 'app/test/l10n/store_listing_languages_test.dart',
    'fastlane/metadata/en-US/description.txt',
    'fastlane/metadata/de-DE/description.txt', 'fastlane/metadata/android/en-US/full_description.txt',
    'fastlane/metadata/android/de-DE/full_description.txt',
]
OFFICIAL = {'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': 'go-vikunja/app', 'GITHUB_REPOSITORY_ID': '1468952826',
            'GITHUB_REF': 'refs/heads/main'}
CROWDIN_TOKEN = 'fake-crowdin-token-5e1f0a7c'
GH_TOKEN = 'ghs_fakecrowdinsync42'
ENGLISH = {'appTitle': 'Vikunja', 'done': 'Done', 'later': 'Later', 'open': 'Open', 'close': 'Close'}
GERMAN = {'appTitle': 'Vikunja', 'done': 'Erledigt'}
SWISS = {'appTitle': 'Vikunja', 'done': 'Erlediget'}
FRENCH = {'appTitle': 'Vikunja', 'done': 'Terminé'}
PR_URL = 'https://github.com/go-vikunja/app/pull/400'

FAKE_TOOL = r'''
import hashlib
import json
import os
import sys

tool, argv = sys.argv[1], sys.argv[2:]
entry = {'tool': tool, 'argv': argv,
         'tokens': {name: hashlib.sha256(os.environ[name].encode()).hexdigest()
                    for name in ('CROWDIN_PERSONAL_TOKEN', 'GH_TOKEN', 'GITHUB_TOKEN', 'CROWDIN_PROJECT_ID')
                    if name in os.environ}}


def finish(code=0, out='', err=''):
    with open(os.environ['FAKE_LOG'], 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry) + '\n')
    sys.stdout.write(out)
    sys.stderr.write(err)
    sys.exit(code)


def write(files):
    for name, content in files.items():
        path = os.path.join('app/lib/l10n/arb', name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content if isinstance(content, str) else json.dumps(content, ensure_ascii=False, indent=2))


def link(links):
    for name, target in links.items():
        path = os.path.join('app/lib/l10n/arb', name)
        if os.path.lexists(path):
            os.remove(path)
        os.symlink(target, path)


with open(os.environ['FAKE_CONFIG'], encoding='utf-8') as f:
    config = json.load(f)
if tool == 'crowdin':
    if argv == ['--version']:
        sys.stdout.write('5.6.0\n')
        sys.exit(0)
    if argv[:2] == ['upload', 'sources']:
        finish()
    if argv[:2] == ['download', 'translations']:
        if '--exclude-language' in argv:
            write(config.get('others', {}))
            link(config.get('other_links', {}))
        elif '--language' in argv:
            write(config.get('german', {}))
            link(config.get('german_links', {}))
        finish()
    finish(2, err='fake crowdin: unexpected call\n')

if tool == 'gh':
    if argv[:2] == ['pr', 'list']:
        finish(out=config.get('open_pr', '') + '\n')
    if argv[:1] == ['api'] and '-F' in argv:
        field = argv[argv.index('-F') + 1]
        if field.startswith('body=@'):
            with open(field[len('body=@'):], encoding='utf-8') as f:
                entry['body'] = f.read()
        finish()
    if argv[:2] == ['pr', 'create']:
        with open(argv[argv.index('--body-file') + 1], encoding='utf-8') as f:
            entry['body'] = f.read()
        if config.get('create_fails'):
            finish(1, err='pull request create failed: GraphQL: GitHub Actions is not permitted to create or '
                          'approve pull requests (createPullRequest)\n')
        finish(out=config.get('created', '') + '\n')
    finish(2, err='fake gh: unexpected call\n')
'''


def git(cwd, *argv, bare=False):
    git_dir = ['--git-dir', cwd] if bare else []
    return subprocess.run(['git', *git_dir, *argv], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def dump(value):
    return json.dumps(value, ensure_ascii=False, indent=2)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        for directory in ('home', 'temp', 'bin'):
            os.mkdir(os.path.join(self.tmp, directory))
        self.repo = os.path.join(self.tmp, 'repo')
        self.origin = os.path.join(self.tmp, 'origin.git')
        self.log = os.path.join(self.tmp, 'calls.jsonl')
        self.config_path = os.path.join(self.tmp, 'config.json')
        self.output = os.path.join(self.tmp, 'output')
        self.summary = os.path.join(self.tmp, 'summary.md')
        self.configure()
        fake = os.path.join(self.tmp, 'fake_tool.py')
        with open(fake, 'w', encoding='utf-8') as f:
            f.write(FAKE_TOOL)
        for tool in ('crowdin', 'gh'):
            path = os.path.join(self.tmp, 'bin', tool)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(f'#!/bin/sh\nexec "{sys.executable}" -I "{fake}" {tool} "$@"\n')
            os.chmod(path, 0o755)

        os.makedirs(os.path.join(self.repo, 'tool', 'ci'))
        for script in SCRIPTS:
            shutil.copy2(os.path.join(ROOT, 'tool', 'ci', script), os.path.join(self.repo, 'tool', 'ci', script))
        for script in ('l10n_ship.py', 'l10n_progress.py'):
            shutil.copy2(os.path.join(ROOT, 'tool', script), os.path.join(self.repo, 'tool', script))
        for path in SHIPPING_FILES:
            if os.path.isfile(os.path.join(ROOT, path)):
                os.makedirs(os.path.dirname(os.path.join(self.repo, path)), exist_ok=True)
                shutil.copy2(os.path.join(ROOT, path), os.path.join(self.repo, path))
        shutil.copy2(os.path.join(ROOT, 'crowdin.yml'), self.repo)
        with open(os.path.join(self.repo, '.gitignore'), 'w', encoding='utf-8') as f:
            f.write('build/\n.cache/\n')
        os.makedirs(os.path.join(self.repo, ARB))
        self.write_arb('app_en.arb', ENGLISH)
        self.write_arb('app_de.arb', GERMAN)
        self.write_arb('app_sr.arb', {})
        self.write_arb('app_fr.arb', {'appTitle': 'Vikunja'})
        env = self.env()
        for argv in (['init', '-q', '-b', 'main'], ['add', '.'], ['commit', '-q', '-m', 'init']):
            subprocess.run(['git', *argv], cwd=self.repo, env=env, check=True, capture_output=True)
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', self.origin], check=True, capture_output=True)
        git(self.repo, 'remote', 'add', 'origin', self.origin)
        git(self.repo, 'push', '-q', 'origin', 'main')
        self.main = git(self.repo, 'rev-parse', 'HEAD')

    def configure(self, **config):
        with open(self.config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f)

    def write_arb(self, name, content, root=None):
        path = os.path.join(root or os.path.join(self.repo, ARB), name)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content if isinstance(content, str) else dump(content))

    def read(self, path):
        with open(os.path.join(self.repo, path), encoding='utf-8') as f:
            return f.read()

    def env(self, **extra):
        env = {'PATH': os.path.join(self.tmp, 'bin') + os.pathsep + os.environ.get('PATH', os.defpath),
               'HOME': os.path.join(self.tmp, 'home'), 'TMPDIR': os.path.join(self.tmp, 'temp'),
               'GIT_CONFIG_NOSYSTEM': '1', 'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 'test@example.test',
               'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 'test@example.test',
               'FAKE_LOG': self.log, 'FAKE_CONFIG': self.config_path}
        env.update(extra)
        return env

    def sync(self, *arguments, official=True, **extra):
        env = self.env(**{**(OFFICIAL if official else {}), 'GITHUB_OUTPUT': self.output,
                          'GITHUB_STEP_SUMMARY': self.summary, **extra})
        for name in ('GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL'):
            del env[name]
        result = subprocess.run(['bash', os.path.join(self.repo, 'tool', 'ci', 'crowdin_sync.sh'), *arguments],
                                cwd=self.tmp, env=env, capture_output=True, text=True, timeout=120)
        for token in (CROWDIN_TOKEN, GH_TOKEN):
            self.assertNotIn(token, result.stdout + result.stderr)
        self.assertEqual(os.listdir(os.path.join(self.tmp, 'temp')), [], 'a temporary file is left behind')
        return result

    def calls(self, tool=None):
        if not os.path.exists(self.log):
            return []
        with open(self.log, encoding='utf-8') as f:
            calls = [json.loads(line) for line in f]
        return [call for call in calls if tool is None or call['tool'] == tool]

    def outputs(self):
        if not os.path.exists(self.output):
            return ''
        with open(self.output, encoding='utf-8') as f:
            return f.read()


def sha(value):
    return hashlib.sha256(value.encode()).hexdigest()


class UsageTest(Fixture):
    def test_usage(self):
        for arguments in ((), ('sync',), ('--dry-run',), ('upload', '--dry-run'), ('upload', 'download')):
            with self.subTest(arguments=arguments):
                result = self.sync(*arguments)
                self.assertEqual(result.returncode, 2)
                self.assertIn('usage: tool/ci/crowdin_sync.sh [--dry-run] upload|download|pull-request', result.stderr)

    def test_dry_runs_need_nothing(self):
        expected = {'upload': 'crowdin upload sources',
                    'download': 'crowdin download translations --export-only-approved '
                                '--skip-untranslated-strings --exclude-language de'}
        for step, text in expected.items():
            with self.subTest(step):
                result = self.sync('--dry-run', step, official=False)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(text, result.stdout)
        self.assertEqual(self.calls(), [])


class UploadTest(Fixture):
    def test_skips_without_the_token(self):
        for step in ('upload', 'download'):
            with self.subTest(step):
                result = self.sync(step)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('::notice title=Crowdin skipped::CROWDIN_PERSONAL_TOKEN is not set', result.stdout)
        self.assertEqual(self.outputs(), 'changed=false\n')
        self.assertEqual(self.calls(), [])

    def test_only_on_main_of_the_official_repository(self):
        for change in ({'GITHUB_REPOSITORY': 'someone/app'}, {'GITHUB_REPOSITORY_ID': '1'},
                       {'GITHUB_REF': 'refs/heads/feature'}, {'GITHUB_ACTIONS': 'false'}):
            for step in ('upload', 'download'):
                with self.subTest(change=change, step=step):
                    result = self.sync(step, CROWDIN_PERSONAL_TOKEN=CROWDIN_TOKEN, **change)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn('only a run on main of go-vikunja/app', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_uploads_the_source(self):
        result = self.sync('upload', CROWDIN_PERSONAL_TOKEN=CROWDIN_TOKEN, CROWDIN_PROJECT_ID='1', GH_TOKEN=GH_TOKEN)
        self.assertEqual(result.returncode, 0, result.stderr)
        (call,) = self.calls()
        self.assertEqual(call['argv'], ['upload', 'sources'])
        self.assertEqual(call['tokens'], {'CROWDIN_PERSONAL_TOKEN': sha(CROWDIN_TOKEN)})


class DownloadTest(Fixture):
    def download(self):
        return self.sync('download', CROWDIN_PERSONAL_TOKEN=CROWDIN_TOKEN, GH_TOKEN=GH_TOKEN)

    def taken(self):
        directory = os.path.join(self.repo, 'build', 'crowdin', 'arb')
        return {name: json.loads(self.read(f'build/crowdin/arb/{name}')) for name in sorted(os.listdir(directory))}

    def test_german_only_from_its_own_download(self):
        german = dict(GERMAN, later='Später')
        self.configure(others={'app_fr.arb': FRENCH, 'app_nl.arb': {'done': 'Klaar'}, 'app_de.arb': SWISS,
                               'app_en.arb': {'done': 'Finished'}, 'app_es-419.arb': {'done': 'Hecho'},
                               'sub/app_it.arb': {}},
                       german={'app_de.arb': german})
        result = self.download()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call['argv'] for call in self.calls()], [
            ['download', 'translations', '--export-only-approved', '--skip-untranslated-strings',
             '--exclude-language', 'de'],
            ['download', 'translations', '--export-only-approved', '--skip-untranslated-strings',
             '--language', 'de']])
        for call in self.calls():
            self.assertEqual(call['tokens'], {'CROWDIN_PERSONAL_TOKEN': sha(CROWDIN_TOKEN)})
        self.assertEqual(self.taken(), {'app_de.arb': german, 'app_fr.arb': FRENCH, 'app_nl.arb': {'done': 'Klaar'}})
        self.assertEqual(json.loads(self.read(f'{ARB}/app_en.arb')), ENGLISH)
        self.assertEqual(self.read('build/crowdin/dropped.txt').splitlines(),
                         ['app_de.arb', 'app_en.arb', 'app_es-419.arb', 'sub?app_it.arb'])
        self.assertIn('::warning title=Crowdin file not taken::app_de.arb: a language other than German was exported '
                      'as app_de.arb', result.stdout)
        self.assertIn('::warning title=Crowdin file not taken::app_en.arb: ', result.stdout)
        self.assertEqual(self.outputs(), 'changed=true\n')

    def test_swiss_german_cannot_replace_unchanged_german(self):
        self.configure(others={'app_de.arb': SWISS}, german={'app_de.arb': GERMAN})
        result = self.download()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.taken(), {})
        self.assertEqual(json.loads(self.read(f'{ARB}/app_de.arb')), GERMAN)
        self.assertEqual(self.read('build/crowdin/dropped.txt'), 'app_de.arb\n')
        self.assertEqual(self.outputs(), 'changed=false\n')

    def test_nothing_changed(self):
        self.configure(others={'app_fr.arb': {'appTitle': 'Vikunja'}}, german={'app_de.arb': GERMAN})
        result = self.download()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.taken(), {})
        self.assertIn('changes no ARB file of the checkout', result.stdout)
        self.assertEqual(self.outputs(), 'changed=false\n')

    def test_the_german_download_writes_nothing_else(self):
        self.configure(others={'app_fr.arb': FRENCH}, german={'app_de.arb': GERMAN, 'app_gsw.arb': SWISS})
        result = self.download()
        self.assertEqual(result.returncode, 1)
        self.assertIn('the download of German alone changed other files than app/lib/l10n/arb/app_de.arb',
                      result.stderr)
        self.assertNotIn('changed=true', self.outputs())

    def test_refuses_what_is_no_json_object(self):
        for content in ('{"done": ', '["Terminé"]'):
            with self.subTest(content=content):
                git(self.repo, 'checkout', '-q', '--', ARB)
                self.configure(others={'app_fr.arb': content}, german={})
                result = self.download()
                self.assertEqual(result.returncode, 1)
                self.assertNotIn('changed=true', self.outputs())

    def test_refuses_a_symbolic_link(self):
        target = os.path.join(self.tmp, 'event.json')
        with open(target, 'w', encoding='utf-8') as f:
            json.dump({'token': 'from the runner'}, f)
        for config in ({'other_links': {'app_it.arb': target}}, {'german_links': {'app_it.arb': target}},
                       {'other_links': {'app_de.arb': target}}):
            with self.subTest(config=config):
                git(self.repo, 'checkout', '-q', '--', ARB)
                git(self.repo, 'clean', '-q', '-f', '--', ARB)
                self.configure(others={'app_fr.arb': FRENCH}, german={'app_de.arb': GERMAN}, **config)
                result = self.download()
                self.assertEqual(result.returncode, 1)
                self.assertIn('the download wrote a symbolic link into app/lib/l10n/arb', result.stderr)
                self.assertNotIn('changed=true', self.outputs())
                self.assertEqual(os.listdir(os.path.join(self.repo, 'build', 'crowdin', 'arb')), [])

    def test_refuses_a_changed_checkout(self):
        self.write_arb('app_fr.arb', FRENCH)
        result = self.download()
        self.assertEqual(result.returncode, 1)
        self.assertIn('differs from the checkout before the download', result.stderr)
        self.assertEqual(self.calls(), [])


class PullRequestTest(Fixture):
    def setUp(self):
        super().setUp()
        self.artifact = os.path.join(self.repo, 'build', 'crowdin', 'arb')
        os.makedirs(self.artifact)
        self.configure(created=PR_URL)

    def pull_request(self, *arguments, **extra):
        return self.sync(*arguments, 'pull-request', **{'GH_TOKEN': GH_TOKEN, **extra})

    def remote_git(self, *argv):
        return git(self.origin, *argv, bare=True)

    def remote_branch(self):
        listing = self.remote_git('for-each-ref', '--format=%(objectname)', 'refs/heads/crowdin')
        return listing or None

    def test_commits_pushes_and_opens_the_pull_request(self):
        self.write_arb('app_fr.arb', FRENCH, self.artifact)
        self.write_arb('app_de.arb', GERMAN, self.artifact)
        with open(os.path.join(self.repo, 'build', 'crowdin', 'dropped.txt'), 'w', encoding='utf-8') as f:
            f.write('app_de.arb\n')
        result = self.pull_request(CROWDIN_PERSONAL_TOKEN=CROWDIN_TOKEN)
        self.assertEqual(result.returncode, 0, result.stderr)
        head = self.remote_branch()
        self.assertEqual(self.remote_git('rev-parse', f'{head}^'), self.main)
        self.assertEqual(self.remote_git('show', '-s', '--format=%an <%ae>|%cn <%ce>|%s', head),
                         'Frederick [Bot] <bot@vikunja.io>|Frederick [Bot] <bot@vikunja.io>|'
                         'chore(i18n): update translations via Crowdin')
        self.assertEqual(self.remote_git('diff', '--name-only', self.main, head), f'{ARB}/app_fr.arb')
        self.assertEqual(self.remote_git('show', 'refs/heads/main:app/lib/l10n/arb/app_fr.arb'),
                         dump({'appTitle': 'Vikunja'}))
        calls = self.calls('gh')
        self.assertEqual([call['argv'][:2] for call in calls], [['pr', 'list'], ['pr', 'create']])
        self.assertEqual(calls[0]['argv'], ['pr', 'list', '--repo', 'go-vikunja/app', '--head', 'crowdin', '--base',
                                            'main', '--state', 'open', '--json', 'number,isCrossRepository', '--jq',
                                            'map(select(.isCrossRepository | not)) | .[0].number // ""'])
        create = calls[1]
        self.assertEqual(create['argv'][:10], ['pr', 'create', '--repo', 'go-vikunja/app', '--base', 'main',
                                               '--head', 'crowdin', '--title',
                                               'chore(i18n): update translations via Crowdin'])
        for call in calls:
            self.assertEqual(call['tokens'], {'GH_TOKEN': sha(GH_TOKEN)})
        self.assertIn('"Approve workflows to run"', create['body'])
        self.assertIn('"Awaiting approval"', create['body'])
        self.assertIn('- `app_de.arb`', create['body'])
        self.assertIn(f'Opened the pull request {PR_URL}', result.stdout)

    def test_ships_a_language_that_reached_half_of_the_english_texts(self):
        self.write_arb('app_fr.arb', dict(FRENCH, later='Plus tard'), self.artifact)
        result = self.pull_request()
        self.assertEqual(result.returncode, 0, result.stderr)
        head = self.remote_branch()
        names = set(self.remote_git('diff', '--name-only', self.main, head).split('\n'))
        self.assertEqual(names, {f'{ARB}/app_fr.arb', *(path for path in SHIPPING_FILES
                                                         if os.path.isfile(os.path.join(ROOT, path))
                                                         and path != 'app/ios/VikunjaWidgets/Info.plist')})
        shipped = self.remote_git('show', f'{head}:app/lib/app/l10n/shipped_locales.dart')
        self.assertIn("Locale('fr')", shipped)
        (create,) = [call for call in self.calls('gh') if call['argv'][:2] == ['pr', 'create']]
        self.assertIn('Ships: fr (French), 60.0 %', create['body'])
        self.assertIn('tool/l10n_ship.py', create['body'])
        self.assertEqual(self.read('app/lib/app/l10n/shipped_locales.dart').count("Locale('fr')"), 1)

    def test_a_failing_ship_step_stops_before_anything_is_pushed(self):
        git(self.repo, 'rm', '-q', 'app/android/app/src/main/res/xml/locales_config.xml')
        git(self.repo, '-c', 'user.name=Someone', '-c', 'user.email=someone@example.test', '-c', 'commit.gpgsign=false',
            'commit', '-q', '-m', 'remove')
        git(self.repo, 'push', '-q', 'origin', 'main')
        self.write_arb('app_fr.arb', dict(FRENCH, later='Plus tard'), self.artifact)
        result = self.pull_request()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('locales_config.xml', result.stderr)
        self.assertIsNone(self.remote_branch())

    def commit_on(self, branch, path, content):
        git(self.repo, 'switch', '-q', branch)
        os.makedirs(os.path.dirname(os.path.join(self.repo, path)), exist_ok=True)
        with open(os.path.join(self.repo, path), 'w', encoding='utf-8') as f:
            f.write(content)
        git(self.repo, 'add', path)
        git(self.repo, '-c', 'user.name=Someone', '-c', 'user.email=someone@example.test', '-c', 'commit.gpgsign=false',
            'commit', '-q', '-m', 'something else')
        git(self.repo, 'push', '-q', 'origin', f'{branch}:{branch}')
        git(self.repo, 'switch', '-q', 'main')

    def test_an_open_pull_request_takes_the_push(self):
        self.write_arb('app_fr.arb', FRENCH, self.artifact)
        self.assertEqual(self.pull_request().returncode, 0)
        first = self.remote_branch()
        self.configure(open_pr='400')
        os.remove(self.log)
        git(self.repo, 'switch', '-q', 'main')
        with open(os.path.join(self.repo, 'build', 'crowdin', 'dropped.txt'), 'w', encoding='utf-8') as f:
            f.write('app_de.arb\n')

        result = self.pull_request()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('holds these translations on this main already: not pushed', result.stdout)
        self.assertEqual(self.remote_branch(), first)
        calls = self.calls('gh')
        self.assertEqual([call['argv'][:2] for call in calls], [['pr', 'list'], ['api', '--silent']])
        self.assertEqual(calls[1]['argv'][:5], ['api', '--silent', '--method', 'PATCH', 'repos/go-vikunja/app/pulls/400'])
        self.assertEqual(calls[1]['tokens'], {'GH_TOKEN': sha(GH_TOKEN)})
        self.assertIn('"Approve workflows to run"', calls[1]['body'])
        self.assertIn('- `app_de.arb`', calls[1]['body'])
        self.assertIn(f'The pull request {PR_URL} is open: it shows the branch, and its text is updated.',
                      result.stdout)

        os.remove(self.log)
        git(self.repo, 'switch', '-q', 'main')
        self.write_arb('app_fr.arb', dict(FRENCH, done='Fini'), self.artifact)
        result = self.pull_request()
        self.assertEqual(result.returncode, 0, result.stderr)
        second = self.remote_branch()
        self.assertNotEqual(second, first)
        self.assertEqual(self.remote_git('rev-parse', f'{second}^'), self.main)
        self.assertEqual([call['argv'][:2] for call in self.calls('gh')], [['pr', 'list'], ['api', '--silent']])

    def test_replaces_what_else_was_pushed_to_the_branch(self):
        self.write_arb('app_fr.arb', FRENCH, self.artifact)
        self.assertEqual(self.pull_request().returncode, 0)
        git(self.repo, 'switch', '-q', 'main')
        self.commit_on('crowdin', '.github/workflows/other.yaml', 'on: push\n')
        self.assertEqual(self.remote_git('diff', '--name-only', 'main', 'crowdin').splitlines(),
                         ['.github/workflows/other.yaml', f'{ARB}/app_fr.arb'])

        result = self.pull_request()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Pushed app_fr.arb to the branch crowdin.', result.stdout)
        head = self.remote_branch()
        self.assertEqual(self.remote_git('rev-parse', f'{head}^'), self.main)
        self.assertEqual(self.remote_git('diff', '--name-only', self.main, head), f'{ARB}/app_fr.arb')

    def test_follows_main(self):
        self.write_arb('app_fr.arb', FRENCH, self.artifact)
        self.assertEqual(self.pull_request().returncode, 0)
        git(self.repo, 'switch', '-q', 'main')
        self.commit_on('main', 'README.md', 'Vikunja\n')
        main = git(self.repo, 'rev-parse', 'HEAD')

        result = self.pull_request()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Pushed app_fr.arb to the branch crowdin.', result.stdout)
        head = self.remote_branch()
        self.assertEqual(self.remote_git('rev-parse', f'{head}^'), main)
        self.assertEqual(self.remote_git('diff', '--name-only', main, head), f'{ARB}/app_fr.arb')

    def test_nothing_new(self):
        self.write_arb('app_de.arb', GERMAN, self.artifact)
        result = self.pull_request()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('has these translations already: no pull request', result.stdout)
        self.assertIsNone(self.remote_branch())
        self.assertEqual(self.calls(), [])

    def test_refuses_what_is_no_translation(self):
        cases = {'app_en.arb': dump(FRENCH), 'app_fr.txt': dump(FRENCH), '.app_fr.arb': dump(FRENCH),
                 'app_fr.arb': '["Terminé"]', 'app_nl.arb': '{"done": '}
        for name, content in cases.items():
            with self.subTest(name=name, content=content):
                shutil.rmtree(self.artifact)
                os.makedirs(self.artifact)
                self.write_arb(name, content, self.artifact)
                result = self.pull_request()
                self.assertEqual(result.returncode, 1)
        with self.subTest('symlink'):
            shutil.rmtree(self.artifact)
            os.makedirs(self.artifact)
            os.symlink(os.path.join(self.repo, ARB, 'app_en.arb'), os.path.join(self.artifact, 'app_fr.arb'))
            self.assertEqual(self.pull_request().returncode, 1)
        with self.subTest('dropped'):
            shutil.rmtree(self.artifact)
            os.makedirs(self.artifact)
            self.write_arb('app_fr.arb', FRENCH, self.artifact)
            with open(os.path.join(self.repo, 'build', 'crowdin', 'dropped.txt'), 'w', encoding='utf-8') as f:
                f.write('[click](https://example.test)\n')
            result = self.pull_request()
            self.assertEqual(result.returncode, 1)
            self.assertIn('dropped.txt has a line that is no file name', result.stderr)
        with self.subTest('empty'):
            shutil.rmtree(self.artifact)
            os.makedirs(self.artifact)
            self.assertEqual(self.pull_request().returncode, 1)
        self.assertIsNone(self.remote_branch())
        self.assertEqual(self.calls(), [])
        self.assertEqual(git(self.repo, 'status', '--porcelain'), '')

    def test_only_on_main_of_the_official_repository(self):
        self.write_arb('app_fr.arb', FRENCH, self.artifact)
        result = self.pull_request(GITHUB_REPOSITORY='someone/app')
        self.assertEqual(result.returncode, 1)
        self.assertIn('only a run on main of go-vikunja/app', result.stderr)
        self.assertIsNone(self.remote_branch())
        self.assertEqual(self.calls(), [])

    def test_names_the_setting_when_github_refuses_the_pull_request(self):
        self.configure(create_fails=True)
        self.write_arb('app_fr.arb', FRENCH, self.artifact)
        result = self.pull_request()
        self.assertEqual(result.returncode, 1)
        self.assertIn('GitHub Actions is not permitted to create or approve pull requests', result.stderr)
        message = ' '.join(result.stderr.split())
        self.assertIn('"Allow GitHub Actions to create and approve pull requests" on in the repository', message)
        self.assertIn("an organisation owner allows it first in the organisation's Settings > Actions > General",
                      message)

    def test_dry_run(self):
        self.write_arb('app_fr.arb', FRENCH, self.artifact)
        result = self.pull_request('--dry-run', official=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Would commit app_fr.arb as "chore(i18n): update translations via Crowdin" by Frederick [Bot] '
                      '<bot@vikunja.io> on the branch crowdin', result.stdout)
        self.assertIn('Approve workflows to run', result.stdout)
        self.assertEqual(git(self.repo, 'status', '--porcelain'), '')
        self.assertEqual(git(self.repo, 'branch', '--show-current'), 'main')
        self.assertIsNone(self.remote_branch())
        self.assertEqual(self.calls(), [])


if __name__ == '__main__':
    unittest.main()
