#!/usr/bin/env python3
"""Link-share helper for the Docker `tls` profile (test_servers/tls/README.md).

Talks to vikunja-2-7-tls over its plain seeding port as the E2E user from
test_servers/seed/e2e-user.env (create it first with
`tool/seed_e2e_user.sh http://localhost:34531`). Prints only ids, never a
password, token, share hash or share URL.

Usage:
  python3 -I tool/tls_e2e.py seed [--write]     project, task and a link share (read, or write with --write)
  python3 -I tool/tls_e2e.py reverse            adb reverse for 34528-34530
  python3 -I tool/tls_e2e.py send-share PORT    hand https://localhost:PORT/share/<hash>/auth to the app's share target
Env:
  ANDROID_SERIAL  device for adb (default emulator-5554)
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = 'http://localhost:34531/api/v1'
TLS_PORTS = (34528, 34529, 34530)
PROJECT_TITLE = 'TLS-Test'
SHARE_NAME = 'tls-e2e'
SHARE_TARGET = 'dev.coderoftime.vikunja/.ShareTargetActivity'
SERIAL = os.environ.get('ANDROID_SERIAL', 'emulator-5554')


def credentials():
    values = {}
    with open(os.path.join(ROOT, 'test_servers', 'seed', 'e2e-user.env'), encoding='utf-8') as env:
        for line in env:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                values[key] = value
    return values['E2E_USERNAME'], values['E2E_PASSWORD']


def call(method, path, token=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    headers = {'Accept': 'application/json'}
    if data is not None:
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = f'Bearer {token}'
    request = urllib.request.Request(f'{BASE}{path}', data=data, method=method, headers=headers)
    for _ in range(3):
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                raw = response.read().decode()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            if error.code == 429:
                time.sleep(int(error.headers.get('Retry-After', '30')) + 1)
                continue
            raise SystemExit(f'{method} {path}: HTTP {error.code}') from None
        except urllib.error.URLError as error:
            raise SystemExit(f'{method} {path}: {error.reason}; is the tls profile up?') from None
    raise SystemExit(f'{method} {path}: still rate limited')


def login():
    username, password = credentials()
    try:
        return call('POST', '/login', body={'username': username, 'password': password})['token']
    except SystemExit as error:
        raise SystemExit(f'{error}; run tool/seed_e2e_user.sh http://localhost:34531 first') from None


def find_project(token):
    return next((p for p in call('GET', '/projects', token) or [] if p['title'] == PROJECT_TITLE), None)


def first_task_id(token, project_id):
    views = call('GET', f'/projects/{project_id}/views', token) or []
    list_view = next((v for v in views if v.get('view_kind') == 'list'), None)
    if list_view is None:
        return None
    tasks = call('GET', f'/projects/{project_id}/views/{list_view["id"]}/tasks', token) or []
    return tasks[0]['id'] if tasks else None


def find_share(token, project_id):
    shares = call('GET', f'/projects/{project_id}/shares', token) or []
    return next((s for s in shares if s.get('name') == SHARE_NAME), None)


def seed(write):
    token = login()
    project = find_project(token) or call('PUT', '/projects', token, {'title': PROJECT_TITLE, 'identifier': 'TLS'})
    task_id = first_task_id(token, project['id'])
    if task_id is None:
        task_id = call('PUT', f'/projects/{project["id"]}/tasks', token, {'title': 'Über TLS geladen'})['id']
    share = find_share(token, project['id'])
    permission = 1 if write else 0
    if share is not None and share.get('permission') != permission:
        call('DELETE', f'/projects/{project["id"]}/shares/{share["id"]}', token)
        share = None
    if share is None:
        share = call('PUT', f'/projects/{project["id"]}/shares', token,
                     {'permission': permission, 'name': SHARE_NAME})
    print('project', project['id'], 'task', task_id, 'share', share['id'],
          'permission', 'write' if permission else 'read')


def adb(*args):
    result = subprocess.run(['adb', '-s', SERIAL, *args], capture_output=True, text=True, check=False)
    return result.returncode, result.stdout + result.stderr


def reverse():
    for port in TLS_PORTS:
        code, output = adb('reverse', f'tcp:{port}', f'tcp:{port}')
        if code != 0:
            raise SystemExit(f'adb reverse {port} failed: {output.strip()}')
    print('adb reverse set for', ', '.join(map(str, TLS_PORTS)), 'on', SERIAL)


def send_share(port):
    if port not in TLS_PORTS:
        raise SystemExit(f'PORT must be one of {", ".join(map(str, TLS_PORTS))}')
    token = login()
    project = find_project(token)
    share = find_share(token, project['id']) if project else None
    if share is None:
        raise SystemExit('no link share yet; run: python3 -I tool/tls_e2e.py seed')
    secret = share['hash']
    url = f'https://localhost:{port}/share/{secret}/auth'
    code, output = adb('shell', 'am', 'start', '-a', 'android.intent.action.SEND', '-t', 'text/plain',
                       '--es', 'android.intent.extra.TEXT', url, '-n', SHARE_TARGET)
    if code != 0 or 'Error' in output:
        raise SystemExit('adb am start failed: ' + output.replace(secret, '<hash>').strip())
    print('share', share['id'], 'sent to the app for port', port)


def main():
    args = sys.argv[1:]
    if args[:1] == ['seed'] and args[1:] in ([], ['--write']):
        seed(write=args[1:] == ['--write'])
    elif args == ['reverse']:
        reverse()
    elif len(args) == 2 and args[0] == 'send-share' and args[1].isdigit():
        send_share(int(args[1]))
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
