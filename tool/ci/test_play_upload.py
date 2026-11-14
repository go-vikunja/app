"""Tests tool/ci/play_upload.py through its command line, against a fake token
endpoint and Play edits API on 127.0.0.1. The networked tests need openssl
for the per-run test key and are skipped without it."""
import base64
import hashlib
import http.server
import json
import os
import secrets
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(ROOT, 'tool/ci/play_upload.py')
OPENSSL = shutil.which('openssl')
PACKAGE = 'io.vikunja.app'
EMAIL = 'publisher@vikunja-app-test.iam.gserviceaccount.com'
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'
JWT_BEARER = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
EDIT = 'edit-1'
API = f'/androidpublisher/v3/applications/{PACKAGE}'
UPLOAD = f'/upload/androidpublisher/v3/applications/{PACKAGE}'
SIGNING_FAILED = "openssl could not sign with the service account's private_key"


def unb64url(text):
    return base64.urlsafe_b64decode(text + '=' * (-len(text) % 4))


def generate_key(directory):
    """(PEM of a new RSA private key, path of its public key)."""
    key = os.path.join(directory, 'key.pem')
    public = os.path.join(directory, 'public.pem')
    subprocess.run([OPENSSL, 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', key],
                   check=True, capture_output=True)
    subprocess.run([OPENSSL, 'pkey', '-in', key, '-pubout', '-out', public], check=True, capture_output=True)
    with open(key, encoding='ascii') as f:
        pem = f.read()
    os.remove(key)
    return pem, public


def write_service_account(path, token_uri, private_key, email=EMAIL):
    account = {'type': 'service_account', 'project_id': 'vikunja-app-test', 'private_key_id': 'abc',
               'private_key': private_key, 'client_email': email, 'token_uri': token_uri}
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w', encoding='utf-8') as f:
        json.dump(account, f)
    return json.dumps(account)


def run_script(arguments, home, extra_env=None):
    env = {'PATH': os.environ.get('PATH', os.defpath), 'HOME': home, 'TMPDIR': home, 'no_proxy': '*'}
    env.update(extra_env or {})
    return subprocess.run([sys.executable, '-I', SCRIPT, *arguments], env=env, capture_output=True, text=True,
                          timeout=120)


class LocalServer(http.server.ThreadingHTTPServer):
    # HTTPServer.server_bind looks up the host's name, which can take half a
    # minute on a Mac.
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]


class FakePlay:
    """The token endpoint and the Play edits API. Records every request;
    `tracks` holds each track's releases (a track not in it answers 404),
    `errors` maps a request kind to the (status, JSON) it answers."""

    def __init__(self, public_key=None, version_code=1000001):
        self.public_key = public_key
        self.token = 'ya29.fake-' + secrets.token_urlsafe(24)
        self.requests = []
        self.assertions = []
        self.token_problems = []
        self.tracks = {'beta': [], 'production': [{'name': '0.9.0', 'versionCodes': ['900099'],
                                                   'status': 'completed'}]}
        self.upload_version_code = version_code
        self.errors = {}
        self.server = LocalServer(('127.0.0.1', 0), self._handler())
        self.root = f'http://127.0.0.1:{self.server.server_address[1]}'
        self.token_uri = f'{self.root}/token'
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={'poll_interval': 0.05}, daemon=True)
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def kinds(self):
        return [request['kind'] for request in self.requests]

    def request(self, kind):
        matching = [request for request in self.requests if request['kind'] == kind]
        if len(matching) != 1:
            raise AssertionError(f'{len(matching)} {kind} requests: {self.kinds()}')
        return matching[0]

    def _handler(self):
        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def _answer(self):
                length = int(self.headers.get('Content-Length') or 0)
                body = self.rfile.read(length) if length else b''
                status, answer = fake.handle(self.command, self.path, self.headers, body)
                data = b'' if answer is None else json.dumps(answer).encode()
                self.send_response(status)
                if data:
                    self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            do_GET = do_POST = do_PUT = do_DELETE = _answer

        return Handler

    def _kind(self, method, path):
        edit = f'{API}/edits/{EDIT}'
        routes = {
            ('POST', '/token'): 'token',
            ('POST', f'{API}/edits'): 'insert',
            ('POST', f'{UPLOAD}/edits/{EDIT}/bundles?uploadType=media'): 'upload',
            ('POST', f'{edit}:commit'): 'commit',
            ('DELETE', edit): 'delete',
        }
        for track in ('beta', 'production'):
            routes[('GET', f'{edit}/tracks/{track}')] = 'track-get'
            routes[('PUT', f'{edit}/tracks/{track}')] = 'track-update'
        return routes.get((method, path), 'unknown')

    def handle(self, method, path, headers, body):
        kind = self._kind(method, path)
        self.requests.append({'kind': kind, 'method': method, 'path': path,
                              'content_type': headers.get('Content-Type'), 'body': body})
        if kind == 'token':
            return self._grant(body)
        if headers.get('Authorization') != f'Bearer {self.token}':
            return 401, {'error': {'code': 401, 'message': 'Request had invalid authentication credentials.'}}
        if kind in self.errors:
            return self.errors[kind]
        if kind == 'insert':
            return 200, {'id': EDIT, 'expiryTimeSeconds': str(int(time.time()) + 3600)}
        if kind == 'track-get':
            track = path.rsplit('/', 1)[1]
            if track not in self.tracks:
                return 404, {'error': {'code': 404, 'message': 'Track not found.'}}
            return 200, {'track': track, 'releases': self.tracks[track]}
        if kind == 'upload':
            return 200, {'versionCode': self.upload_version_code, 'sha256': hashlib.sha256(body).hexdigest()}
        if kind == 'track-update':
            return 200, json.loads(body)
        if kind == 'commit':
            return 200, {'id': EDIT}
        if kind == 'delete':
            return 204, None
        return 404, {'error': {'code': 404, 'message': f'no route for {method} {path}'}}

    def _grant(self, body):
        problems = []
        try:
            form = urllib.parse.parse_qs(body.decode('ascii'), strict_parsing=True)
            if form.get('grant_type') != [JWT_BEARER]:
                problems.append('grant_type')
            assertion = form['assertion'][0]
            self.assertions.append(assertion)
            parts = assertion.split('.')
            header, claims = (json.loads(unb64url(part)) for part in parts[:2])
            if len(parts) != 3 or '=' in assertion:
                problems.append('form')
            if header != {'alg': 'RS256', 'typ': 'JWT'}:
                problems.append('header')
            for name, value in (('iss', EMAIL), ('scope', SCOPE), ('aud', self.token_uri)):
                if claims.get(name) != value:
                    problems.append(name)
            if claims['exp'] - claims['iat'] != 3600 or abs(claims['iat'] - time.time()) > 300:
                problems.append('iat/exp')
            if self.public_key and not self._signature_ok(parts):
                problems.append('signature')
        except (KeyError, ValueError, TypeError):
            problems.append('malformed')
        if problems:
            self.token_problems.extend(problems)
            return 400, {'error': 'invalid_grant', 'error_description': 'Invalid JWT: ' + ', '.join(problems)}
        return 200, {'access_token': self.token, 'expires_in': 3599, 'token_type': 'Bearer'}

    def _signature_ok(self, parts):
        with tempfile.TemporaryDirectory() as directory:
            data = os.path.join(directory, 'data')
            signature = os.path.join(directory, 'signature')
            with open(data, 'wb') as f:
                f.write(f'{parts[0]}.{parts[1]}'.encode('ascii'))
            with open(signature, 'wb') as f:
                f.write(unb64url(parts[2]))
            return subprocess.run([OPENSSL, 'dgst', '-sha256', '-verify', self.public_key, '-signature', signature,
                                   data], capture_output=True).returncode == 0


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.bundle = os.path.join(self.tmp, 'app-release.aab')
        with open(self.bundle, 'wb') as f:
            f.write(secrets.token_bytes(4096))
        with open(self.bundle, 'rb') as f:
            self.bundle_bytes = f.read()

    def arguments(self, track='beta', version_code='1000001', name='1.0.0-beta.1', fraction=None,
                  api_root='https://androidpublisher.googleapis.com', account=None):
        arguments = ['--package', PACKAGE, '--bundle', self.bundle, '--version-code', version_code,
                     '--track', track, '--release-name', name, '--api-root', api_root]
        if fraction is not None:
            arguments += ['--user-fraction', fraction]
        if account is not None:
            arguments += ['--service-account-file', account]
        return arguments


class ArgumentTest(Fixture):
    def assert_usage_error(self, arguments, text):
        result = run_script(arguments, self.tmp)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn(text, result.stderr)
        self.assertEqual(result.stdout, '')

    def test_user_fraction_only_and_always_for_production(self):
        self.assert_usage_error(self.arguments(fraction='0.1') + ['--dry-run'], 'only for production')
        self.assert_usage_error(self.arguments(track='production', name='1.0.0') + ['--dry-run'],
                                'required for production')

    def test_user_fraction_strictly_between_0_and_1(self):
        for fraction in ('0', '1', '1.5', '-0.1', 'abc', 'nan', 'inf', ''):
            with self.subTest(fraction=fraction):
                self.assert_usage_error(self.arguments(track='production', fraction=fraction) + ['--dry-run'],
                                        'strictly between 0 and 1')

    def test_plain_http_only_to_this_machine(self):
        for root in ('http://androidpublisher.googleapis.com', 'http://127.0.0.1.example.com',
                     'http://localhost@example.com', 'ftp://127.0.0.1', 'https://'):
            with self.subTest(root=root):
                self.assert_usage_error(self.arguments(api_root=root) + ['--dry-run'], '--api-root')

    def test_missing_bundle(self):
        os.remove(self.bundle)
        self.assert_usage_error(self.arguments() + ['--dry-run'], 'is not a file')

    def test_version_code_range(self):
        for code in ('0', '2100000001', 'abc', '-1', '01', ' 1'):
            with self.subTest(code=code):
                self.assert_usage_error(self.arguments(version_code=code) + ['--dry-run'], '--version-code')
        self.assertEqual(run_script(self.arguments(version_code='2100000000') + ['--dry-run'], self.tmp).returncode,
                         0)

    def test_track_and_package(self):
        self.assert_usage_error(self.arguments(track='alpha') + ['--dry-run'], 'invalid choice')
        arguments = self.arguments() + ['--dry-run']
        arguments[arguments.index(PACKAGE)] = 'io.vikunja.app/../x'
        self.assert_usage_error(arguments, 'not an application id')

    def test_service_account_required_without_dry_run(self):
        self.assert_usage_error(self.arguments(), '--service-account-file is required')

    def test_service_account_without_a_field(self):
        path = os.path.join(self.tmp, 'account.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump({'client_email': EMAIL, 'private_key': '', 'token_uri': 'https://oauth2.googleapis.com/token'},
                      f)
        result = run_script(self.arguments(account=path), self.tmp)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr, 'error: the service account JSON has no private_key\n')

    def test_service_account_token_uri_must_be_https(self):
        path = os.path.join(self.tmp, 'account.json')
        write_service_account(path, 'http://oauth2.example.com/token', 'not a key')
        result = run_script(self.arguments(account=path), self.tmp)
        self.assertEqual(result.returncode, 1)
        self.assertIn("token_uri is not an https URL", result.stderr)
        self.assertNotIn('not a key', result.stdout + result.stderr)

    def test_dry_run_reads_no_service_account_and_sends_nothing(self):
        fake = FakePlay()
        self.addCleanup(fake.close)
        missing = os.path.join(self.tmp, 'no-such-account.json')
        result = run_script(self.arguments(api_root=fake.root, account=missing) + ['--dry-run'], self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(fake.requests, [])
        self.assertEqual(result.stderr, '')
        lines = result.stdout.splitlines()
        self.assertEqual(len(lines), 6)
        self.assertTrue(all(line.startswith('Would ') for line in lines), lines)
        self.assertIn(f'{fake.root}{API}/edits (edits.insert)', lines[1])
        self.assertIn('versionCode 1000001 is already on beta', lines[2])
        self.assertIn(f'{fake.root}{UPLOAD}/edits/<edit>/bundles?uploadType=media', lines[3])
        self.assertIn('app-release.aab, 4096 bytes', lines[3])
        self.assertIn('{"track": "beta", "releases": [{"name": "1.0.0-beta.1", "versionCodes": ["1000001"], '
                      '"status": "completed"}]}', lines[4])
        self.assertIn(':commit (edits.commit)', lines[5])

    def test_dry_run_production(self):
        result = run_script(self.arguments(track='production', version_code='1000099', name='1.0.0',
                                           fraction='0.25') + ['--dry-run'], self.tmp)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('"status": "inProgress", "userFraction": 0.25}', result.stdout)


@unittest.skipUnless(OPENSSL, 'openssl is missing')
class PlayUploadTest(Fixture):
    @classmethod
    def setUpClass(cls):
        cls.keys = tempfile.mkdtemp()
        cls.private_key, cls.public_key = generate_key(cls.keys)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.keys)

    def setUp(self):
        super().setUp()
        self.fake = FakePlay(self.public_key)
        self.addCleanup(self.fake.close)
        self.account = os.path.join(self.tmp, 'play.json')
        write_service_account(self.account, self.fake.token_uri, self.private_key)

    def upload(self, extra_env=None, **arguments):
        arguments.setdefault('api_root', self.fake.root)
        arguments.setdefault('account', self.account)
        result = run_script(self.arguments(**arguments), self.tmp, extra_env)
        self.assert_no_secrets(result)
        return result

    def assert_no_secrets(self, result):
        output = result.stdout + result.stderr
        unmasked = '\n'.join(line for line in output.splitlines() if not line.startswith('::add-mask::'))
        self.assertNotIn(self.fake.token, unmasked)
        for assertion in self.fake.assertions:
            self.assertNotIn(assertion.rsplit('.', 1)[-1], output)
        for line in self.private_key.splitlines():
            if line and not line.startswith('-----'):
                self.assertNotIn(line, output)

    def test_beta(self):
        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fake.token_problems, [])
        self.assertEqual(self.fake.kinds(), ['token', 'insert', 'track-get', 'upload', 'track-update', 'commit'])
        self.assertEqual(self.fake.request('token')['content_type'], 'application/x-www-form-urlencoded')
        self.assertEqual(self.fake.request('insert')['body'], b'{}')
        upload = self.fake.request('upload')
        self.assertEqual(upload['content_type'], 'application/octet-stream')
        self.assertEqual(upload['body'], self.bundle_bytes)
        update = self.fake.request('track-update')
        self.assertEqual(update['path'], f'{API}/edits/{EDIT}/tracks/beta')
        self.assertEqual(json.loads(update['body']), {
            'track': 'beta',
            'releases': [{'name': '1.0.0-beta.1', 'versionCodes': ['1000001'], 'status': 'completed'}]})
        self.assertIn('Committed versionCode 1000001 to beta (completed)', result.stdout)

    def test_production_staged_rollout(self):
        self.fake.upload_version_code = 1000099
        result = self.upload(track='production', version_code='1000099', name='1.0.0', fraction='0.25')
        self.assertEqual(result.returncode, 0, result.stderr)
        update = self.fake.request('track-update')
        self.assertEqual(update['path'], f'{API}/edits/{EDIT}/tracks/production')
        self.assertEqual(json.loads(update['body']), {
            'track': 'production',
            'releases': [{'name': '1.0.0', 'versionCodes': ['1000099'], 'status': 'inProgress',
                          'userFraction': 0.25}]})
        self.assertIn('Committed versionCode 1000099 to production (inProgress, 0.25)', result.stdout)

    def test_a_missing_track_counts_as_empty(self):
        del self.fake.tracks['beta']
        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fake.kinds(), ['token', 'insert', 'track-get', 'upload', 'track-update', 'commit'])

    def test_version_code_already_on_the_track(self):
        self.fake.tracks['beta'] = [{'name': '1.0.0-beta.1', 'versionCodes': ['1000001'], 'status': 'completed'}]
        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fake.kinds(), ['token', 'insert', 'track-get', 'delete'])
        self.assertEqual(self.fake.request('delete')['path'], f'{API}/edits/{EDIT}')
        self.assertIn('versionCode 1000001 is already on beta', result.stdout)

    def test_upload_answering_another_version_code(self):
        self.fake.upload_version_code = 1000002
        result = self.upload()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.fake.kinds(), ['token', 'insert', 'track-get', 'upload', 'delete'])
        self.assertIn('bundles.upload answered versionCode 1000002, the release has 1000001', result.stderr)

    def test_api_error_message(self):
        self.fake.errors['track-update'] = (403, {'error': {
            'code': 403, 'message': 'The caller does not have permission', 'status': 'PERMISSION_DENIED'}})
        result = self.upload()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.fake.kinds(), ['token', 'insert', 'track-get', 'upload', 'track-update', 'delete'])
        self.assertIn('error: tracks.update answered HTTP 403: The caller does not have permission', result.stderr)

    def test_token_error(self):
        write_service_account(self.account, self.fake.token_uri, self.private_key, email='someone@example.com')
        result = self.upload()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.fake.kinds(), ['token'])
        self.assertIn('the token request answered HTTP 400: invalid_grant: Invalid JWT: iss', result.stderr)

    def test_unusable_private_key(self):
        broken = '-----BEGIN PRIVATE KEY-----\nTk9UQUtFWWJ1dHNlY3JldA==\n-----END PRIVATE KEY-----\n'
        write_service_account(self.account, self.fake.token_uri, broken)
        result = self.upload()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.fake.requests, [])
        self.assertEqual(result.stderr, f'error: {SIGNING_FAILED}\n')
        self.assertNotIn('Tk9UQUtFWWJ1dHNlY3JldA', result.stdout)

    def test_token_masked_first_on_github_actions(self):
        result = self.upload(extra_env={'GITHUB_ACTIONS': 'true'})
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual(lines[0], f'::add-mask::{self.fake.token}')
        self.assertNotIn(self.fake.token, '\n'.join(lines[1:]) + result.stderr)

    def test_no_mask_line_elsewhere(self):
        result = self.upload()
        self.assertNotIn('::add-mask::', result.stdout)


if __name__ == '__main__':
    unittest.main()
