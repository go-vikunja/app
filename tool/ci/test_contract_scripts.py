"""Tests tool/contract_tests.sh and tool/ci/contract.sh (D28) on a copy of the
scripts, with fake docker-compose and flutter first on PATH: the requested
image is always started, and every suite runs before a failure counts."""
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

FAKE = r'''
import json
import os
import sys

tool, argv = sys.argv[1], sys.argv[2:]
with open(os.environ['FAKE_LOG'], 'a', encoding='utf-8') as f:
    f.write(json.dumps({'tool': tool, 'cwd': os.path.basename(os.getcwd()), 'argv': argv}) + '\n')
if tool == 'docker':
    sys.exit(1)
if tool == 'docker-compose':
    if 'config' in argv:
        print('vikunja')
    elif 'ps' in argv and '--services' in argv:
        print('vikunja')
    sys.exit(0)
if argv[:2] == ['--version', '--machine']:
    print(json.dumps({'frameworkVersion': os.environ['FAKE_FLUTTER_VERSION']}))
    sys.exit(0)
if argv[:1] == ['test'] and os.path.basename(os.getcwd()) in os.environ.get('FAKE_FAIL', '').split():
    sys.exit(1)
sys.exit(0)
'''


class ContractScriptsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.repo = os.path.join(self.tmp, 'repo')
        for directory in ('tool/ci', 'test_servers', 'packages/vikunja_api/test/contract', 'app/test/contract'):
            os.makedirs(os.path.join(self.repo, directory))
        for path in ('tool/contract_tests.sh', 'tool/ci/contract.sh', 'tool/ci/lib.sh', 'tool/ci/pins.sh'):
            shutil.copy2(os.path.join(ROOT, path), os.path.join(self.repo, path))
        with open(os.path.join(self.repo, 'test_servers/docker-compose.yaml'), 'w', encoding='utf-8') as f:
            f.write('services: {}\n')
        self.log = os.path.join(self.tmp, 'calls.jsonl')
        fake = os.path.join(self.tmp, 'fake.py')
        with open(fake, 'w', encoding='utf-8') as f:
            f.write(FAKE)
        bin_dir = os.path.join(self.tmp, 'bin')
        os.mkdir(bin_dir)
        for tool in ('docker', 'docker-compose', 'flutter'):
            self.executable(os.path.join(bin_dir, tool), f'#!/bin/sh\nexec "{sys.executable}" -I "{fake}" {tool} "$@"\n')
        self.executable(os.path.join(self.repo, 'tool/wait_for_test_servers.sh'),
                        f'#!/bin/sh\nexec "{sys.executable}" -I "{fake}" wait "$@"\n')
        with open(os.path.join(ROOT, 'tool/ci/pins.sh'), encoding='utf-8') as f:
            flutter = re.search(r'^FLUTTER_VERSION=(\S+)$', f.read(), re.MULTILINE).group(1)
        self.env = {name: value for name, value in os.environ.items()
                    if name not in ('GITHUB_ACTIONS', 'RUNNER_ENVIRONMENT', 'VIKUNJA_APP_TEST_VIKUNJA_IMAGE',
                                    'VIKUNJA_APP_TEST_DATABASE_PATH')}
        self.env.update({'PATH': bin_dir + os.pathsep + os.environ.get('PATH', os.defpath), 'FAKE_LOG': self.log,
                         'FAKE_FLUTTER_VERSION': flutter})

    @staticmethod
    def executable(path, text):
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)
        os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)

    def run_script(self, path, *arguments, **env):
        return subprocess.run(['bash', os.path.join(self.repo, path), *arguments], env={**self.env, **env},
                              capture_output=True, text=True, timeout=120)

    def calls(self, tool):
        with open(self.log, encoding='utf-8') as f:
            return [call for call in map(json.loads, f) if call['tool'] == tool]

    def test_contract_tests_start_the_requested_image_on_running_servers(self):
        result = self.run_script('tool/contract_tests.sh', VIKUNJA_APP_TEST_VIKUNJA_IMAGE='vikunja/vikunja:2.7.1')
        self.assertEqual(result.returncode, 0, result.stderr)
        compose = [call['argv'][2:] for call in self.calls('docker-compose')]
        self.assertIn(['up', '-d'], compose)
        (test,) = self.calls('flutter')
        self.assertEqual((test['cwd'], test['argv']), ('vikunja_api', ['test', '--tags', 'contract', 'test/contract']))

    def test_contract_runs_both_suites_before_failing(self):
        for failing in ('vikunja_api', 'app', 'vikunja_api app'):
            with self.subTest(failing=failing):
                if os.path.exists(self.log):
                    os.remove(self.log)
                result = self.run_script('tool/ci/contract.sh', FAKE_FAIL=failing)
                self.assertEqual(result.returncode, 1)
                suites = [call['cwd'] for call in self.calls('flutter') if call['argv'][:1] == ['test']]
                self.assertEqual(suites, ['vikunja_api', 'app'])
                self.assertIn(f'error: the contract tests of {failing} failed', result.stderr)
                self.assertIn(['logs', '--no-color', '--timestamps'],
                              [call['argv'][2:] for call in self.calls('docker-compose')])

    def test_contract_passes(self):
        result = self.run_script('tool/ci/contract.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        compose = [call['argv'][2:] for call in self.calls('docker-compose')]
        self.assertEqual(compose, [['up', '-d', '--quiet-pull']])
        api = [call['argv'] for call in self.calls('flutter') if call['cwd'] == 'vikunja_api']
        self.assertEqual(api, [['test', '--tags', 'contract', 'test/contract']])

    def test_contract_runs_api_files_one_at_a_time_without_immediate_transactions(self):
        result = self.run_script('tool/ci/contract.sh', VIKUNJA_APP_TEST_DATABASE_PATH='/tmp/vikunja.db?_x=')
        self.assertEqual(result.returncode, 0, result.stderr)
        api = [call['argv'] for call in self.calls('flutter') if call['cwd'] == 'vikunja_api']
        self.assertEqual(api, [['test', '--tags', 'contract', '--concurrency=1', 'test/contract']])


if __name__ == '__main__':
    unittest.main()
