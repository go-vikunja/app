"""Checks .github/workflows (D86): triggers, permissions, pins, secrets and the
jobs' counterparts in .gitlab-ci.yml. Parsed with Ruby's YAML, because Python
has no YAML parser without third-party packages."""
import json
import os
import re
import shutil
import subprocess
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORKFLOWS = os.path.join(ROOT, '.github', 'workflows')
GITLAB_CI = os.path.join(ROOT, '.gitlab-ci.yml')

WORKFLOW_FILES = {'ci.yaml', 'release.yaml'}
ALLOWED_ACTIONS = {'actions/checkout', 'actions/cache', 'actions/setup-node', 'actions/upload-artifact',
                   'actions/download-artifact'}
RUNNERS = {'ubuntu-24.04', 'macos-26'}
COUNTERPARTS = {'checks', 'editor', 'contract', 'android', 'osv', 'ios'}
RELEASE_JOBS = ('build', 'secret-scope', 'publish', 'dry-run')
SIGNING_SECRETS = ('KEYSTORE_BASE64', 'KEY_PROPERTIES', 'APK_KEYSTORE_BASE64', 'APK_KEY_PROPERTIES')
PLAY_SECRET = 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'
S3_SECRETS = ('S3_ACCESS_KEY', 'S3_SECRET_KEY', 'S3_ENDPOINT', 'S3_BUCKET', 'S3_REGION')
SECRETS = SIGNING_SECRETS + (PLAY_SECRET,) + S3_SECRETS
# The credentials among them, which no repository or organisation secret may
# hold: the job secret-scope sees only those.
CREDENTIALS = SIGNING_SECRETS + (PLAY_SECRET, 'S3_ACCESS_KEY', 'S3_SECRET_KEY')
OUTSIDE_RELEASE_ENVIRONMENT = '${{ ' + ' || '.join(f"secrets.{name} != ''" for name in CREDENTIALS) + ' }}'
BANNED = ('pull_request_target', 'workflow_run', 'self-hosted', 'fetch-depth', 'ACTIONS_STEP_DEBUG',
          'ACTIONS_RUNNER_DEBUG', 'secrets: inherit')

NOT_SCHEDULED = "github.event_name != 'schedule'"
OFFICIAL = "github.repository == 'go-vikunja/app'"
DRY_RUN_VARIABLE = "vars.VIKUNJA_APP_RELEASE_DRY_RUN == 'true'"
UNSIGNED = {'name': 'release-unsigned', 'path': 'build/release/unsigned'}
PUBLISH_RUNS = ['tool/ci/release_publish.sh check', 'tool/ci/release_sign.sh', 'tool/ci/release_publish.sh play',
                'tool/ci/release_publish.sh dl', 'tool/ci/release_publish.sh github']
DRY_RUN_RUNS = ['tool/ci/release_publish.sh --dry-run check', 'tool/ci/release_sign.sh --dry-run',
                'tool/ci/release_publish.sh --dry-run play', 'tool/ci/release_publish.sh --dry-run dl',
                'tool/ci/release_publish.sh --dry-run github']

LOCAL_USES = re.compile(r'uses: (\./\.github/workflows/[\w.-]+\.yaml)')
PINNED_USES = re.compile(r'uses: ([\w.-]+/[\w.-]+(?:/[\w./-]+)?)@([0-9a-f]{40}) # (v\d+\.\d+\.\d+)')
SCRIPT = re.compile(r'tool/ci/[\w.-]+\.sh')
SECRETS_REFERENCE = r'secrets\s*[.\[:]'
# One script with plain arguments: no pipes, lists or substitutions in a run.
ONE_SCRIPT = r'^tool/ci/[\w.-]+\.sh(?: (?:--?[\w-]+|[\w.-]+|"\$[A-Z_]+"))*$'
GITLAB_RESERVED = {'workflow', 'stages', 'default', 'variables', 'include', 'image', 'services', 'cache',
                   'before_script', 'after_script'}


def load(path, aliases=False):
    if not shutil.which('ruby'):
        if os.environ.get('CI') == 'true':
            raise AssertionError('ruby is needed to parse the workflows')
        raise unittest.SkipTest('ruby is not installed')
    options = ', aliases: true' if aliases else ''
    output = subprocess.run(
        ['ruby', '-ryaml', '-rjson', '-e', f'puts JSON.dump(YAML.safe_load(File.read(ARGV[0]){options}))', path],
        check=True, capture_output=True, text=True).stdout
    return json.loads(output)


def triggers(workflow):
    # Psych reads YAML 1.1, where the key on is the boolean true.
    return workflow.get('on', workflow.get('true'))


def steps(job):
    return job.get('steps', [])


def runs(job):
    return [step['run'] for step in steps(job) if 'run' in step]


def action(step):
    return step.get('uses', '').split('@')[0]


def steps_using(job, name):
    return [step for step in steps(job) if action(step) == name]


def step_running(job, command):
    found = [step for step in steps(job) if step.get('run') == command]
    if len(found) != 1:
        raise AssertionError(f'{len(found)} steps run {command!r}')
    return found[0]


def kinds(job):
    return [action(step) if 'uses' in step else 'run' for step in steps(job)]


def gitlab_scripts(config, name):
    """The tool/ci scripts a GitLab job names, following extends."""
    keys = ('before_script', 'script', 'after_script')

    def collect(job_name):
        job = config[job_name]
        parents = job.get('extends', [])
        result = {}
        for parent in [parents] if isinstance(parents, str) else parents:
            result.update(collect(parent))
        result.update({key: job[key] for key in keys if key in job})
        return result

    found = {key: value for key, value in config.get('default', {}).items() if key in keys}
    found.update(collect(name))
    return {script for lines in found.values() for line in lines for script in SCRIPT.findall(line)}


class GitHubWorkflowsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = sorted(name for name in os.listdir(WORKFLOWS) if name.endswith(('.yml', '.yaml')))
        cls.workflows = {name: load(os.path.join(WORKFLOWS, name)) for name in cls.files}
        cls.texts = {}
        for name in cls.files:
            with open(os.path.join(WORKFLOWS, name), encoding='utf-8') as f:
                cls.texts[name] = f.read()
        cls.ci = cls.workflows['ci.yaml']
        cls.release = cls.workflows['release.yaml']
        cls.gitlab = load(GITLAB_CI, aliases=True)

    def all_jobs(self):
        for file, workflow in self.workflows.items():
            for name, job in workflow['jobs'].items():
                yield f'{file}: {name}', job

    def all_steps(self):
        for label, job in self.all_jobs():
            for index, step in enumerate(steps(job)):
                yield f'{label} step {index + 1}', step

    def test_the_workflow_files(self):
        self.assertEqual(set(self.files), WORKFLOW_FILES)

    def test_triggers(self):
        ci = triggers(self.ci)
        self.assertEqual(set(ci), {'push', 'pull_request', 'schedule', 'workflow_dispatch', 'workflow_call'})
        self.assertEqual(ci['push'], {'branches': ['main']})
        self.assertEqual(ci['schedule'], [{'cron': '23 5 * * 1'}])
        for event in ('pull_request', 'workflow_dispatch', 'workflow_call'):
            with self.subTest(event):
                self.assertIsNone(ci[event])
        self.assertEqual(triggers(self.release), {'push': {'tags': ['v*']}})
        for file, workflow in self.workflows.items():
            with self.subTest(file):
                self.assertNotIn('pull_request_target', triggers(workflow))
                self.assertNotIn('workflow_run', triggers(workflow))

    def test_permissions(self):
        for file, workflow in self.workflows.items():
            with self.subTest(file):
                self.assertIn('permissions', workflow)
                self.assertEqual(workflow['permissions'], {})
        for label, job in self.all_jobs():
            with self.subTest(label):
                expected = 'write' if label == 'release.yaml: publish' else 'read'
                self.assertEqual(job.get('permissions'), {'contents': expected})

    def test_actions_are_pinned(self):
        pins = {}
        parsed = sorted(value['uses'] for _, value in [*self.all_jobs(), *self.all_steps()] if 'uses' in value)
        written = []
        for file, text in self.texts.items():
            for line in text.splitlines():
                line = line.strip().removeprefix('- ')
                if 'uses:' not in line:
                    continue
                with self.subTest(f'{file}: {line}'):
                    local = LOCAL_USES.fullmatch(line)
                    pinned = PINNED_USES.fullmatch(line)
                    self.assertTrue(local or pinned, line)
                    if local:
                        written.append(local.group(1))
                        self.assertTrue(os.path.isfile(os.path.join(ROOT, local.group(1))), line)
                    else:
                        name, sha, version = pinned.groups()
                        written.append(f'{name}@{sha}')
                        self.assertIn(name, ALLOWED_ACTIONS)
                        self.assertEqual(name.split('/')[0], 'actions')
                        pins.setdefault(name, set()).add((sha, version))
        self.assertEqual(sorted(written), parsed)
        for name, versions in pins.items():
            with self.subTest(name):
                self.assertEqual(len(versions), 1, versions)

    def test_checkout_keeps_no_credentials(self):
        for label, job in self.all_jobs():
            if 'uses' not in job:
                with self.subTest(f'{label} starts with a checkout'):
                    self.assertEqual(kinds(job)[0], 'actions/checkout')
        for label, step in self.all_steps():
            if action(step) == 'actions/checkout':
                with self.subTest(label):
                    self.assertIs(step.get('with', {}).get('persist-credentials'), False)

    def test_no_expressions_in_run(self):
        for label, step in self.all_steps():
            if 'run' in step:
                with self.subTest(label):
                    self.assertNotIn('${{', step['run'])

    def test_runners_and_timeouts(self):
        for label, job in self.all_jobs():
            if 'uses' in job:
                continue
            with self.subTest(label):
                self.assertIn(job.get('runs-on'), RUNNERS)
                self.assertIs(type(job.get('timeout-minutes')), int)
                self.assertGreater(job['timeout-minutes'], 0)

    def test_defaults(self):
        for file, workflow in self.workflows.items():
            with self.subTest(file):
                self.assertEqual(workflow.get('defaults', {}).get('run', {}).get('shell'), 'bash')

    def test_concurrency(self):
        concurrency = self.ci['concurrency']
        self.assertTrue(concurrency['group'].startswith('ci-'))
        self.assertIn('github.event.pull_request.number || github.ref', concurrency['group'])
        self.assertNotIn('github.workflow', concurrency['group'])
        self.assertIs(concurrency['cancel-in-progress'], True)
        self.assertNotIn('concurrency', self.release)
        self.assertEqual(self.release['jobs']['publish']['concurrency'],
                         {'group': 'release-publish', 'cancel-in-progress': False})

    def test_the_schedule_runs_osv_only(self):
        for name, job in self.ci['jobs'].items():
            with self.subTest(name):
                if name == 'osv':
                    self.assertNotIn('if', job)
                elif name == 'ios':
                    self.assertEqual(job['if'],
                                     f"{NOT_SCHEDULED} && ({OFFICIAL} || vars.VIKUNJA_APP_IOS_JOB == 'true')")
                else:
                    self.assertEqual(job['if'], NOT_SCHEDULED)

    def test_counterparts_in_gitlab(self):
        gitlab_jobs = {name for name in self.gitlab if name not in GITLAB_RESERVED and not name.startswith('.')}
        self.assertEqual(set(self.ci['jobs']), COUNTERPARTS)
        for name in sorted(COUNTERPARTS):
            with self.subTest(name):
                self.assertIn(name, gitlab_jobs)
                self.assertNotIn('name', self.ci['jobs'][name])
                github = {script for line in runs(self.ci['jobs'][name]) for script in SCRIPT.findall(line)}
                self.assertTrue(github)
                self.assertEqual(github, gitlab_scripts(self.gitlab, name))
        self.assertIn('dco', gitlab_jobs)
        for file, workflow in self.workflows.items():
            with self.subTest(f'no dco in {file}'):
                self.assertNotIn('dco', workflow['jobs'])
        self.assertIn('release', gitlab_jobs)
        self.assertLessEqual(set(RELEASE_JOBS), set(self.release['jobs']))

    def test_the_scripts_exist_and_are_executable(self):
        named = set()
        for label, step in self.all_steps():
            if 'run' not in step:
                continue
            with self.subTest(label):
                self.assertNotIn('\n', step['run'].strip())
                self.assertRegex(step['run'], ONE_SCRIPT)
            named.update(re.findall(r'tool/ci/[\w./-]+', step['run']))
        for path in sorted(named):
            with self.subTest(path):
                self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), f'{path} is missing')
                self.assertTrue(os.access(os.path.join(ROOT, path), os.X_OK), f'{path} is not executable')

    def test_caches(self):
        for label, step in self.all_steps():
            if action(step) != 'actions/cache':
                continue
            with self.subTest(label):
                for arguments in re.findall(r'hashFiles\(([^)]*)\)', step['with']['key']):
                    files = re.findall(r"'([^']*)'", arguments)
                    self.assertTrue(files)
                    for path in files:
                        self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), path)
                for path in step['with']['path'].split('\n'):
                    if path.strip():
                        self.assertTrue(path.strip().startswith('.cache/'), path)
                        self.assertNotIn('..', path)
        for name in RELEASE_JOBS:
            job = self.release['jobs'][name]
            with self.subTest(name):
                self.assertEqual(steps_using(job, 'actions/cache'), [])
                for step in steps(job):
                    if action(step).startswith('actions/setup-'):
                        self.assertNotIn('cache', step.get('with', {}))
                self.assertNotIn('restore-keys', json.dumps(job))

    def test_node_matches_gitlab(self):
        image = self.gitlab['editor']['image']
        version = re.match(r'node:(\d+\.\d+\.\d+)-', image).group(1)
        setup = steps_using(self.ci['jobs']['editor'], 'actions/setup-node')
        self.assertEqual(len(setup), 1)
        self.assertEqual(setup[0]['with']['node-version'], version)

    def test_caches_stay_in_the_workspace(self):
        expected = {'PUB_CACHE': '${{ github.workspace }}/.cache/pub',
                    'GRADLE_USER_HOME': '${{ github.workspace }}/.cache/gradle'}
        for label, env in (('ci.yaml', self.ci['env']), ('release.yaml: build', self.release['jobs']['build']['env'])):
            with self.subTest(label):
                self.assertEqual({key: env.get(key) for key in expected}, expected)

    def test_the_release_jobs(self):
        jobs = self.release['jobs']
        self.assertEqual(jobs['ci'], {'uses': './.github/workflows/ci.yaml', 'permissions': {'contents': 'read'}})

        build = jobs['build']
        self.assertEqual(build['if'], f'{OFFICIAL} || {DRY_RUN_VARIABLE}')
        self.assertNotIn('needs', build)
        self.assertNotIn('environment', build)
        self.assertEqual(runs(build), ['tool/ci/release_build.sh --tag "$GITHUB_REF_NAME"'])
        self.assertEqual(kinds(build), ['actions/checkout', 'run', 'actions/upload-artifact'])
        self.assertEqual(steps_using(build, 'actions/upload-artifact')[0]['with'],
                         {'name': 'release-unsigned', 'path': 'build/release/unsigned/', 'if-no-files-found': 'error',
                          'retention-days': 14})

        scope = jobs['secret-scope']
        self.assertEqual(scope['if'], OFFICIAL)
        self.assertNotIn('needs', scope)
        self.assertEqual(runs(scope), ['tool/ci/release_publish.sh scope'])
        self.assertEqual(kinds(scope), ['actions/checkout', 'run'])

        publish = jobs['publish']
        self.assertEqual(publish['if'], OFFICIAL)
        self.assertEqual(set(publish['needs']), {'ci', 'build', 'secret-scope'})
        self.assertEqual(publish['environment'], 'release')
        self.assertEqual(runs(publish), PUBLISH_RUNS)

        dry_run = jobs['dry-run']
        self.assertEqual(dry_run['if'], f"github.repository != 'go-vikunja/app' && {DRY_RUN_VARIABLE}")
        self.assertEqual(set(dry_run['needs']), {'ci', 'build'})
        self.assertNotIn('environment', dry_run)
        self.assertEqual(runs(dry_run), DRY_RUN_RUNS)

        for name, job in (('publish', publish), ('dry-run', dry_run)):
            with self.subTest(name):
                self.assertEqual(kinds(job), ['actions/checkout', 'actions/download-artifact'] + ['run'] * 5)
                self.assertEqual(steps_using(job, 'actions/download-artifact')[0]['with'], UNSIGNED)
        for label, job in self.all_jobs():
            if label != 'release.yaml: publish':
                with self.subTest(label):
                    self.assertNotIn('environment', job)

    def test_secrets_only_in_publish(self):
        self.assertNotRegex(self.texts['ci.yaml'], SECRETS_REFERENCE)
        others = dict(self.release, jobs={name: job for name, job in self.release['jobs'].items()
                                          if name not in ('publish', 'secret-scope')})
        self.assertNotRegex(json.dumps(others), SECRETS_REFERENCE)
        for label, job in self.all_jobs():
            with self.subTest(label):
                self.assertNotIn('secrets', job)

        scope = self.release['jobs']['secret-scope']
        self.assertNotIn('env', scope)
        self.assertNotIn('environment', scope)
        check = step_running(scope, 'tool/ci/release_publish.sh scope')
        self.assertEqual(check['env'], {'OUTSIDE_RELEASE_ENVIRONMENT': OUTSIDE_RELEASE_ENVIRONMENT})
        without = dict(scope, steps=[dict(step, env={}) if step is check else step for step in steps(scope)])
        self.assertNotRegex(json.dumps(without), SECRETS_REFERENCE)

        publish = self.release['jobs']['publish']
        self.assertNotIn('env', publish)
        self.assertEqual(step_running(publish, 'tool/ci/release_publish.sh check')['env'],
                         {f'HAS_{name}': f"${{{{ secrets.{name} != '' }}}}" for name in SECRETS})
        self.assertEqual(step_running(publish, 'tool/ci/release_sign.sh')['env'],
                         {name: f'${{{{ secrets.{name} }}}}' for name in SIGNING_SECRETS})
        self.assertEqual(step_running(publish, 'tool/ci/release_publish.sh play')['env'],
                         {PLAY_SECRET: f'${{{{ secrets.{PLAY_SECRET} }}}}',
                          'VIKUNJA_APP_PLAY_ROLLOUT': '${{ vars.VIKUNJA_APP_PLAY_ROLLOUT }}'})
        self.assertEqual(step_running(publish, 'tool/ci/release_publish.sh dl')['env'],
                         {name: f'${{{{ secrets.{name} }}}}' for name in S3_SECRETS})
        self.assertEqual(step_running(publish, 'tool/ci/release_publish.sh github')['env'],
                         {'GH_TOKEN': '${{ github.token }}'})
        for step in steps(publish):
            if 'uses' in step:
                self.assertNotRegex(json.dumps(step), SECRETS_REFERENCE)

        self.assertNotIn('secrets[', json.dumps(publish))
        self.assertEqual(set(re.findall(r'secrets\.(\w+)', json.dumps(publish))), set(SECRETS))
        for name in SECRETS:
            with self.subTest(name):
                value = f'${{{{ secrets.{name} }}}}'
                self.assertEqual(sum(value in json.dumps(step) for step in steps(publish)), 1)

    def test_bans(self):
        for file, text in self.texts.items():
            for banned in BANNED:
                with self.subTest(f'{file}: {banned}'):
                    self.assertNotIn(banned, text)
        allowed = []
        for label, job in self.all_jobs():
            with self.subTest(label):
                self.assertNotIn('continue-on-error', job)
            for step in steps(job):
                if 'continue-on-error' in step:
                    allowed.append((label, step))
        self.assertEqual(len(allowed), 1)
        label, step = allowed[0]
        self.assertEqual(label, 'ci.yaml: checks')
        self.assertEqual(step, {'if': '${{ !cancelled() }}', 'continue-on-error': True, 'run': 'tool/ci/outdated.sh'})
        self.assertEqual(sum(text.count('continue-on-error') for text in self.texts.values()), 1)


if __name__ == '__main__':
    unittest.main()
