"""Tests tool/ci/release_publish.sh with a fake release directory, fake gh,
aws and git first on PATH and, for play, the fake Play API of
test_play_upload.py."""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from release_version import release_version
from test_play_upload import EMAIL, OPENSSL, FakePlay, generate_key

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(ROOT, 'tool/ci/release_publish.sh')
METADATA = os.path.join(ROOT, 'fastlane/metadata/android')
OFFICIAL = {'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': 'go-vikunja/app', 'GITHUB_REPOSITORY_ID': '395095540',
            'GITHUB_REF_TYPE': 'tag'}
SECRETS = ('KEYSTORE_BASE64', 'KEY_PROPERTIES', 'APK_KEYSTORE_BASE64', 'APK_KEY_PROPERTIES',
           'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', 'S3_ACCESS_KEY', 'S3_SECRET_KEY', 'S3_ENDPOINT', 'S3_BUCKET',
           'S3_REGION')
S3 = {'S3_ACCESS_KEY': 'AKIAFAKEACCESSKEY0042', 'S3_SECRET_KEY': 'fake/s3+secret-key-31f2c9a7d84e',
      'S3_ENDPOINT': 's3.example.test', 'S3_BUCKET': 'fake-dl-bucket', 'S3_REGION': 'fake-region-1'}
GH_TOKEN = 'ghs_faketoken6b1d0c'
DESUGAR = 'desugar_jdk_libs-2.1.4-src.tar.gz'
COMMIT = '50d9c1fb3e85fa4c00161525a45484f712c1f003'
CERTIFICATE = 'c0ffee' * 10 + 'beef'
BUILT = '7a1c3e5f9b2d4c6e8a0b1d3f5e7c9a2b4d6f8e0a'
OTHER_COMMIT = 'e' * 40
CREDENTIALS = ('KEYSTORE_BASE64', 'KEY_PROPERTIES', 'APK_KEYSTORE_BASE64', 'APK_KEY_PROPERTIES',
               'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', 'S3_ACCESS_KEY', 'S3_SECRET_KEY')
APK_TYPE = 'application/vnd.android.package-archive'
ABIS = ('arm64-v8a', 'armeabi-v7a', 'x86_64')


def abi_key(abi):
    return abi.upper().replace('-', '_')


def apk_files(name):
    """The universal APK, then the per-ABI ones."""
    return [f'vikunja-app-{name}.apk'] + [f'vikunja-app-{name}-{abi}.apk' for abi in ABIS]

FAKE_TOOL = r'''
import hashlib
import json
import os
import shutil
import sys

WATCHED = ('GH_TOKEN', 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', 'S3_ACCESS_KEY', 'S3_SECRET_KEY', 'S3_ENDPOINT',
           'S3_BUCKET', 'S3_REGION', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_DEFAULT_REGION',
           'AWS_CONFIG_FILE', 'AWS_SHARED_CREDENTIALS_FILE', 'AWS_EC2_METADATA_DISABLED',
           'AWS_REQUEST_CHECKSUM_CALCULATION', 'AWS_RESPONSE_CHECKSUM_VALIDATION')
tool, argv = sys.argv[1], sys.argv[2:]
entry = {'tool': tool, 'argv': argv, 'env': sorted(name for name in WATCHED if name in os.environ)}


def finish(code=0, out='', err=''):
    with open(os.environ['FAKE_LOG'], 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry) + '\n')
    sys.stdout.write(out)
    sys.stderr.write(err)
    sys.exit(code)


if tool == 'gh':
    state = os.environ.get('FAKE_GH_STATE', 'absent')
    if argv[:2] == ['release', 'view']:
        if state == 'absent':
            finish(1, err='release not found\n')
        if state == 'error':
            finish(1, err='HTTP 502: Bad Gateway (https://api.github.com/graphql)\n')
        assets = json.loads(os.environ['FAKE_GH_ASSETS'])
        if state == 'published-other':
            assets[0]['size'] += 1
        finish(out=json.dumps({'isDraft': state == 'draft', 'assets': [] if state == 'draft' else assets}))
    if argv[:2] == ['release', 'delete']:
        finish()
    if argv[:2] == ['release', 'download']:
        source = os.environ.get('FAKE_GH_DOWNLOAD')
        if not source:
            finish(1, err='HTTP 503: Service Unavailable\n')
        for asset in json.loads(os.environ['FAKE_GH_ASSETS']):
            shutil.copy(os.path.join(source, asset['name']), argv[argv.index('--dir') + 1])
        finish()
    if argv[:2] == ['release', 'create']:
        with open(argv[argv.index('--notes-file') + 1], encoding='utf-8') as f:
            entry['notes'] = f.read()
        finish(out=f"https://github.com/{argv[argv.index('--repo') + 1]}/releases/tag/{argv[2]}\n")
    finish(2, err='fake gh: unexpected call\n')

if tool == 'git':
    if argv[:3] == ['ls-remote', '--tags', '--refs'] and len(argv) == 5:
        entry['prompt'] = os.environ.get('GIT_TERMINAL_PROMPT')
        if os.environ.get('FAKE_GIT_TAGS') == 'error':
            finish(128, err="fatal: unable to access 'https://github.com/go-vikunja/app/': timed out\n")
        finish(out=''.join(f'{"c" * 40}\trefs/tags/{name}\n' for name in os.environ.get('FAKE_GIT_TAGS', '').split()))
    if argv[:1] == ['ls-remote'] and len(argv) == 4:
        entry['prompt'] = os.environ.get('GIT_TERMINAL_PROMPT')
        ref, built, other = argv[2], os.environ.get('GITHUB_SHA', ''), 'e' * 40
        lines = {'built': [(built, ref)], 'annotated': [('d' * 40, ref), (built, ref + '^{}')],
                 'moved': [(other, ref)], 'moved-annotated': [(built, ref), (other, ref + '^{}')],
                 'absent': []}
        state = os.environ.get('FAKE_GIT_TAG', 'built')
        if state == 'error':
            finish(128, err="fatal: unable to access 'https://github.com/go-vikunja/app/': timed out\n")
        finish(out=''.join(f'{sha}\t{name}\n' for sha, name in lines[state]))
    finish(2, err='fake git: unexpected call\n')

entry['credentials'] = [hashlib.sha256(os.environ.get(name, '').encode()).hexdigest()
                        for name in ('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_DEFAULT_REGION')]
entry['settings'] = {name: os.environ.get(name) for name in (
    'AWS_SHARED_CREDENTIALS_FILE', 'AWS_EC2_METADATA_DISABLED', 'AWS_REQUEST_CHECKSUM_CALCULATION',
    'AWS_RESPONSE_CHECKSUM_VALIDATION')}
if os.environ.get('AWS_CONFIG_FILE'):
    entry['config_mode'] = os.stat(os.environ['AWS_CONFIG_FILE']).st_mode & 0o777
    with open(os.environ['AWS_CONFIG_FILE'], encoding='utf-8') as f:
        entry['config'] = f.read()
state = os.environ.get('FAKE_S3_STATE', 'absent')
operation = argv[3] if len(argv) > 3 and argv[0] == '--endpoint-url' and argv[2] == 's3api' else None
if operation == 'head-object':
    if state == 'absent':
        finish(254, err='\nAn error occurred (404) when calling the HeadObject operation: Not Found\n')
    if state == 'forbidden':
        finish(254, err='\nAn error occurred (403) when calling the HeadObject operation: Forbidden\n')
    key = argv[argv.index('--key') + 1]
    finish(out=(json.loads(os.environ['FAKE_S3_SHA256'])[key] if state == 'same' else '0' * 64) + '\n')
if operation == 'put-object':
    finish(out='{"ETag": "\\"0\\""}\n')
finish(2, err='fake aws: unexpected call\n')
'''


def write(path, data):
    with open(path, 'wb') as f:
        f.write(data)
    return hashlib.sha256(data).hexdigest()


def whats_new(version_code):
    """The repository's release notes of version_code, as Play gets them."""
    notes = []
    for language in sorted(os.listdir(METADATA)):
        path = os.path.join(METADATA, language, 'changelogs', f'{version_code}.txt')
        if os.path.isfile(path):
            with open(path, encoding='utf-8') as f:
                notes.append({'language': language, 'text': f.read().strip()})
    return notes


def write_env(path, values):
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(f'{key}={value}\n' for key, value in values.items())


def make_release(root, tag, signing='release', not_releasable=''):
    """build/release/{unsigned,signed} as release_build.sh and
    release_sign.sh leave them, with small fake files."""
    name, number, channel = release_version(tag)
    unsigned = os.path.join(root, 'unsigned')
    signed = os.path.join(root, 'signed')
    os.makedirs(unsigned)
    os.makedirs(signed)
    desugar = b'desugar_jdk_libs source'
    values = {
        'TAG': tag, 'BUILD_NAME': name, 'BUILD_NUMBER': str(number),
        'CHANNEL': channel, 'SOURCE_URL': f'https://github.com/go-vikunja/app/tree/{tag}',
        'DESUGAR_ARCHIVE': DESUGAR, 'DESUGAR_COMMIT': COMMIT,
        'UNSIGNED_AAB_SHA256': write(os.path.join(unsigned, 'app-release.aab'), b'unsigned bundle ' + tag.encode()),
        'UNSIGNED_APK_SHA256': write(os.path.join(unsigned, 'app-release.apk'), b'unsigned apk ' + tag.encode()),
        **{f'UNSIGNED_APK_{abi_key(abi)}_SHA256': write(os.path.join(unsigned, f'app-{abi}-release.apk'),
                                                         f'unsigned {abi} apk {tag}'.encode()) for abi in ABIS},
        'DESUGAR_ARCHIVE_SHA256': write(os.path.join(unsigned, DESUGAR), desugar),
        'DRY_RUN': '0', 'NOT_RELEASABLE': not_releasable,
    }
    write_env(os.path.join(unsigned, 'release.env'), values)
    apk = f'vikunja-app-{name}.apk'
    apk_sha256 = write(os.path.join(signed, apk), b'signed apk ' + tag.encode())
    abi_sha256 = {f'APK_{abi_key(abi)}_SHA256': write(os.path.join(signed, f'vikunja-app-{name}-{abi}.apk'),
                                                      f'signed {abi} apk {tag}'.encode()) for abi in ABIS}
    write(os.path.join(signed, DESUGAR), desugar)
    with open(os.path.join(signed, 'SHA256SUMS'), 'w', encoding='utf-8') as f:
        f.write(f'{apk_sha256}  {apk}\n')
        f.writelines(f'{abi_sha256[f"APK_{abi_key(abi)}_SHA256"]}  vikunja-app-{name}-{abi}.apk\n' for abi in ABIS)
        f.write(f'{values["DESUGAR_ARCHIVE_SHA256"]}  {DESUGAR}\n')
    values.update({
        'APK_FILE': apk, 'APK_SHA256': apk_sha256, **abi_sha256,
        'AAB_SHA256': write(os.path.join(signed, 'app-release.aab'), b'signed bundle ' + tag.encode()),
        'UPLOAD_CERT_SHA256': CERTIFICATE, 'APK_CERT_SHA256': CERTIFICATE, 'APK_SET': 'upload', 'SIGNING': signing,
    })
    write_env(os.path.join(signed, 'release.env'), values)
    return values


def edit_env(path, **changes):
    with open(path, encoding='utf-8') as f:
        lines = f.read().splitlines()
    lines = [f'{line.split("=", 1)[0]}={changes[line.split("=", 1)[0]]}' if line.split('=', 1)[0] in changes
             else line for line in lines]
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


class Fixture(unittest.TestCase):
    TAG = 'v1.0.0-beta.1'

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        for directory in ('home', 'temp', 'bin', 'release'):
            os.mkdir(os.path.join(self.tmp, directory))
        self.temp = os.path.join(self.tmp, 'temp')
        self.root = os.path.join(self.tmp, 'release')
        self.log = os.path.join(self.tmp, 'calls.jsonl')
        fake = os.path.join(self.tmp, 'fake_tool.py')
        with open(fake, 'w', encoding='utf-8') as f:
            f.write(FAKE_TOOL)
        for tool in ('gh', 'aws', 'git'):
            path = os.path.join(self.tmp, 'bin', tool)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(f'#!/bin/sh\nexec "{sys.executable}" -I "{fake}" {tool} "$@"\n')
            os.chmod(path, 0o755)
        self.values = make_release(self.root, self.TAG)
        self.signed = os.path.join(self.root, 'signed')

    def official(self, **extra):
        return {**OFFICIAL, 'GITHUB_REF_NAME': self.TAG, 'GITHUB_SHA': BUILT, **extra}

    def publish(self, *arguments, env=None):
        full = {'PATH': os.path.join(self.tmp, 'bin') + os.pathsep + os.environ.get('PATH', os.defpath),
                'HOME': os.path.join(self.tmp, 'home'), 'TMPDIR': self.temp, 'VIKUNJA_APP_RELEASE_DIR': self.root,
                'FAKE_LOG': self.log, 'no_proxy': '*'}
        full.update(env or {})
        result = subprocess.run(['bash', SCRIPT, *arguments], env=full, capture_output=True, text=True, timeout=120)
        self.assertEqual(os.listdir(self.temp), [], 'the work directory is left behind')
        for name in ('S3_ACCESS_KEY', 'S3_SECRET_KEY', 'GH_TOKEN'):
            if full.get(name):
                self.assertNotIn(full[name], result.stdout + result.stderr)
        return result

    def forget_calls(self):
        if os.path.exists(self.log):
            os.remove(self.log)

    def calls(self, tool=None):
        if not os.path.exists(self.log):
            return []
        with open(self.log, encoding='utf-8') as f:
            calls = [json.loads(line) for line in f]
        return [call for call in calls if tool is None or call['tool'] == tool]

    def not_published(self, result):
        lines = [line for line in (result.stdout + result.stderr).splitlines() if line.startswith('Not published: ')]
        self.assertEqual(len(lines), 1, result.stdout + result.stderr)
        return lines[0][len('Not published: '):]


class GuardTest(Fixture):
    def test_dry_run_outside_github_actions(self):
        for step in ('check', 'play', 'dl', 'github'):
            with self.subTest(step=step):
                result = self.publish('--dry-run', step)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('Would ', result.stdout)
                self.assertEqual(self.not_published(result),
                                 'not a tag run of go-vikunja/app on GitHub Actions; '
                                 'GITHUB_REF_NAME (unset) is not v1.0.0-beta.1; --dry-run')
        self.assertEqual(self.calls(), [])

    def test_fails_outside_github_actions_without_dry_run(self):
        for step in ('check', 'play', 'dl', 'github'):
            with self.subTest(step=step):
                result = self.publish(step, env={**S3, 'GH_TOKEN': GH_TOKEN,
                                                 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': '{"private_key": "x"}'})
                self.assertEqual(result.returncode, 1)
                self.assertIn('Would ', result.stdout)
                self.assertIn('Not published: not a tag run of go-vikunja/app on GitHub Actions', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_throwaway_keys_in_the_official_repository(self):
        edit_env(os.path.join(self.signed, 'release.env'), SIGNING='throwaway')
        env = self.official(**S3, GH_TOKEN=GH_TOKEN, GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='{"private_key": "x"}')
        for step in ('play', 'dl', 'github'):
            with self.subTest(step=step):
                result = self.publish(step, env=env)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.not_published(result), 'signed with throwaway keys')
        self.assertEqual(self.calls(), [])

    def test_other_repositories_and_refs(self):
        cases = [
            ({'GITHUB_REPOSITORY_ID': '1'}, 'not a tag run of go-vikunja/app on GitHub Actions'),
            ({'GITHUB_REPOSITORY': 'someone/app'}, 'not a tag run of go-vikunja/app on GitHub Actions'),
            ({'GITHUB_REF_TYPE': 'branch'}, 'not a tag run of go-vikunja/app on GitHub Actions'),
            ({'GITHUB_ACTIONS': 'false'}, 'not a tag run of go-vikunja/app on GitHub Actions'),
            ({'GITHUB_REF_NAME': 'v9.9.9'}, 'GITHUB_REF_NAME (v9.9.9) is not v1.0.0-beta.1'),
        ]
        for change, reason in cases:
            for step in ('check', 'dl', 'github'):
                with self.subTest(change=change, step=step):
                    result = self.publish(step, env=self.official(**change, **S3, GH_TOKEN=GH_TOKEN,
                                                                  **{f'HAS_{name}': 'true' for name in SECRETS}))
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(self.not_published(result), reason)
        self.assertEqual(self.calls(), [])

    def test_throwaway_keys_named_once(self):
        edit_env(os.path.join(self.signed, 'release.env'), SIGNING='throwaway',
                 NOT_RELEASABLE='placeholder source URL; throwaway keys')
        result = self.publish('--dry-run', 'dl', env=self.official())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.not_published(result), 'placeholder source URL; throwaway keys; --dry-run')

    def test_not_a_tag_run_named_once(self):
        built = 'not a tag run of go-vikunja/app on GitHub Actions'
        signed = f'{built}; throwaway keys; no committed certificate fingerprints (tool/ci/release_certificates.txt)'
        edit_env(os.path.join(self.root, 'unsigned', 'release.env'), NOT_RELEASABLE=built)
        edit_env(os.path.join(self.signed, 'release.env'), SIGNING='throwaway', NOT_RELEASABLE=signed)
        env = self.official(GITHUB_REPOSITORY='someone/app')
        for step, expected in (('check', built), ('play', signed), ('dl', signed), ('github', signed)):
            with self.subTest(step=step):
                result = self.publish('--dry-run', step, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.not_published(result), f'{expected}; --dry-run')

    def test_the_cause_comes_first(self):
        edit_env(os.path.join(self.signed, 'release.env'),
                 NOT_RELEASABLE='not a tag run of go-vikunja/app on GitHub Actions; placeholder source URL')
        result = self.publish('--dry-run', 'dl')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.not_published(result),
                         'not a tag run of go-vikunja/app on GitHub Actions; placeholder source URL; '
                         'GITHUB_REF_NAME (unset) is not v1.0.0-beta.1; --dry-run')

    def test_not_releasable_build(self):
        edit_env(os.path.join(self.signed, 'release.env'), NOT_RELEASABLE='placeholder source URL; throwaway keys')
        result = self.publish('github', env=self.official(GH_TOKEN=GH_TOKEN))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.not_published(result), 'placeholder source URL; throwaway keys')
        self.assertEqual(self.calls(), [])

    def test_usage(self):
        for arguments in ((), ('publish',), ('--dry-run',), ('play', '--dry-run'), ('--dry-run', 'dl', 'github')):
            with self.subTest(arguments=arguments):
                result = self.publish(*arguments)
                self.assertEqual(result.returncode, 2)
                self.assertIn('usage: tool/ci/release_publish.sh [--dry-run] scope|check|play|dl|github',
                              result.stderr)


class ValidationTest(Fixture):
    def assert_refused(self, step, text, dry_run=True):
        result = self.publish(*(['--dry-run'] if dry_run else []), step,
                              env=self.official(**S3, GH_TOKEN=GH_TOKEN))
        self.assertEqual(result.returncode, 1)
        self.assertIn(text, result.stderr)
        self.assertNotIn('Would ', result.stdout)
        self.assertEqual(self.calls(), [])

    def test_tampered_files(self):
        with open(os.path.join(self.signed, f'vikunja-app-{self.TAG[1:]}.apk'), 'ab') as f:
            f.write(b'!')
        self.assert_refused('dl', 'does not have the SHA-256 that APK_SHA256', dry_run=False)
        self.assert_refused('github', 'does not have the SHA-256 that APK_SHA256')
        with open(os.path.join(self.root, 'unsigned', 'app-release.aab'), 'ab') as f:
            f.write(b'!')
        self.assert_refused('check', 'does not have the SHA-256 that UNSIGNED_AAB_SHA256')

    def test_tampered_per_abi_files(self):
        with open(os.path.join(self.signed, 'vikunja-app-1.0.0-beta.1-arm64-v8a.apk'), 'ab') as f:
            f.write(b'!')
        self.assert_refused('dl', 'does not have the SHA-256 that APK_ARM64_V8A_SHA256', dry_run=False)
        with open(os.path.join(self.root, 'unsigned', 'app-x86_64-release.apk'), 'ab') as f:
            f.write(b'!')
        self.assert_refused('check', 'does not have the SHA-256 that UNSIGNED_APK_X86_64_SHA256')

    def test_missing_file(self):
        os.remove(os.path.join(self.signed, DESUGAR))
        self.assert_refused('github', f'{DESUGAR} is missing')
        os.remove(os.path.join(self.root, 'unsigned', 'app-armeabi-v7a-release.apk'))
        self.assert_refused('check', 'app-armeabi-v7a-release.apk is missing')

    def test_sha256sums_must_list_every_file(self):
        path = os.path.join(self.signed, 'SHA256SUMS')
        with open(path, encoding='utf-8') as f:
            listed = f.read()
        with open(path, 'a', encoding='utf-8') as f:
            f.write(f'{"0" * 64}  app-release.aab\n')
        self.assert_refused('github', 'SHA256SUMS does not list exactly')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(''.join(line for line in listed.splitlines(keepends=True) if 'x86_64' not in line))
        self.assert_refused('github', 'SHA256SUMS does not list exactly')

    def test_inconsistent_values(self):
        env_file = os.path.join(self.signed, 'release.env')
        for change, text in (({'BUILD_NUMBER': '1000002'}, 'do not belong to v1.0.0-beta.1'),
                             ({'CHANNEL': 'final'}, 'do not belong to v1.0.0-beta.1'),
                             ({'BUILD_NAME': '1.0.0'}, 'do not belong to v1.0.0-beta.1'),
                             ({'TAG': 'v1.0'}, 'TAG (v1.0) is not a release tag'),
                             ({'TAG': 'v1.0.0-beta.01'}, 'is not a release tag'),
                             ({'APK_FILE': 'other.apk'}, 'APK_FILE is not vikunja-app-1.0.0-beta.1.apk'),
                             ({'SIGNING': 'maybe'}, 'SIGNING is neither release nor throwaway'),
                             ({'APK_CERT_SHA256': 'abc'}, 'APK_CERT_SHA256 is not a SHA-256'),
                             ({'DESUGAR_ARCHIVE': '../x.tar.gz'}, 'is malformed'),
                             ({'SOURCE_URL': 'http://example.com/tree/v1.0.0-beta.1'}, 'is malformed')):
            with self.subTest(change=change):
                shutil.copy(env_file, env_file + '.orig')
                edit_env(env_file, **change)
                self.assert_refused('play', text)
                shutil.move(env_file + '.orig', env_file)

    def test_missing_release_env(self):
        os.remove(os.path.join(self.signed, 'release.env'))
        self.assert_refused('dl', 'signed/release.env is missing')


class VersionSchemeTest(Fixture):
    def test_bash_agrees_with_release_version_py(self):
        # release_publish.sh computes the scheme again in Bash on purpose;
        # a change in one language alone fails here.
        for tag in ('v0.0.1-beta.1', 'v1.2.3', 'v12.34.56-beta.98', 'v2099.99.99'):
            with self.subTest(tag=tag):
                root = os.path.join(self.tmp, tag)
                values = make_release(root, tag)
                env = {'VIKUNJA_APP_RELEASE_DIR': root}
                accepted = self.publish('--dry-run', 'dl', env=env)
                self.assertEqual(accepted.returncode, 0, accepted.stderr)
                self.assertIn('Not published: ', accepted.stdout)
                edit_env(os.path.join(root, 'signed', 'release.env'),
                         BUILD_NUMBER=str(int(values['BUILD_NUMBER']) + 1))
                refused = self.publish('--dry-run', 'dl', env=env)
                self.assertEqual(refused.returncode, 1)
                self.assertIn(f'do not belong to {tag}', refused.stderr)


class CheckTest(Fixture):
    def check(self, *arguments, **has):
        env = self.official(**{f'HAS_{name}': 'true' for name in SECRETS})
        env.update({f'HAS_{name}': value for name, value in has.items()})
        return self.publish(*arguments, 'check', env=env)

    def test_all_secrets(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('This job releases v1.0.0-beta.1 (beta, versionCode 1000001):', result.stdout)
        self.assertIn('Google Play io.vikunja.app: track beta, status completed', result.stdout)
        self.assertIn('dl.vikunja.io: app/1.0.0-beta.1/vikunja-app-1.0.0-beta.1.apk', result.stdout)
        self.assertIn('GitHub release "Vikunja app 1.0.0-beta.1" in go-vikunja/app, a prerelease', result.stdout)
        self.assertIn('every secret this release needs', result.stdout)
        self.assertEqual(result.stderr, '')

    def test_reads_only_the_unsigned_release(self):
        shutil.rmtree(self.signed)
        self.assertEqual(self.check().returncode, 0)

    def test_no_signing_secrets_warns(self):
        result = self.check(KEYSTORE_BASE64='false', KEY_PROPERTIES='false', S3_BUCKET='false')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('no signing secrets for the job publish: this run signs\n'
                      'with throwaway keys, publishes nothing and fails at the publish step.', result.stderr)

    def test_half_a_signing_pair(self):
        result = self.check(KEY_PROPERTIES='false')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: secrets missing for the job publish: KEY_PROPERTIES, ', result.stderr)
        result = self.check(KEYSTORE_BASE64='')
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing for the job publish: KEYSTORE_BASE64, ', result.stderr)

    def test_publishing_secrets_required_with_the_keys(self):
        result = self.check(S3_BUCKET='false')
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing for the job publish: S3_BUCKET, ', result.stderr)
        result = self.check(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='True', S3_ENDPOINT='1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing for the job publish: GOOGLE_PLAY_SERVICE_ACCOUNT_JSON S3_ENDPOINT, ',
                      result.stderr)

    def test_the_region_is_optional(self):
        result = self.check(S3_REGION='false')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('S3_REGION is not set: dl uses us-east-1', result.stdout)
        self.assertNotIn('S3_REGION is not set', self.check().stdout)

    def test_apk_pair_both_or_neither(self):
        self.assertEqual(self.check(APK_KEYSTORE_BASE64='false', APK_KEY_PROPERTIES='false').returncode, 0)
        result = self.check(APK_KEY_PROPERTIES='false')
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing for the job publish: APK_KEY_PROPERTIES, ', result.stderr)
        result = self.check(APK_KEYSTORE_BASE64='false')
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing for the job publish: APK_KEYSTORE_BASE64, ', result.stderr)

    def test_outside_the_official_repository(self):
        result = self.publish('check', env={f'HAS_{name}': 'true' for name in SECRETS})
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('every secret', result.stdout)

    def test_dry_run_lists_the_secrets_and_the_guard(self):
        result = self.publish('--dry-run', 'check')
        self.assertEqual(result.returncode, 0, result.stderr)
        listed = [line.split()[0] for line in result.stdout.splitlines()
                  if line.startswith('  ') and line.split()[0].isupper()]
        self.assertEqual(listed, list(SECRETS))
        self.assertIn('VIKUNJA_APP_PLAY_ROLLOUT', result.stdout)
        self.assertIn('Guard: GITHUB_ACTIONS=unset GITHUB_REPOSITORY=unset', result.stdout)
        self.assertIn('not official', result.stdout)

    def test_dry_run_in_the_official_repository(self):
        result = self.check('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('  a tag run of go-vikunja/app (id 395095540) on GitHub Actions', result.stdout)
        self.assertEqual(self.not_published(result), '--dry-run')


class ScopeTest(Fixture):
    def scope(self, *arguments, **env):
        return self.publish(*arguments, 'scope', env=self.official(**env))

    def test_needs_no_release(self):
        shutil.rmtree(self.root)
        os.mkdir(self.root)
        result = self.scope(OUTSIDE_RELEASE_ENVIRONMENT='false')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'No release secret is readable outside the environment release.\n')
        self.assertEqual(self.calls(), [])

    def test_a_repository_or_organisation_copy_fails_a_final_tag(self):
        for tag in ('v1.0.0', 'v1.2.1', 'v1.0', 'v1.0.0+1', 'release-1', '', 'v1.0.1-beta.1', 'v1.1.0-beta.1',
                    'v2.0.0-rc.1', 'v10.0.0-beta.1'):
            with self.subTest(tag=tag):
                summary = os.path.join(self.tmp, 'summary.md')
                result = self.scope(OUTSIDE_RELEASE_ENVIRONMENT='true', GITHUB_REF_NAME=tag,
                                    GITHUB_STEP_SUMMARY=summary)
                self.assertEqual(result.returncode, 1)
                message = ' '.join(result.stderr.split())
                self.assertIn(f'go-vikunja/app can read {", ".join(CREDENTIALS[:-1])} or {CREDENTIALS[-1]} '
                              'as a repository or organisation secret', message)
                self.assertIn('is no pre-release tag of 1.0.0 or 0.x', message)
                self.assertIn('remove the repository from the access list of organisation secrets', message)
                self.assertNotIn('::warning', result.stdout)
                self.assertFalse(os.path.exists(summary))
        self.assertEqual(self.calls(), [])

    def test_a_repository_or_organisation_copy_warns_on_a_pre_release_tag(self):
        for tag in ('v1.0.0-beta.1', 'v1.0.0-beta.12', 'v1.0.0-rc.1', 'v0.9.0-beta.1'):
            with self.subTest(tag=tag):
                summary = os.path.join(self.tmp, f'summary-{tag}.md')
                result = self.scope(OUTSIDE_RELEASE_ENVIRONMENT='true', GITHUB_REF_NAME=tag,
                                    GITHUB_STEP_SUMMARY=summary)
                self.assertEqual(result.returncode, 0, result.stderr)
                (line,) = result.stdout.splitlines()
                self.assertTrue(line.startswith('::warning title=Release secrets outside the environment release::'
                                                'go-vikunja/app can read KEYSTORE_BASE64, '), line)
                self.assertIn(f'Allowed for the pre-release tag {tag} until the first final release', line)
                self.assertIn('v1.0.0 and every tag after it fail', line)
                with open(summary, encoding='utf-8') as f:
                    self.assertEqual(f.read(), f'**Warning:** {line.split("::", 2)[2]}\n')
        self.assertEqual(self.calls(), [])

    def test_no_copy_passes_any_tag(self):
        for tag in ('v1.0.0', 'v1.0.0-beta.1'):
            with self.subTest(tag=tag):
                result = self.scope(OUTSIDE_RELEASE_ENVIRONMENT='false', GITHUB_REF_NAME=tag)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, 'No release secret is readable outside the environment release.\n')

    def test_fails_closed(self):
        for value in (None, '', 'True', '1', 'false '):
            for tag in ('v1.0.0', 'v1.0.0-beta.1'):
                with self.subTest(value=value, tag=tag):
                    env = {'GITHUB_REF_NAME': tag}
                    if value is not None:
                        env['OUTSIDE_RELEASE_ENVIRONMENT'] = value
                    result = self.scope(**env)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn('not true or false', result.stderr)

    def test_dry_run(self):
        result = self.publish('--dry-run', 'scope')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Would check that no KEYSTORE_BASE64, ', result.stdout)
        self.assertIn(' is a repository or organisation secret of go-vikunja/app: while one is, a pre-release tag of'
                      ' 1.0.0 or 0.x warns and any other tag fails.', result.stdout)


class TagTest(Fixture):
    LS_REMOTE = ['ls-remote', 'https://github.com/go-vikunja/app', 'refs/tags/v1.0.0-beta.1',
                 'refs/tags/v1.0.0-beta.1^{}']

    def run_step(self, step, **env):
        assets = [{'name': name, 'size': os.path.getsize(os.path.join(self.signed, name))}
                  for name in (*apk_files(self.TAG[1:]), 'SHA256SUMS', DESUGAR)]
        return self.publish(step, env=self.official(
            **{f'HAS_{name}': 'true' for name in SECRETS}, GH_TOKEN=GH_TOKEN, FAKE_GH_ASSETS=json.dumps(assets),
            **env))

    def test_the_tag_at_the_built_commit(self):
        for state in ('built', 'annotated'):
            for step in ('check', 'github'):
                with self.subTest(state=state, step=step):
                    self.forget_calls()
                    result = self.run_step(step, FAKE_GIT_TAG=state)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(f'The tag v1.0.0-beta.1 still points at the built commit {BUILT}.', result.stdout)
                    (call,) = self.calls('git')
                    self.assertEqual(call['argv'], self.LS_REMOTE)
                    self.assertEqual(call['prompt'], '0')

    def test_a_moved_or_missing_tag_fails(self):
        for state, tagged in (('moved', OTHER_COMMIT), ('moved-annotated', OTHER_COMMIT), ('absent', 'nothing')):
            for step in ('check', 'github'):
                with self.subTest(state=state, step=step):
                    self.forget_calls()
                    result = self.run_step(step, FAKE_GIT_TAG=state)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn(f'error: the tag v1.0.0-beta.1 points at {tagged} in go-vikunja/app, not at {BUILT},'
                                  ' the commit this run built', result.stderr)
                    self.assertNotIn('every secret', result.stdout)
                    self.assertEqual(self.calls('gh'), [])

    def test_ls_remote_errors_fail(self):
        result = self.run_step('github', FAKE_GIT_TAG='error')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: git ls-remote failed:\n  fatal: unable to access', result.stderr)
        self.assertEqual(self.calls('gh'), [])

    def test_needs_the_built_commit(self):
        for value in ('', 'v1.0.0-beta.1', BUILT[:12]):
            with self.subTest(value=value):
                result = self.run_step('check', GITHUB_SHA=value)
                self.assertEqual(result.returncode, 1)
                self.assertIn('is not a commit id', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_dl_does_not_look(self):
        result = self.run_step('dl', FAKE_GIT_TAG='moved', **S3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls('git'), [])


class FinalCheckTest(Fixture):
    TAG = 'v1.0.0'

    def test_plan(self):
        result = self.publish('check', env=self.official(**{f'HAS_{name}': 'true' for name in SECRETS}))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('This job releases v1.0.0 (final, versionCode 1000099):', result.stdout)
        self.assertIn('track production, staged rollout (inProgress) to a user fraction of VIKUNJA_APP_PLAY_ROLLOUT',
                      result.stdout)
        self.assertIn('GitHub release "Vikunja app 1.0.0" in go-vikunja/app, marked latest', result.stdout)


class DlTest(Fixture):
    def dl(self, *arguments, **env):
        return self.publish(*arguments, 'dl', env=self.official(**{**S3, **env}))

    def test_absent_is_uploaded(self):
        result = self.dl()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls('aws')
        self.assertEqual(len(calls), 2 * len(apk_files('1.0.0-beta.1')))
        for index, name in enumerate(apk_files('1.0.0-beta.1')):
            key = f'app/1.0.0-beta.1/{name}'
            sha256 = self.values['APK_SHA256' if index == 0 else f'APK_{abi_key(ABIS[index - 1])}_SHA256']
            with self.subTest(name):
                self.assertIn(f'Published the APK on dl.vikunja.io: {key}', result.stdout)
                head, put = calls[2 * index:2 * index + 2]
                self.assertEqual(head['argv'], ['--endpoint-url', 'https://s3.example.test', 's3api', 'head-object',
                                                '--bucket', S3['S3_BUCKET'], '--key', key, '--query',
                                                'Metadata.sha256', '--output', 'text'])
                self.assertEqual(put['argv'], ['--endpoint-url', 'https://s3.example.test', 's3api', 'put-object',
                                               '--bucket', S3['S3_BUCKET'], '--key', key,
                                               '--body', os.path.join(self.signed, name),
                                               '--content-type', APK_TYPE, '--metadata', f'sha256={sha256}'])
        for call in calls:
            self.assertEqual(call['credentials'], [hashlib.sha256(S3[name].encode()).hexdigest()
                                                   for name in ('S3_ACCESS_KEY', 'S3_SECRET_KEY', 'S3_REGION')])
            self.assertEqual(call['settings'], {
                'AWS_SHARED_CREDENTIALS_FILE': '/dev/null', 'AWS_EC2_METADATA_DISABLED': 'true',
                'AWS_REQUEST_CHECKSUM_CALCULATION': 'when_required',
                'AWS_RESPONSE_CHECKSUM_VALIDATION': 'when_required'})
            self.assertEqual(call['config'], '[default]\ns3 =\n    addressing_style = path\n')
            self.assertEqual(call['config_mode'], 0o600)
            self.assertFalse({name for name in call['env'] if name.startswith('S3_') or name.startswith('GOOGLE')})

    def test_same_is_skipped(self):
        name = '1.0.0-beta.1'
        published = {f'app/{name}/{file}': value for file, value in zip(
            apk_files(name), [self.values['APK_SHA256'], *(self.values[f'APK_{abi_key(abi)}_SHA256'] for abi in ABIS)])}
        result = self.dl(FAKE_S3_STATE='same', FAKE_S3_SHA256=json.dumps(published))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('already published'), len(published))
        self.assertEqual([call['argv'][3] for call in self.calls('aws')], ['head-object'] * len(published))

    def test_other_content_fails(self):
        result = self.dl(FAKE_S3_STATE='other')
        self.assertEqual(result.returncode, 1)
        self.assertIn(f'with the SHA-256 metadata {"0" * 64}, not {self.values["APK_SHA256"]}', result.stderr)
        self.assertIn("'Re-run failed jobs' keeps the build", result.stderr)
        self.assertEqual([call['argv'][3] for call in self.calls('aws')], ['head-object'])

    def test_other_errors_fail(self):
        result = self.dl(FAKE_S3_STATE='forbidden')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: aws s3api head-object failed:\n', result.stderr)
        self.assertIn('An error occurred (403) when calling the HeadObject operation: Forbidden', result.stderr)
        self.assertEqual(len(self.calls('aws')), 1)

    def test_endpoints(self):
        for endpoint, expected, path in (
                ('https://s3.example.test/', 'https://s3.example.test', False),
                ('HTTPS://S3.example.test//', 'https://S3.example.test', False),
                ('s3.example.test:9000/', 'https://s3.example.test:9000', False),
                ('https://acct.r2.cloudflarestorage.com/fake-dl-bucket', 'https://acct.r2.cloudflarestorage.com', True),
                ('https://s3.example.test:8443/x/y/', 'https://s3.example.test:8443', True),
                ('s3.example.test/fake-dl-bucket?x-id=1', 'https://s3.example.test', True),
                ('https://s3.example.test#x', 'https://s3.example.test', True)):
            with self.subTest(endpoint=endpoint):
                self.forget_calls()
                result = self.dl(S3_ENDPOINT=endpoint)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual({call['argv'][1] for call in self.calls('aws')}, {expected})
                self.assertEqual({call['argv'][5] for call in self.calls('aws')}, {S3['S3_BUCKET']})
                self.assertEqual('only its host and port are used' in result.stdout, path)

    def test_plain_http_refused(self):
        for endpoint in ('http://s3.example.test', 'HTTP://s3.example.test', 'ftp://s3.example.test', 'https://',
                         'https:///fake-dl-bucket', 'https://user@s3.example.test', '/fake-dl-bucket'):
            with self.subTest(endpoint=endpoint):
                result = self.dl(S3_ENDPOINT=endpoint)
                self.assertEqual(result.returncode, 1)
                self.assertIn('S3_ENDPOINT', result.stderr)
                self.assertNotIn(endpoint, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [])

    def test_missing_secret(self):
        result = self.dl(S3_SECRET_KEY='', S3_BUCKET='')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: S3_SECRET_KEY S3_BUCKET not set', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_the_region_defaults_to_us_east_1(self):
        result = self.dl(S3_REGION='')
        self.assertEqual(result.returncode, 0, result.stderr)
        for call in self.calls('aws'):
            self.assertEqual(call['credentials'][2], hashlib.sha256(b'us-east-1').hexdigest())

    def test_dry_run_names_but_never_shows_the_bucket(self):
        result = self.dl('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--endpoint-url $S3_ENDPOINT s3api put-object --bucket $S3_BUCKET '
                      '--key app/1.0.0-beta.1/vikunja-app-1.0.0-beta.1.apk', result.stdout)
        self.assertIn(f'--content-type {APK_TYPE} --metadata sha256={self.values["APK_SHA256"]}', result.stdout)
        for abi in ABIS:
            self.assertIn(f'--key app/1.0.0-beta.1/vikunja-app-1.0.0-beta.1-{abi}.apk '
                          f'--body vikunja-app-1.0.0-beta.1-{abi}.apk --content-type {APK_TYPE} '
                          f'--metadata sha256={self.values[f"APK_{abi_key(abi)}_SHA256"]}', result.stdout)
        for value in S3.values():
            self.assertNotIn(value, result.stdout + result.stderr)
        result = self.publish('--dry-run', 'dl')
        self.assertIn('--endpoint-url <S3_ENDPOINT> s3api put-object --bucket <S3_BUCKET>', result.stdout)
        self.assertEqual(self.calls(), [])


class GithubTest(Fixture):
    def github(self, *arguments, **env):
        assets = [{'name': name, 'size': os.path.getsize(os.path.join(self.signed, name))}
                  for name in (*apk_files(self.TAG[1:]), 'SHA256SUMS', DESUGAR)]
        return self.publish(*arguments, 'github', env=self.official(**{
            'GH_TOKEN': GH_TOKEN, 'FAKE_GH_ASSETS': json.dumps(assets), 'FAKE_GH_DOWNLOAD': self.signed, **env}))

    def assert_created(self, create, prerelease, latest=True):
        tag = self.TAG
        flags = ['--prerelease', '--latest=false'] if prerelease else ['--latest' if latest else '--latest=false']
        notes = create['argv'][create['argv'].index('--notes-file') + 1]
        self.assertEqual(create['argv'], [
            'release', 'create', tag, '--repo', 'go-vikunja/app', '--verify-tag', '--title',
            f'Vikunja app {tag[1:]}', '--notes-file', notes, *flags,
            *(os.path.join(self.signed, name) for name in apk_files(tag[1:])), os.path.join(self.signed, 'SHA256SUMS'),
            os.path.join(self.signed, DESUGAR)])
        self.assertEqual(create['env'], ['GH_TOKEN'])
        return create['notes']

    def test_absent_is_created(self):
        result = self.github()
        self.assertEqual(result.returncode, 0, result.stderr)
        view, create = self.calls('gh')
        self.assertEqual(view['argv'], ['release', 'view', self.TAG, '--repo', 'go-vikunja/app',
                                        '--json', 'isDraft,assets'])
        notes = self.assert_created(create, prerelease=True)
        self.assertEqual(notes, '\n'.join([
            'Vikunja app 1.0.0-beta.1, a beta: it may still have rough edges.',
            '',
            f'- APK for every device `vikunja-app-1.0.0-beta.1.apk`, SHA-256 `{self.values["APK_SHA256"]}`',
            *(f'- APK for {abi} only `vikunja-app-1.0.0-beta.1-{abi}.apk`, '
              f'SHA-256 `{self.values[f"APK_{abi_key(abi)}_SHA256"]}`' for abi in ABIS),
            f'- APK signing certificate SHA-256 `{CERTIFICATE}`',
            '- Source code: https://github.com/go-vikunja/app/tree/v1.0.0-beta.1',
            f'- `{DESUGAR}`: the source code of desugar_jdk_libs at upstream commit {COMMIT} '
            '(GPL-2.0 with the Classpath exception), which the app contains',
            '',
            'An APK installed by hand gets no updates by itself. Most phones can take the smaller APK for '
            '`arm64-v8a`.',
        ]) + '\n')
        self.assertIn('Published the GitHub release: https://github.com/go-vikunja/app/releases/tag/v1.0.0-beta.1',
                      result.stdout)

    def test_draft_is_replaced(self):
        result = self.github(FAKE_GH_STATE='draft')
        self.assertEqual(result.returncode, 0, result.stderr)
        view, delete, create = self.calls('gh')
        self.assertEqual(delete['argv'], ['release', 'delete', self.TAG, '--repo', 'go-vikunja/app', '--yes'])
        self.assert_created(create, prerelease=True)

    def test_published_with_the_same_files_is_skipped(self):
        result = self.github(FAKE_GH_STATE='published-same')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('already published', result.stdout)
        view, download = self.calls('gh')
        self.assertEqual(download['argv'][:5], ['release', 'download', self.TAG, '--repo', 'go-vikunja/app'])
        self.assertEqual(download['argv'][5], '--dir')
        self.assertEqual(len(download['argv']), 7)

    def test_published_with_the_same_sizes_but_other_content_fails(self):
        for name in (*apk_files(self.TAG[1:]), 'SHA256SUMS', DESUGAR):
            with self.subTest(name=name):
                forged = os.path.join(self.tmp, 'forged-' + name)
                shutil.copytree(self.signed, forged)
                with open(os.path.join(forged, name), 'r+b') as f:
                    first = f.read(1)
                    f.seek(0)
                    f.write(bytes([first[0] ^ 1]))
                self.forget_calls()
                result = self.github(FAKE_GH_STATE='published-same', FAKE_GH_DOWNLOAD=forged)
                self.assertEqual(result.returncode, 1)
                self.assertIn(f'the GitHub release {self.TAG} has a {name} with other content', result.stderr)
                self.assertNotIn('already published', result.stdout)
                self.assertEqual([call['argv'][1] for call in self.calls('gh')], ['view', 'download'])

    def test_download_errors_fail(self):
        result = self.github(FAKE_GH_STATE='published-same', FAKE_GH_DOWNLOAD='')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: gh release download failed:\n  HTTP 503', result.stderr)
        self.assertEqual([call['argv'][1] for call in self.calls('gh')], ['view', 'download'])

    def test_published_with_other_files_fails(self):
        result = self.github(FAKE_GH_STATE='published-other')
        self.assertEqual(result.returncode, 1)
        self.assertIn('exists with other files', result.stderr)
        self.assertIn("'Re-run failed jobs' keeps the build", result.stderr)
        self.assertEqual(len(self.calls('gh')), 1)

    def test_view_errors_fail(self):
        result = self.github(FAKE_GH_STATE='error')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: gh release view failed:\n  HTTP 502', result.stderr)
        self.assertEqual(len(self.calls('gh')), 1)

    def test_needs_a_token(self):
        result = self.github(GH_TOKEN='')
        self.assertEqual(result.returncode, 1)
        self.assertIn('GH_TOKEN is not set', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_dry_run_prints_the_command_and_the_notes(self):
        result = self.publish('--dry-run', 'github')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('gh release create v1.0.0-beta.1 --repo <GITHUB_REPOSITORY> --verify-tag '
                      '--title "Vikunja app 1.0.0-beta.1" --notes-file notes.md --prerelease --latest=false '
                      f'{" ".join(apk_files("1.0.0-beta.1"))} SHA256SUMS {DESUGAR}', result.stdout)
        self.assertNotIn('higher final release tag', result.stdout)
        self.assertIn('  - Source code: https://github.com/go-vikunja/app/tree/v1.0.0-beta.1', result.stdout)
        self.assertEqual(self.calls(), [])


class FinalGithubTest(GithubTest):
    TAG = 'v1.0.0'

    def test_absent_is_created(self):
        result = self.github(FAKE_GIT_TAGS='v0.0.26-alpha v1.0.0-beta.2 v1.0.0 v1.1.0-beta.1')
        self.assertEqual(result.returncode, 0, result.stderr)
        notes = self.assert_created(self.calls('gh')[1], prerelease=False)
        self.assertTrue(notes.startswith('Vikunja app 1.0.0.\n\n'), notes)
        tags = self.calls('git')[1]
        self.assertEqual(tags['argv'], ['ls-remote', '--tags', '--refs', 'https://github.com/go-vikunja/app',
                                        'refs/tags/v*'])
        self.assertEqual(tags['prompt'], '0')
        self.assertNotIn('Not marked latest', result.stdout)

    def test_an_older_line_is_not_latest(self):
        for higher in ('v1.0.1', 'v1.1.0', 'v2.0.0'):
            with self.subTest(higher=higher):
                self.forget_calls()
                result = self.github(FAKE_GIT_TAGS=f'v1.0.0 {higher} v3.0.0-beta.1')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assert_created(self.calls('gh')[1], prerelease=False, latest=False)
                self.assertIn(f'Not marked latest: go-vikunja/app has the higher final release tag {higher}.',
                              result.stdout)

    def test_tag_listing_errors_fail(self):
        result = self.github(FAKE_GIT_TAGS='error')
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: git ls-remote failed:\n  fatal: unable to access', result.stderr)
        self.assertEqual([call['argv'][1] for call in self.calls('gh')], [])

    def test_draft_is_replaced(self):
        result = self.github(FAKE_GH_STATE='draft')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_created(self.calls('gh')[2], prerelease=False)

    def test_dry_run_prints_the_command_and_the_notes(self):
        result = self.publish('--dry-run', 'github')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--notes-file notes.md --latest vikunja-app-1.0.0.apk', result.stdout)
        self.assertIn('--latest=false instead if the repository has a higher final release tag', result.stdout)
        self.assertEqual(self.calls(), [])


class PlayDryRunTest(Fixture):
    def test_beta(self):
        result = self.publish('--dry-run', 'play')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Would upload app-release.aab to Google Play's beta track:", result.stdout)
        notes = whats_new(1000001)
        self.assertEqual([note['language'] for note in notes], ['de-DE', 'en-US'])
        self.assertIn(json.dumps({'track': 'beta', 'releases': [{
            'name': '1.0.0-beta.1', 'versionCodes': ['1000001'], 'status': 'completed', 'releaseNotes': notes}]}),
            result.stdout)
        self.assertNotIn('userFraction', result.stdout)

    def test_service_account_required(self):
        result = self.publish('play', env=self.official(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=''))
        self.assertEqual(result.returncode, 1)
        self.assertIn('error: GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is empty', result.stderr)


class FinalPlayDryRunTest(Fixture):
    TAG = 'v1.0.0'

    def test_rollout(self):
        for rollout, expected in (('0.25', '0.25'), ('0.05', '0.05'), ('', '0.1'), (None, '0.1')):
            with self.subTest(rollout=rollout):
                env = {} if rollout is None else {'VIKUNJA_APP_PLAY_ROLLOUT': rollout}
                result = self.publish('--dry-run', 'play', env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('"versionCodes": ["1000099"], "status": "inProgress", '
                              f'"userFraction": {expected}, "releaseNotes": {json.dumps(whats_new(1000099))}}}]',
                              result.stdout)

    def test_bad_rollout_refused(self):
        for rollout in ('1.5', 'abc', '1', '0', '0.0', '.5', '0.1 '):
            with self.subTest(rollout=rollout):
                result = self.publish('--dry-run', 'play', env={'VIKUNJA_APP_PLAY_ROLLOUT': rollout})
                self.assertEqual(result.returncode, 1)
                self.assertIn('VIKUNJA_APP_PLAY_ROLLOUT', result.stderr)
                self.assertNotIn('Would ', result.stdout)


class WhatsNewDryRunTest(Fixture):
    TAG = 'v9.9.9'

    def test_production_without_the_english_text_is_refused(self):
        result = self.publish('--dry-run', 'play')
        self.assertEqual(result.returncode, 1)
        self.assertIn("error: production needs Play's What's new in en-US, the default listing language: "
                      'fastlane/metadata/android/en-US/changelogs/9090999.txt is missing', result.stderr)
        self.assertNotIn('Would PUT', result.stdout)


class BetaWithoutWhatsNewDryRunTest(Fixture):
    TAG = 'v9.9.9-beta.1'

    def test_a_beta_goes_without(self):
        result = self.publish('--dry-run', 'play')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Would send no What's new: there is no "
                      'fastlane/metadata/android/<language>/changelogs/9090901.txt', result.stdout)
        self.assertIn('"status": "completed"}]}', result.stdout)


@unittest.skipUnless(OPENSSL, 'openssl is missing')
class PlayFixture(Fixture):
    @classmethod
    def setUpClass(cls):
        cls.keys = tempfile.mkdtemp()
        cls.private_key, cls.public_key = generate_key(cls.keys)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.keys)

    def play(self, fake, **env):
        account = json.dumps({'type': 'service_account', 'client_email': EMAIL, 'private_key': self.private_key,
                              'token_uri': fake.token_uri})
        result = self.publish('play', env=self.official(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=account,
                                                        VIKUNJA_APP_PLAY_API_ROOT=fake.root, **env))
        output = result.stdout + result.stderr
        for line in self.private_key.splitlines():
            if line and not line.startswith('-----'):
                self.assertNotIn(line, output)
        self.assertNotIn(fake.token, '\n'.join(line for line in output.splitlines()
                                              if not line.startswith('::add-mask::')))
        self.assertEqual(fake.token_problems, [])
        return result


class PlayTest(PlayFixture):
    def test_beta(self):
        fake = FakePlay(self.public_key, version_code=1000001)
        self.addCleanup(fake.close)
        result = self.play(fake)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(fake.kinds(), ['token', 'insert', 'track-get', 'upload', 'track-update', 'commit'])
        with open(os.path.join(self.signed, 'app-release.aab'), 'rb') as f:
            self.assertEqual(fake.request('upload')['body'], f.read())
        self.assertEqual(json.loads(fake.request('track-update')['body'])['releases'],
                         [{'name': '1.0.0-beta.1', 'versionCodes': ['1000001'], 'status': 'completed',
                           'releaseNotes': whats_new(1000001)}])
        self.assertIn("Committed versionCode 1000001 to beta (completed) with the What's new in de-DE, en-US",
                      result.stdout)


class FinalPlayTest(PlayFixture):
    TAG = 'v1.0.0'

    def test_staged_rollout(self):
        fake = FakePlay(self.public_key, version_code=1000099)
        self.addCleanup(fake.close)
        result = self.play(fake, VIKUNJA_APP_PLAY_ROLLOUT='0.25')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(fake.request('track-update')['body']), {
            'track': 'production',
            'releases': [{'name': '1.0.0', 'versionCodes': ['1000099'], 'status': 'inProgress', 'userFraction': 0.25,
                          'releaseNotes': whats_new(1000099)}]})


if __name__ == '__main__':
    unittest.main()
