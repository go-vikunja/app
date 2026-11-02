"""Checks .gitlab-ci.yml (D73): the job sets per pipeline, pins, scripts and
the release job's protections. Parsed with Ruby's YAML, because Python has
no YAML parser without third-party packages."""
import json
import os
import re
import shutil
import subprocess
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG = os.path.join(ROOT, '.gitlab-ci.yml')
RESERVED = {'workflow', 'stages', 'default', 'variables', 'include', 'image', 'services', 'cache', 'before_script',
            'after_script'}
GITHUB_COUNTERPARTS = {'analyze-test': 'checks', 'editor': 'editor', 'contract': 'contract',
                       'build-android': 'android', 'build-ios': 'ios', 'sign-off': 'dco', 'osv-scan': 'osv'}
FIVE = {'checks', 'editor', 'contract', 'android', 'osv'}


def load():
    if not shutil.which('ruby'):
        if os.environ.get('CI') == 'true':
            raise AssertionError('ruby is needed to parse .gitlab-ci.yml')
        raise unittest.SkipTest('ruby is not installed')
    output = subprocess.run(
        ['ruby', '-ryaml', '-rjson', '-e', 'puts JSON.dump(YAML.safe_load(File.read(ARGV[0]), aliases: true))',
         CONFIG], check=True, capture_output=True, text=True).stdout
    return json.loads(output)


def merged(base, override):
    if isinstance(base, dict) and isinstance(override, dict):
        result = dict(base)
        for key, value in override.items():
            result[key] = merged(base[key], value) if key in base else value
        return result
    return override


def resolve(config, name, seen=()):
    job = config[name]
    if name in seen:
        raise AssertionError(f'extends cycle at {name}')
    parents = job.get('extends', [])
    parents = [parents] if isinstance(parents, str) else parents
    result = {}
    for parent in parents:
        result = merged(result, resolve(config, parent, seen + (name,)))
    return merged(result, {key: value for key, value in job.items() if key != 'extends'})


def jobs_of(config):
    return {name: resolve(config, name) for name in config if name not in RESERVED and not name.startswith('.')}


TOKEN = re.compile(r'\s*(?:(\(|\)|&&|\|\||==|!=|=~|!~)|\$([A-Za-z_][A-Za-z0-9_]*)|"([^"]*)"|\'([^\']*)\'|'
                   r'/((?:\\.|[^/\\])*)/|(null))')


def tokens(expression):
    position, found = 0, []
    while position < len(expression.rstrip()):
        match = TOKEN.match(expression, position)
        if not match:
            raise AssertionError(f'cannot parse {expression!r} at {position}')
        operator, variable, double, single, regex, null = match.groups()
        if operator:
            found.append(('op', operator))
        elif variable:
            found.append(('var', variable))
        elif double is not None or single is not None:
            found.append(('str', double if double is not None else single))
        elif regex is not None:
            found.append(('re', regex))
        else:
            found.append(('null', None))
        position = match.end()
    return found


def evaluate(expression, context):
    """GitLab's rules:if subset used here: ==, !=, =~, !~, bare variables,
    &&, || (&& binds tighter) and parentheses."""
    queue = tokens(expression)

    def take(kind=None, value=None):
        if not queue:
            raise AssertionError(f'unexpected end of {expression!r}')
        token = queue.pop(0)
        if (kind and token[0] != kind) or (value and token[1] != value):
            raise AssertionError(f'unexpected {token} in {expression!r}')
        return token

    def operand():
        kind, value = take()
        if kind == 'var':
            return context.get(value)
        if kind in ('str', 're', 'null'):
            return value
        raise AssertionError(f'unexpected {value} in {expression!r}')

    def comparison():
        if queue and queue[0] == ('op', '('):
            take()
            result = disjunction()
            take('op', ')')
            return result
        left = operand()
        if queue and queue[0][0] == 'op' and queue[0][1] in ('==', '!=', '=~', '!~'):
            operator = take()[1]
            right = operand()
            if operator in ('==', '!='):
                return (left == right) == (operator == '==')
            found = left is not None and re.search(right, left) is not None
            return found == (operator == '=~')
        return bool(left)

    def conjunction():
        result = comparison()
        while queue and queue[0] == ('op', '&&'):
            take()
            result = comparison() and result
        return result

    def disjunction():
        result = conjunction()
        while queue and queue[0] == ('op', '||'):
            take()
            result = conjunction() or result
        return result

    result = disjunction()
    if queue:
        raise AssertionError(f'trailing {queue} in {expression!r}')
    return result


def first_rule(rules, context):
    for rule in rules:
        if 'if' not in rule or evaluate(rule['if'], context):
            return rule.get('when', 'on_success')
    return None


def pipeline(config, **variables):
    """The jobs of a pipeline with these variables, or None without one."""
    context = dict(CI_DEFAULT_BRANCH='main', **variables)
    if first_rule(config['workflow']['rules'], context) in (None, 'never'):
        return None
    selected = set()
    for name, job in jobs_of(config).items():
        when = first_rule(job['rules'], context) if 'rules' in job else 'on_success'
        if when not in (None, 'never'):
            selected.add(name)
    return selected


class GitLabCiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = load()
        cls.jobs = jobs_of(cls.config)

    def test_the_jobs_of_each_pipeline(self):
        cases = [
            ('merge request', dict(CI_PIPELINE_SOURCE='merge_request_event', CI_MERGE_REQUEST_IID='1'),
             FIVE | {'dco'}),
            ('push to main', dict(CI_PIPELINE_SOURCE='push', CI_COMMIT_BRANCH='main', CI_COMMIT_REF_PROTECTED='true'),
             FIVE | {'pages'}),
            ('feature branch without a merge request', dict(CI_PIPELINE_SOURCE='push', CI_COMMIT_BRANCH='feature'),
             None),
            ('feature branch with an open merge request',
             dict(CI_PIPELINE_SOURCE='push', CI_COMMIT_BRANCH='feature', CI_OPEN_MERGE_REQUESTS='owner/rurana!1'),
             None),
            ('tag v1.0.0', dict(CI_PIPELINE_SOURCE='push', CI_COMMIT_TAG='v1.0.0', CI_COMMIT_REF_PROTECTED='true'),
             FIVE | {'release'}),
            ('tag v1.0.0-beta.1',
             dict(CI_PIPELINE_SOURCE='push', CI_COMMIT_TAG='v1.0.0-beta.1', CI_COMMIT_REF_PROTECTED='true'),
             FIVE | {'release'}),
            ('tag foo', dict(CI_PIPELINE_SOURCE='push', CI_COMMIT_TAG='foo'), None),
            ('schedule on main', dict(CI_PIPELINE_SOURCE='schedule', CI_COMMIT_BRANCH='main'), {'osv'}),
            ('web on main', dict(CI_PIPELINE_SOURCE='web', CI_COMMIT_BRANCH='main', CI_COMMIT_REF_PROTECTED='true'),
             FIVE | {'pages'}),
            ('web on another branch',
             dict(CI_PIPELINE_SOURCE='web', CI_COMMIT_BRANCH='feature', CI_COMMIT_REF_PROTECTED='true'), FIVE),
        ]
        for description, variables, expected in cases:
            with self.subTest(description):
                self.assertEqual(pipeline(self.config, **variables), expected)
            with self.subTest(f'{description}, with a Mac runner'):
                with_mac = pipeline(self.config, RURANA_MACOS_RUNNER='true', **variables)
                if expected is None:
                    self.assertIsNone(with_mac)
                elif variables['CI_PIPELINE_SOURCE'] == 'schedule' or 'CI_COMMIT_REF_PROTECTED' not in variables:
                    self.assertEqual(with_mac, expected)
                else:
                    self.assertEqual(with_mac, expected | {'ios'})

    def test_the_evaluator(self):
        context = {'A': 'main', 'B': 'main', 'EMPTY': ''}
        for expression, expected in [('$A == $B', True), ('$A != "main"', False), ('$A =~ /^ma/', True),
                                     ('$MISSING =~ /x/', False), ('$MISSING', False), ('$EMPTY', False),
                                     ('$A && $MISSING || $B', True), ('$A && ($MISSING || $B)', True),
                                     ('$MISSING == null', True), ('$A !~ /^x/', True)]:
            with self.subTest(expression):
                self.assertEqual(evaluate(expression, context), expected)

    def test_every_github_job_has_a_counterpart(self):
        for github, gitlab in GITHUB_COUNTERPARTS.items():
            with self.subTest(github):
                self.assertIn(gitlab, self.jobs)

    def test_scripts_exist_and_are_executable(self):
        named = set()
        for name, job in self.jobs.items():
            for key in ('before_script', 'script', 'after_script'):
                for line in job.get(key, []):
                    named.update(re.findall(r'tool/ci/[\w.-]+\.sh', line))
            self.assertTrue(job.get('script'), name)
        self.assertGreaterEqual(len(named), 9)
        for path in named:
            with self.subTest(path):
                self.assertTrue(os.access(os.path.join(ROOT, path), os.X_OK), path)

    def test_the_scripts_call_existing_files(self):
        for script in sorted(os.listdir(os.path.join(ROOT, 'tool/ci'))):
            if not script.endswith('.sh'):
                continue
            with open(os.path.join(ROOT, 'tool/ci', script), encoding='utf-8') as f:
                text = f.read()
            for path in set(re.findall(r'(?:tool|test_servers)/[\w./-]+\.(?:sh|py|yaml|source)', text)):
                with self.subTest(f'{script}: {path}'):
                    self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), path)

    def test_the_scan_covers_the_committed_lockfiles(self):
        with open(os.path.join(ROOT, 'tool/ci/osv.sh'), encoding='utf-8') as f:
            text = f.read()
        files = re.findall(r'--(?:lockfile|config)=(\S+)', text)
        self.assertEqual(sorted(files), ['app/android/app/gradle.lockfile', 'app/editor/package-lock.json',
                                         'osv-scanner.toml', 'pubspec.lock'])
        for path in files:
            self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), path)

    def test_images_and_services_are_pinned_by_digest(self):
        references = []
        for name, job in self.jobs.items():
            image = job.get('image')
            if image is None:
                self.assertEqual(job.get('tags'), ['macos'], f'{name} has no image')
                continue
            references.append(image if isinstance(image, str) else image['name'])
            references += [service if isinstance(service, str) else service['name']
                           for service in job.get('services', [])]
        self.assertEqual(len(references), 9)
        for reference in references:
            with self.subTest(reference):
                self.assertRegex(reference, r'^[^@\s]+:[^@\s]+@sha256:[0-9a-f]{64}$')

    def test_cache_keys_name_existing_files(self):
        for name, job in self.jobs.items():
            caches = job.get('cache', [])
            for cache in [caches] if isinstance(caches, dict) else caches:
                self.assertLessEqual(len(caches), 4, name)
                for path in cache['key']['files']:
                    self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), f'{name}: {path}')
                for path in cache['paths']:
                    self.assertTrue(path.startswith('.cache/'), f'{name}: {path}')

    def test_the_linux_jobs_keep_caches_in_the_project(self):
        for name in ('checks', 'contract', 'android', 'osv', 'dco', 'release'):
            with self.subTest(name):
                self.assertEqual(self.jobs[name]['variables']['PUB_CACHE'], '$CI_PROJECT_DIR/.cache/pub')
                self.assertEqual(self.jobs[name]['variables']['GRADLE_USER_HOME'], '$CI_PROJECT_DIR/.cache/gradle')
        self.assertNotIn('variables', self.jobs['ios'])

    def test_the_test_jobs_start_at_once(self):
        for name, job in self.jobs.items():
            if name != 'release':
                with self.subTest(name):
                    self.assertEqual(job.get('needs'), [])
                    self.assertEqual(job.get('stage'), 'test')

    def test_dco(self):
        dco = self.jobs['dco']
        self.assertEqual(dco['variables']['GIT_DEPTH'], '0')
        self.assertEqual(dco['script'], ['tool/ci/dco.sh "$CI_MERGE_REQUEST_DIFF_BASE_SHA" '
                                         '"${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA:-$CI_COMMIT_SHA}"'])
        with open(os.path.join(ROOT, 'tool/ci/dco.sh'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('judge="$CI_MERGE_REQUEST_TARGET_BRANCH_SHA"', text)
        self.assertIn('fetch --quiet --no-tags origin "refs/heads/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"', text)
        self.assertIn('show "${judge}:tool/check_dco.py" >"${tmp}/check_dco.py"', text)
        self.assertIn('python3 -I "${tmp}/check_dco.py" --repository "$repo_root" "$base" "$head"', text)

    def test_the_release_job(self):
        release = self.jobs['release']
        self.assertEqual(release['stage'], 'release')
        self.assertEqual(release['environment'], {'name': 'release'})
        self.assertEqual(release['resource_group'], 'release')
        self.assertIs(release['interruptible'], False)
        self.assertEqual(set(release['needs']), FIVE)
        self.assertEqual(release['script'], ['tool/ci/release.sh --tag "$CI_COMMIT_TAG"'])
        self.assertEqual(release['artifacts']['access'], 'developer')
        self.assertIn('build/release/app-release.aab', release['artifacts']['paths'])
        self.assertEqual(release['cache'], [])

    def test_the_pages_job(self):
        pages = self.jobs['pages']
        self.assertEqual(pages['script'], ['python3 -I tool/build_site.py --out public'])
        self.assertTrue(os.access(os.path.join(ROOT, 'tool/build_site.py'), os.X_OK))
        self.assertEqual(pages['artifacts'], {'paths': ['public']})
        self.assertEqual(pages['cache'], [])
        self.assertNotIn('allow_failure', pages)
        self.assertRegex(pages['image'], r'^python:[\d.]+-slim-\w+@sha256:[0-9a-f]{64}$')
        for variables in (dict(CI_PIPELINE_SOURCE='schedule', CI_COMMIT_BRANCH='main'),
                          dict(CI_PIPELINE_SOURCE='merge_request_event', CI_MERGE_REQUEST_IID='1'),
                          dict(CI_PIPELINE_SOURCE='push', CI_COMMIT_TAG='v1.0.0', CI_COMMIT_REF_PROTECTED='true')):
            with self.subTest(variables):
                self.assertNotIn('pages', pipeline(self.config, **variables))

    def test_interruptible(self):
        self.assertIs(self.config['default']['interruptible'], True)
        self.assertEqual(self.config['workflow']['auto_cancel'], {'on_new_commit': 'interruptible'})
        self.assertIs(self.jobs['osv']['interruptible'], False)
        self.assertNotIn('allow_failure', self.jobs['osv'])


if __name__ == '__main__':
    unittest.main()
