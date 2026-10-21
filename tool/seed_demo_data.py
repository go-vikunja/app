#!/usr/bin/env python3
"""Fills the E2E user on a local test server with demo projects and tasks.

For checks on the emulator after the test server restarted empty (its state
lives in a tmpfs). Run tool/seed_e2e_user.sh with both env files first.
Prints neither passwords nor tokens.

Usage: python3 tool/seed_demo_data.py [base URL]   (default http://localhost:34527)
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = (sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:34527').rstrip('/')


def credentials(name):
    values = {}
    with open(os.path.join(ROOT, 'test_servers', 'seed', name)) as env:
        for line in env:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                values[key] = value
    return values['E2E_USERNAME'], values['E2E_PASSWORD']


def call(method, path, token=None, body=None, version='v1', ctype='application/json'):
    data = None if body is None else json.dumps(body).encode()
    headers = {'Accept': 'application/json'}
    if data is not None:
        headers['Content-Type'] = ctype
    if token:
        headers['Authorization'] = f'Bearer {token}'
    request = urllib.request.Request(f'{BASE}/api/{version}{path}', data=data, method=method, headers=headers)
    for _ in range(3):
        try:
            with urllib.request.urlopen(request) as response:
                raw = response.read().decode()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            if error.code == 429:
                time.sleep(int(error.headers.get('Retry-After', '30')) + 1)
                continue
            raise SystemExit(f'{method} {path}: HTTP {error.code}')
    raise SystemExit(f'{method} {path}: still rate limited')


def login(env_name):
    username, password = credentials(env_name)
    token = call('POST', '/login', body={'username': username, 'password': password})['token']
    return token, call('GET', '/user', token)


def at(days=0, hours=0):
    moment = datetime.now(timezone.utc).replace(microsecond=0) + timedelta(days=days, hours=hours)
    return moment.isoformat().replace('+00:00', 'Z')


CHECKLIST = (
    '<p>Die Maschine pumpt <strong>nicht ab</strong>, die Anzeige blinkt E24.</p>'
    '<ul data-type="taskList">'
    '<li data-checked="true" data-type="taskItem"><label><input type="checkbox" checked="checked"><span></span></label><div><p>Sieb reinigen</p></div></li>'
    '<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label><div><p>Pumpe prüfen</p></div></li>'
    '<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label><div><p>Ersatzteil bestellen</p></div></li>'
    '</ul>'
)


def main():
    token, me = login('e2e-user.env')
    _, other = login('e2e-user-2.env')
    if any(p['title'] == 'Arbeit' for p in call('GET', '/projects', token)):
        print('demo data already present')
        return
    call('PATCH', '/user/settings/general', token, {'name': 'Tara'}, version='v2',
         ctype='application/merge-patch+json')

    def project(title, color, identifier='', parent=0):
        return call('PUT', '/projects', token, {'title': title, 'hex_color': color, 'identifier': identifier,
                                                 'parent_project_id': parent})['id']

    def label(title, color):
        return call('PUT', '/labels', token, {'title': title, 'hex_color': color})['id']

    work = project('Arbeit', '2e7d32', 'WORK')
    home = project('Wohnung', '1565c0', 'WOHN')
    kitchen = project('Küche', 'e65100', 'KUE', home)
    reading = project('Lesen', '6a1b9a', 'LES')
    old = project('Altprojekt', '')
    inbox = next(p['id'] for p in call('GET', '/projects', token) if p['title'] == 'Inbox')
    call('POST', f'/projects/{old}', token, {'title': 'Altprojekt', 'is_archived': True})
    call('PUT', f'/projects/{home}/users', token, {'username': other['username'], 'permission': 1})

    chores = label('Haushalt', 'f5a623')
    urgent = label('wichtig', 'd32f2f')
    garage = label('Werkstatt', '2e7d32')
    waiting = label('warten', '78909c')

    def task(project_id, title, labels=(), assignees=(), **fields):
        created = call('PUT', f'/projects/{project_id}/tasks', token, {'title': title, **fields})
        for label_id in labels:
            call('PUT', f'/tasks/{created["id"]}/labels', token, {'label_id': label_id})
        for user_id in assignees:
            call('PUT', f'/tasks/{created["id"]}/assignees', token, {'user_id': user_id})
        return created['id']

    task(kitchen, 'Spülmaschine reparieren', [chores], [other['id']], due_date=at(hours=6),
         priority=3, percent_done=0.4, description=CHECKLIST, hex_color='e65100')
    task(work, 'Quartalsbericht fertigstellen', [urgent], due_date=at(days=3), priority=4,
         is_favorite=True, percent_done=0.3)
    task(work, '1:1 mit Lena vorbereiten', [waiting], due_date=at(days=1, hours=2), priority=2)
    task(work, 'Präsentation vorbereiten', due_date=at(days=5))
    task(work, 'Reisekosten abrechnen')
    task(home, 'Miete überweisen', [urgent], [me['id']], due_date=at(days=-1), priority=4, is_favorite=True)
    task(home, 'Umzugskartons besorgen', assignees=[me['id']])
    task(inbox, 'Reifen wechseln', [garage], due_date=at(days=2), priority=3)
    task(reading, 'Buch zurückgeben', due_date=at(days=1))
    task(work, 'Kickoff-Notizen verschicken', done=True)
    call('PUT', '/filters', token, {'title': 'Dringend', 'filters': {'filter': 'priority >= 3 && done = false'},
                                    'is_favorite': True})
    print('demo data created')


main()
