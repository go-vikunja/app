#!/usr/bin/env python3
"""Uploads a signed bundle to a Google Play track (D86).

  python3 -I tool/ci/play_upload.py --package P --bundle F --version-code N
      --track beta|production --release-name S [--user-fraction F]
      [--service-account-file F] [--api-root URL] [--dry-run]

beta gets a completed release, production a staged rollout (inProgress) to
--user-fraction of the users. A versionCode already on the track is skipped.
Standard library only, so that no third-party code handles the service
account's key: openssl gets the key through stdin, and the access token is
masked on GitHub Actions. --dry-run prints the calls and reads no
credential. Exit 0 when done or already there, 1 on an error, 2 on a usage
error.
"""
import argparse
import base64
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_API_ROOT = 'https://androidpublisher.googleapis.com'
DEFAULT_TOKEN_URI = 'https://oauth2.googleapis.com/token'
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'
JWT_BEARER = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
TIMEOUT = 60
UPLOAD_TIMEOUT = 900
MAX_VERSION_CODE = 2_100_000_000
LOCAL_HOSTS = ('127.0.0.1', 'localhost')
PACKAGE = re.compile(r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+')
VERSION_CODE = re.compile(r'[1-9][0-9]*')
SIGNING_FAILED = "openssl could not sign with the service account's private_key"


class PlayError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    # urllib would send the bearer token on to wherever a redirect points.
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def https_or_local(url):
    parts = urllib.parse.urlsplit(url)
    if not parts.hostname:
        return False
    return parts.scheme == 'https' or (parts.scheme == 'http' and parts.hostname in LOCAL_HOSTS)


def parse_arguments(argv):
    parser = argparse.ArgumentParser(prog='tool/ci/play_upload.py',
                                     description='Uploads a signed bundle to a Google Play track.')
    parser.add_argument('--package', required=True)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--version-code', required=True)
    parser.add_argument('--track', required=True, choices=('beta', 'production'))
    parser.add_argument('--release-name', required=True)
    parser.add_argument('--user-fraction')
    parser.add_argument('--service-account-file')
    parser.add_argument('--api-root', default=DEFAULT_API_ROOT)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args(argv)

    if not PACKAGE.fullmatch(args.package):
        parser.error(f'--package {args.package!r} is not an application id')
    if not VERSION_CODE.fullmatch(args.version_code) or int(args.version_code) > MAX_VERSION_CODE:
        parser.error(f'--version-code must be an integer from 1 to {MAX_VERSION_CODE:,}')
    args.version_code = int(args.version_code)
    if not args.release_name.strip():
        parser.error('--release-name is empty')
    if args.track == 'production':
        if args.user_fraction is None:
            parser.error('--user-fraction is required for production')
        try:
            fraction = float(args.user_fraction)
        except ValueError:
            fraction = math.nan
        if not 0 < fraction < 1:
            parser.error('--user-fraction must lie strictly between 0 and 1')
        args.user_fraction = fraction
    elif args.user_fraction is not None:
        parser.error('--user-fraction is only for production')
    if not os.path.isfile(args.bundle):
        parser.error(f'--bundle {args.bundle} is not a file')
    if not https_or_local(args.api_root):
        parser.error('--api-root must be an https URL (http only for 127.0.0.1 or localhost)')
    args.api_root = args.api_root.rstrip('/')
    if not args.dry_run and not args.service_account_file:
        parser.error('--service-account-file is required without --dry-run')
    return args


def release_body(args):
    release = {'name': args.release_name, 'versionCodes': [str(args.version_code)]}
    if args.track == 'production':
        release.update(status='inProgress', userFraction=args.user_fraction)
    else:
        release['status'] = 'completed'
    return release


def api_urls(args):
    return (f'{args.api_root}/androidpublisher/v3/applications/{args.package}',
            f'{args.api_root}/upload/androidpublisher/v3/applications/{args.package}')


def print_dry_run(args):
    base, upload = api_urls(args)
    code = args.version_code
    track = {'track': args.track, 'releases': [release_body(args)]}
    print('Would get an access token for the service account (JWT bearer grant, scope androidpublisher) '
          'from its token_uri')
    print(f'Would POST {base}/edits (edits.insert)')
    print(f'Would GET {base}/edits/<edit>/tracks/{args.track} (tracks.get), and stop there, deleting the edit, '
          f'if versionCode {code} is already on {args.track}')
    print(f'Would POST {upload}/edits/<edit>/bundles?uploadType=media (bundles.upload) with '
          f'{os.path.basename(args.bundle)}, {os.path.getsize(args.bundle)} bytes; '
          f"the answer's versionCode must be {code}")
    print(f'Would PUT {base}/edits/<edit>/tracks/{args.track} (tracks.update) with {json.dumps(track)}')
    print(f'Would POST {base}/edits/<edit>:commit (edits.commit)')


def read_service_account(path):
    try:
        with open(path, encoding='utf-8') as f:
            text = f.read()
    except (OSError, UnicodeDecodeError):
        raise PlayError('cannot read the service account file') from None
    try:
        account = json.loads(text)
    except ValueError:
        raise PlayError('the service account file is not JSON') from None
    if not isinstance(account, dict):
        raise PlayError('the service account JSON is not an object')
    for field in ('client_email', 'private_key'):
        if not isinstance(account.get(field), str) or not account[field]:
            raise PlayError(f'the service account JSON has no {field}')
    token_uri = account.get('token_uri') or DEFAULT_TOKEN_URI
    if not isinstance(token_uri, str) or not https_or_local(token_uri):
        raise PlayError("the service account's token_uri is not an https URL")
    return account['client_email'], account['private_key'], token_uri


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')


def signed_jwt(client_email, private_key, token_uri, now):
    header = b64url(json.dumps({'alg': 'RS256', 'typ': 'JWT'}, separators=(',', ':')).encode())
    claims = b64url(json.dumps({'iss': client_email, 'scope': SCOPE, 'aud': token_uri, 'iat': now,
                                'exp': now + 3600}, separators=(',', ':')).encode())
    with tempfile.TemporaryDirectory() as directory:
        path = os.path.join(directory, 'jwt-signing-input')
        with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as f:
            f.write(f'{header}.{claims}'.encode('ascii'))
        try:
            # openssl's messages can quote the key, so they are never shown.
            result = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', '/dev/stdin', path],
                                    input=private_key.encode('utf-8'), capture_output=True, check=False,
                                    timeout=TIMEOUT)
        except (OSError, subprocess.SubprocessError):
            raise PlayError(SIGNING_FAILED) from None
    if result.returncode != 0 or not result.stdout:
        raise PlayError(SIGNING_FAILED)
    return f'{header}.{claims}.{b64url(result.stdout)}'


def api_message(error):
    try:
        payload = json.loads(error.read())
    except (OSError, ValueError):
        return ''
    finally:
        error.close()
    if not isinstance(payload, dict):
        return ''
    detail = payload.get('error')
    if isinstance(detail, dict):
        message = detail.get('message')
    elif isinstance(detail, str):
        description = payload.get('error_description')
        message = f'{detail}: {description}' if isinstance(description, str) else detail
    else:
        message = None
    return ' '.join(message.split())[:500] if isinstance(message, str) else ''


def send(method, url, what, *, token=None, body=None, data=None, content_type=None, timeout=TIMEOUT,
         missing_ok=False):
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        content_type = 'application/json'
    if content_type:
        headers['Content-Type'] = content_type
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with OPENER.open(request, timeout=timeout) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        if missing_ok and error.code == 404:
            error.close()
            return None
        message = api_message(error)
        raise PlayError(f'{what} answered HTTP {error.code}' + (f': {message}' if message else '')) from None
    except OSError as error:
        raise PlayError(f'{what} failed: {getattr(error, "reason", None) or error}') from None
    if not raw.strip():
        return {}
    try:
        answer = json.loads(raw)
    except ValueError:
        raise PlayError(f'{what} did not answer JSON') from None
    if not isinstance(answer, dict):
        raise PlayError(f'{what} did not answer a JSON object')
    return answer


def access_token(service_account_file):
    client_email, private_key, token_uri = read_service_account(service_account_file)
    assertion = signed_jwt(client_email, private_key, token_uri, int(time.time()))
    form = urllib.parse.urlencode({'grant_type': JWT_BEARER, 'assertion': assertion}).encode('ascii')
    answer = send('POST', token_uri, 'the token request', data=form,
                  content_type='application/x-www-form-urlencoded')
    token = answer.get('access_token')
    if not isinstance(token, str) or not token:
        raise PlayError('the token endpoint answered without an access_token')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        masked = token.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f'::add-mask::{masked}', flush=True)
    return token


def on_track(track, version_code):
    for release in track.get('releases') or []:
        if not isinstance(release, dict):
            continue
        if str(version_code) in [str(code) for code in release.get('versionCodes') or []]:
            return True
    return False


def delete_edit(edit_url, token):
    try:
        send('DELETE', edit_url, 'edits.delete', token=token)
    except PlayError as error:
        print(f'warning: {error}', file=sys.stderr)


def publish(args):
    code = args.version_code
    token = access_token(args.service_account_file)
    base, upload = api_urls(args)
    edit = send('POST', f'{base}/edits', 'edits.insert', token=token, body={})
    edit_id = edit.get('id')
    if not isinstance(edit_id, str) or not edit_id:
        raise PlayError('edits.insert answered without an edit id')
    edit_path = f'/edits/{urllib.parse.quote(edit_id, safe="")}'
    edit_url = base + edit_path
    track_url = f'{edit_url}/tracks/{args.track}'
    release = release_body(args)
    try:
        if on_track(send('GET', track_url, 'tracks.get', token=token, missing_ok=True) or {}, code):
            print(f'versionCode {code} is already on {args.track}')
            delete_edit(edit_url, token)
            return 0
        try:
            with open(args.bundle, 'rb') as f:
                bundle = f.read()
        except OSError as error:
            raise PlayError(f'cannot read {args.bundle}: {error.strerror}') from None
        print(f'Uploading {os.path.basename(args.bundle)} ({len(bundle)} bytes) to Google Play')
        uploaded = send('POST', f'{upload}{edit_path}/bundles?uploadType=media', 'bundles.upload', token=token,
                        data=bundle, content_type='application/octet-stream', timeout=UPLOAD_TIMEOUT)
        if str(uploaded.get('versionCode')) != str(code):
            raise PlayError(f'bundles.upload answered versionCode {uploaded.get("versionCode")}, '
                            f'the release has {code}')
        send('PUT', track_url, 'tracks.update', token=token, body={'track': args.track, 'releases': [release]})
        send('POST', f'{edit_url}:commit', 'edits.commit', token=token)
    except PlayError:
        delete_edit(edit_url, token)
        raise
    detail = release['status'] + (f', {args.user_fraction:g}' if args.track == 'production' else '')
    print(f'Committed versionCode {code} to {args.track} ({detail})')
    return 0


def main(argv):
    args = parse_arguments(argv)
    if args.dry_run:
        print_dry_run(args)
        return 0
    try:
        return publish(args)
    except PlayError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
