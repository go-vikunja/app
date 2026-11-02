#!/usr/bin/env python3
"""Fills the E2E user on a local test server with demo projects and tasks.

For checks on the emulator after the test server restarted empty (its state
lives in a tmpfs) and for the store screenshots, in German or English: both
sets have the same projects, labels, tasks, filter and board. Run
tool/seed_e2e_user.sh with both env files first. Prints neither passwords nor
tokens.

Usage: python3 -I tool/seed_demo_data.py [--lang de|en] [--reset] [base URL]
       (default: German, http://localhost:34527)
--reset removes the demo data of both languages first, found by its titles,
so the other language replaces it without signing in again.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_BASE = 'http://localhost:34527'
BASE = DEFAULT_BASE

# key, colour, identifier text key, parent key, archived
PROJECTS = (
    ('work', '2e7d32', 'work_id', None, False),
    ('home', '1565c0', 'home_id', None, False),
    ('kitchen', 'e65100', 'kitchen_id', 'home', False),
    ('reading', '6a1b9a', 'reading_id', None, False),
    ('old', '', None, None, True),
)
SHARED_PROJECT = 'home'
LABELS = (('chores', 'f5a623'), ('urgent', 'd32f2f'), ('garage', '2e7d32'), ('waiting', '78909c'))
# project key ('inbox' is the server's), title key, labels, assignees, fields;
# due is (days, hours) from now and description names a text.
TASKS = (
    ('kitchen', 'dishwasher', ('chores',), ('other',),
     {'due': (0, 6), 'priority': 3, 'percent_done': 0.4, 'description': 'checklist', 'hex_color': 'e65100'}),
    ('work', 'report', ('urgent',), (), {'due': (3, 0), 'priority': 4, 'is_favorite': True, 'percent_done': 0.3}),
    ('work', 'one_to_one', ('waiting',), (), {'due': (1, 2), 'priority': 2}),
    ('work', 'presentation', (), (), {'due': (5, 0)}),
    ('work', 'expenses', (), (), {}),
    ('home', 'rent', ('urgent',), ('me',), {'due': (-1, 0), 'priority': 4, 'is_favorite': True}),
    ('home', 'boxes', (), ('me',), {}),
    ('inbox', 'tyres', ('garage',), (), {'due': (2, 0), 'priority': 3}),
    ('reading', 'book', (), (), {'due': (1, 0)}),
    ('work', 'kickoff', (), (), {'done': True}),
)
FILTER = 'priority >= 3 && done = false'
# The Kanban view of this project: its three columns renamed, these tasks in
# the second; the server puts done tasks into the done column itself.
BOARD_PROJECT = 'work'
BOARD_IN_PROGRESS = ('report', 'presentation')

TEXTS = {
    'de': {
        'name': 'Tara',
        'work': 'Arbeit', 'work_id': 'WORK',
        'home': 'Wohnung', 'home_id': 'WOHN',
        'kitchen': 'Küche', 'kitchen_id': 'KUE',
        'reading': 'Lesen', 'reading_id': 'LES',
        'old': 'Altprojekt',
        'chores': 'Haushalt', 'urgent': 'wichtig', 'garage': 'Werkstatt', 'waiting': 'warten',
        'dishwasher': 'Spülmaschine reparieren',
        'report': 'Quartalsbericht fertigstellen',
        'one_to_one': '1:1 mit Lena vorbereiten',
        'presentation': 'Präsentation vorbereiten',
        'expenses': 'Reisekosten abrechnen',
        'rent': 'Miete überweisen',
        'boxes': 'Umzugskartons besorgen',
        'tyres': 'Reifen wechseln',
        'book': 'Buch zurückgeben',
        'kickoff': 'Kickoff-Notizen verschicken',
        'checklist': ('Die Maschine pumpt <strong>nicht ab</strong>, die Anzeige blinkt E24.',
                      (('Sieb reinigen', True), ('Pumpe prüfen', False), ('Ersatzteil bestellen', False))),
        'filter': 'Dringend',
        'columns': ('Offen', 'In Arbeit', 'Erledigt'),
    },
    'en': {
        'name': 'Tara',
        'work': 'Work', 'work_id': 'WORK',
        'home': 'Home', 'home_id': 'HOME',
        'kitchen': 'Kitchen', 'kitchen_id': 'KIT',
        'reading': 'Reading', 'reading_id': 'READ',
        'old': 'Old project',
        'chores': 'chores', 'urgent': 'important', 'garage': 'garage', 'waiting': 'waiting',
        'dishwasher': 'Fix the dishwasher',
        'report': 'Finish the quarterly report',
        'one_to_one': 'Prepare the 1:1 with Lena',
        'presentation': 'Prepare the presentation',
        'expenses': 'Submit travel expenses',
        'rent': 'Pay the rent',
        'boxes': 'Get moving boxes',
        'tyres': 'Change the tyres',
        'book': 'Return the library book',
        'kickoff': 'Send the kickoff notes',
        'checklist': ('The dishwasher <strong>does not drain</strong>, the display flashes E24.',
                      (('Clean the filter', True), ('Check the pump', False), ('Order the spare part', False))),
        'filter': 'Urgent',
        'columns': ('To do', 'In progress', 'Done'),
    },
}


def checklist(text):
    intro, items = text
    rows = []
    for title, checked in items:
        state, attribute = ('true', ' checked="checked"') if checked else ('false', '')
        rows.append(f'<li data-checked="{state}" data-type="taskItem"><label><input type="checkbox"{attribute}>'
                    f'<span></span></label><div><p>{title}</p></div></li>')
    return f'<p>{intro}</p><ul data-type="taskList">{"".join(rows)}</ul>'


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
            if error.code == 304:
                return None
            if error.code == 429:
                time.sleep(int(error.headers.get('Retry-After', '30')) + 1)
                continue
            # The test server's SQLite answers "database is locked" now and
            # then (seen right after adding an assignee), having written nothing.
            if error.code == 500:
                time.sleep(1)
                continue
            raise SystemExit(f'{method} {path}: HTTP {error.code}')
    raise SystemExit(f'{method} {path}: gave up after 3 tries')


def login(env_name):
    username, password = credentials(env_name)
    token = call('POST', '/login', body={'username': username, 'password': password})['token']
    return token, call('GET', '/user', token)


def at(days=0, hours=0):
    moment = datetime.now(timezone.utc).replace(microsecond=0) + timedelta(days=days, hours=hours)
    return moment.isoformat().replace('+00:00', 'Z')


def task_fields(fields, texts):
    result = {}
    for key, value in fields.items():
        if key == 'due':
            result['due_date'] = at(*value)
        elif key == 'description':
            result['description'] = checklist(texts[value])
        else:
            result[key] = value
    return result


def all_projects(token):
    # One page: the server repeats its pseudo projects on every page, and the
    # demo data stays far below a page of 50.
    return call('GET', '/projects?is_archived=true&per_page=50', token)


def demo_titles(keys):
    keys = list(keys)
    return {texts[key] for texts in TEXTS.values() for key in keys}


def reset(token, me):
    projects = demo_titles(key for key, *_ in PROJECTS)
    filters = demo_titles(['filter'])
    for project in all_projects(token):
        if project['id'] > 0 and project['parent_project_id'] == 0 and project['title'] in projects \
                and project['owner']['id'] == me['id']:
            call('DELETE', f'/projects/{project["id"]}', token)
        elif project['id'] < -1 and project['title'] in filters:
            call('DELETE', f'/filters/{-project["id"] - 1}', token)
    labels = demo_titles(key for key, _ in LABELS)
    for label in call('GET', '/labels?per_page=50', token) or []:
        if label['title'] in labels and label['created_by']['id'] == me['id']:
            call('DELETE', f'/labels/{label["id"]}', token)
    inbox_tasks = demo_titles(title for project, title, *_ in TASKS if project == 'inbox')
    for task in call('GET', f'/projects/{inbox_id(token)}/tasks?per_page=50', token) or []:
        if task['title'] in inbox_tasks:
            call('DELETE', f'/tasks/{task["id"]}', token)


def inbox_id(token):
    return next(p['id'] for p in all_projects(token) if p['title'] == 'Inbox' and p['id'] > 0)


def seed(token, me, other, texts):
    call('PATCH', '/user/settings/general', token, {'name': texts['name']}, version='v2',
         ctype='application/merge-patch+json')
    ids = {'inbox': inbox_id(token)}
    for key, colour, identifier, parent, _ in PROJECTS:
        ids[key] = call('PUT', '/projects', token, {
            'title': texts[key], 'hex_color': colour, 'identifier': texts[identifier] if identifier else '',
            'parent_project_id': ids[parent] if parent else 0})['id']
    for key, _, _, _, archived in PROJECTS:
        if archived:
            call('POST', f'/projects/{ids[key]}', token, {'title': texts[key], 'is_archived': True})
    call('PUT', f'/projects/{ids[SHARED_PROJECT]}/users', token, {'username': other['username'], 'permission': 1})

    labels = {key: call('PUT', '/labels', token, {'title': texts[key], 'hex_color': colour})['id']
              for key, colour in LABELS}
    people = {'me': me['id'], 'other': other['id']}
    tasks = {}
    for project, title, label_keys, assignees, fields in TASKS:
        created = call('PUT', f'/projects/{ids[project]}/tasks', token,
                       {'title': texts[title], **task_fields(fields, texts)})
        for key in label_keys:
            call('PUT', f'/tasks/{created["id"]}/labels', token, {'label_id': labels[key]})
        for key in assignees:
            call('PUT', f'/tasks/{created["id"]}/assignees', token, {'user_id': people[key]})
        tasks[title] = created['id']
    call('PUT', '/filters', token, {'title': texts['filter'], 'filters': {'filter': FILTER}, 'is_favorite': True})
    arrange_board(token, ids[BOARD_PROJECT], texts['columns'], [tasks[key] for key in BOARD_IN_PROGRESS])


def arrange_board(token, project_id, titles, in_progress):
    view = next(v for v in call('GET', f'/projects/{project_id}/views', token) if v['view_kind'] == 'kanban')
    path = f'/projects/{project_id}/views/{view["id"]}/buckets'
    buckets = sorted(call('GET', path, token), key=lambda bucket: bucket['position'])
    for bucket, title in zip(buckets, titles):
        call('POST', f'{path}/{bucket["id"]}', token,
             {'title': title, 'limit': bucket['limit'], 'position': bucket['position']})
    for task_id in in_progress:
        call('POST', f'{path}/{buckets[1]["id"]}/tasks', token, {'task_id': task_id})


def parse_args(argv):
    parser = argparse.ArgumentParser(description='Fills the E2E user on a local test server with demo data.')
    parser.add_argument('--lang', choices=sorted(TEXTS), default='de')
    parser.add_argument('--reset', action='store_true',
                        help='remove the demo data of both languages first')
    parser.add_argument('base', nargs='?', default=DEFAULT_BASE)
    return parser.parse_args(argv)


def main(argv):
    global BASE
    args = parse_args(argv)
    BASE = args.base.rstrip('/')
    texts = TEXTS[args.lang]
    token, me = login('e2e-user.env')
    _, other = login('e2e-user-2.env')
    if args.reset:
        reset(token, me)
    titles = {p['title'] for p in all_projects(token)}
    if texts['work'] in titles:
        print('demo data already present')
        return
    others = [lang for lang, other_texts in TEXTS.items() if other_texts['work'] in titles]
    if others:
        raise SystemExit(f'the {others[0]} demo data is on this server; add --reset to replace it')
    seed(token, me, other, texts)
    print(f'demo data created ({args.lang})')


if __name__ == '__main__':
    main(sys.argv[1:])
