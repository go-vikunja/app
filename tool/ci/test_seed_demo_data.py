import contextlib
import importlib.util
import io
import os
import unittest
import urllib.error
from unittest import mock

TOOL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location('seed_demo_data', os.path.join(TOOL, 'seed_demo_data.py'))
seed_demo_data = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(seed_demo_data)

GERMAN_CHECKLIST = (
    '<p>Die Maschine pumpt <strong>nicht ab</strong>, die Anzeige blinkt E24.</p>'
    '<ul data-type="taskList">'
    '<li data-checked="true" data-type="taskItem"><label><input type="checkbox" checked="checked"><span></span></label><div><p>Sieb reinigen</p></div></li>'
    '<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label><div><p>Pumpe prüfen</p></div></li>'
    '<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label><div><p>Ersatzteil bestellen</p></div></li>'
    '</ul>'
)
ME = {'id': 1, 'username': 'me'}
OTHER = {'id': 2, 'username': 'other'}


def project(id_, title, parent=0, owner=1):
    return {'id': id_, 'title': title, 'parent_project_id': parent, 'owner': {'id': owner}}


class FakeServer:
    def __init__(self, projects=(), labels=(), inbox_tasks=()):
        self.requests = []
        self.tokens = []
        self.projects = [project(1, 'Inbox'), *projects]
        self.labels = list(labels)
        self.inbox_tasks = list(inbox_tasks)
        self.last_id = 100

    def __call__(self, method, path, token=None, body=None, version='v1', ctype='application/json'):
        self.requests.append((method, path, body))
        self.tokens.append(token)
        if method == 'GET':
            if path.startswith('/projects?'):
                return self.projects
            if path.endswith('/views'):
                return [{'id': 7, 'view_kind': 'list'}, {'id': 8, 'view_kind': 'kanban'}]
            if path.endswith('/buckets'):
                return [{'id': 33, 'position': 300, 'limit': 0}, {'id': 31, 'position': 100, 'limit': 0},
                        {'id': 32, 'position': 200, 'limit': 5}]
            if path.startswith('/labels'):
                return self.labels
            if path.startswith('/projects/1/tasks'):
                return self.inbox_tasks
            raise AssertionError(path)
        if method == 'PUT' and (path in ('/projects', '/labels') or path.endswith('/tasks')):
            self.last_id += 1
            return {'id': self.last_id}
        return None

    def sent(self, method, prefix=''):
        return [(path, body) for m, path, body in self.requests if m == method and path.startswith(prefix)]


def seeded(lang):
    server = FakeServer()
    with mock.patch.object(seed_demo_data, 'call', server), \
            mock.patch.object(seed_demo_data, 'at', lambda days=0, hours=0: f'at({days},{hours})'), \
            mock.patch.object(seed_demo_data, 'today_at', lambda hour: f'today_at({hour})'):
        seed_demo_data.seed('token', ME, 'token2', OTHER, seed_demo_data.TEXTS[lang])
    return server


class DataSetTest(unittest.TestCase):
    def test_both_languages_have_the_same_keys(self):
        texts = seed_demo_data.TEXTS
        self.assertEqual(set(texts), {'de', 'en'})
        self.assertEqual(set(texts['de']), set(texts['en']))
        used = {key for key, _, identifier, _, _ in seed_demo_data.PROJECTS for key in (key, identifier) if key}
        used |= {key for key, _ in seed_demo_data.LABELS}
        used |= {title for _, title, *_ in seed_demo_data.TASKS}
        used |= {'name', 'checklist', 'filter', 'columns'}
        self.assertEqual(used, set(texts['de']))

    def test_the_english_set_is_translated(self):
        german, english = seed_demo_data.TEXTS['de'], seed_demo_data.TEXTS['en']
        for key in german:
            if key not in ('name', 'work_id'):
                with self.subTest(key=key):
                    self.assertNotEqual(german[key], english[key])
        flat = repr(english)
        for letter in 'äöüßÄÖÜ':
            self.assertNotIn(letter, flat)
        self.assertEqual(len(english['columns']), 3)

    def test_the_german_checklist_is_unchanged(self):
        self.assertEqual(seed_demo_data.checklist(seed_demo_data.TEXTS['de']['checklist']), GERMAN_CHECKLIST)


class TodayAtTest(unittest.TestCase):
    CET = seed_demo_data.timezone(seed_demo_data.timedelta(hours=1))

    def at(self, hour, minute):
        return seed_demo_data.datetime(2026, 11, 3, hour, minute, 20, tzinfo=self.CET)

    def test_the_hour_of_today_in_utc(self):
        self.assertEqual(seed_demo_data.today_at(21, self.at(15, 10)), '2026-11-03T20:00:00Z')

    def test_late_in_the_evening_two_full_hours_later(self):
        self.assertEqual(seed_demo_data.today_at(21, self.at(20, 30)), '2026-11-03T21:00:00Z')


class SeedTest(unittest.TestCase):
    def test_the_german_default_sends_what_it_always_sent(self):
        server = seeded('de')
        self.assertEqual(server.sent('PATCH'), [('/user/settings/general', {'name': 'Tara'}),
                                                ('/user/settings/general', {'name': 'Sam'})])
        self.assertEqual([token for (method, _, _), token in zip(server.requests, server.tokens) if method == 'PATCH'],
                         ['token', 'token2'])
        projects = [body for path, body in server.sent('PUT') if path == '/projects']
        self.assertEqual(projects, [
            {'title': 'Arbeit', 'hex_color': '2e7d32', 'identifier': 'WORK', 'parent_project_id': 0},
            {'title': 'Wohnung', 'hex_color': '1565c0', 'identifier': 'WOHN', 'parent_project_id': 0},
            {'title': 'Küche', 'hex_color': 'e65100', 'identifier': 'KUE', 'parent_project_id': 102},
            {'title': 'Lesen', 'hex_color': '6a1b9a', 'identifier': 'LES', 'parent_project_id': 0},
            {'title': 'Altprojekt', 'hex_color': '', 'identifier': '', 'parent_project_id': 0},
        ])
        self.assertIn(('/projects/105', {'title': 'Altprojekt', 'is_archived': True}), server.sent('POST'))
        self.assertIn(('/projects/102/users', {'username': 'other', 'permission': 1}), server.sent('PUT'))
        self.assertEqual([body['title'] for path, body in server.sent('PUT', '/labels')],
                         ['Haushalt', 'wichtig', 'Werkstatt', 'warten'])
        tasks = [(path, body) for path, body in server.sent('PUT') if path.endswith('/tasks')]
        self.assertEqual(tasks, [
            ('/projects/103/tasks', {'title': 'Spülmaschine reparieren', 'due_date': 'today_at(21)', 'priority': 3,
                                     'percent_done': 0.4, 'description': GERMAN_CHECKLIST, 'hex_color': 'e65100'}),
            ('/projects/101/tasks', {'title': 'Quartalsbericht fertigstellen', 'due_date': 'at(3,0)', 'priority': 4,
                                     'is_favorite': True, 'percent_done': 0.3}),
            ('/projects/101/tasks', {'title': '1:1 mit Lena vorbereiten', 'due_date': 'at(1,2)', 'priority': 2}),
            ('/projects/101/tasks', {'title': 'Präsentation vorbereiten', 'due_date': 'at(5,0)'}),
            ('/projects/101/tasks', {'title': 'Reisekosten abrechnen'}),
            ('/projects/102/tasks', {'title': 'Miete überweisen', 'due_date': 'at(-1,0)', 'priority': 4,
                                     'is_favorite': True}),
            ('/projects/102/tasks', {'title': 'Umzugskartons besorgen'}),
            ('/projects/1/tasks', {'title': 'Reifen wechseln', 'due_date': 'at(2,0)', 'priority': 3}),
            ('/projects/104/tasks', {'title': 'Buch zurückgeben', 'due_date': 'at(1,0)'}),
            ('/projects/101/tasks', {'title': 'Kickoff-Notizen verschicken', 'done': True}),
        ])
        self.assertEqual(server.sent('PUT', '/tasks/110/'), [('/tasks/110/labels', {'label_id': 106}),
                                                             ('/tasks/110/assignees', {'user_id': 2})])
        self.assertEqual(server.sent('PUT', '/tasks/115/'), [('/tasks/115/labels', {'label_id': 107}),
                                                             ('/tasks/115/assignees', {'user_id': 1})])
        self.assertIn(('/filters', {'title': 'Dringend', 'filters': {'filter': 'priority >= 3 && done = false'},
                                    'is_favorite': True}), server.sent('PUT'))

    def test_the_board_gets_its_columns_and_two_cards_in_progress(self):
        server = seeded('de')
        board = server.sent('POST', '/projects/101/views/8/buckets')
        self.assertEqual(board, [
            ('/projects/101/views/8/buckets/31', {'title': 'Offen', 'limit': 0, 'position': 100}),
            ('/projects/101/views/8/buckets/32', {'title': 'In Arbeit', 'limit': 5, 'position': 200}),
            ('/projects/101/views/8/buckets/33', {'title': 'Erledigt', 'limit': 0, 'position': 300}),
            ('/projects/101/views/8/buckets/32/tasks', {'task_id': 111}),
            ('/projects/101/views/8/buckets/32/tasks', {'task_id': 113}),
        ])

    def test_english_has_the_same_requests_with_other_texts(self):
        german, english = seeded('de').requests, seeded('en').requests
        self.assertEqual([(m, p) for m, p, _ in german], [(m, p) for m, p, _ in english])
        titles = [body['title'] for m, path, body in english if m == 'PUT' and path.endswith('/tasks')]
        self.assertEqual(titles[0], 'Fix the dishwasher')
        self.assertIn(('/filters', {'title': 'Urgent', 'filters': {'filter': 'priority >= 3 && done = false'},
                                    'is_favorite': True}), [(p, b) for m, p, b in english if m == 'PUT'])


class ResetTest(unittest.TestCase):
    def test_only_the_demo_data_of_either_language_goes(self):
        server = FakeServer(
            projects=[project(10, 'Arbeit'), project(11, 'Home'), project(12, 'Kitchen', parent=11),
                      project(13, 'Altprojekt'), project(14, 'My own project'), project(15, 'Work', owner=9),
                      project(-1, 'Favorites'), project(-2, 'My Open Tasks'), project(-6, 'Dringend'),
                      project(-7, 'Urgent')],
            labels=[{'id': 1, 'title': 'wichtig', 'created_by': {'id': 1}},
                    {'id': 2, 'title': 'chores', 'created_by': {'id': 9}},
                    {'id': 3, 'title': 'mine', 'created_by': {'id': 1}},
                    {'id': 4, 'title': 'garage', 'created_by': {'id': 1}}],
            inbox_tasks=[{'id': 50, 'title': 'Reifen wechseln'}, {'id': 51, 'title': 'Change the tyres'},
                         {'id': 52, 'title': 'Something else'}])
        with mock.patch.object(seed_demo_data, 'call', server):
            seed_demo_data.reset('token', ME)
        self.assertEqual([path for path, _ in server.sent('DELETE')], [
            '/projects/10', '/projects/11', '/projects/13', '/filters/5', '/filters/6',
            '/labels/1', '/labels/4', '/tasks/50', '/tasks/51'])


class MainTest(unittest.TestCase):
    def run_main(self, argv, server):
        out = io.StringIO()
        with mock.patch.object(seed_demo_data, 'call', server), \
                mock.patch.object(seed_demo_data, 'login', side_effect=[('token', ME), ('token2', OTHER)]), \
                contextlib.redirect_stdout(out):
            seed_demo_data.main(argv)
        return out.getvalue()

    def test_arguments(self):
        args = seed_demo_data.parse_args([])
        self.assertEqual((args.lang, args.reset, args.base), ('de', False, 'http://localhost:34527'))
        args = seed_demo_data.parse_args(['--lang', 'en', '--reset', 'http://localhost:34599/'])
        self.assertEqual((args.lang, args.reset, args.base), ('en', True, 'http://localhost:34599/'))
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            seed_demo_data.parse_args(['--lang', 'fr'])

    def test_present_data_is_left_alone(self):
        server = FakeServer(projects=[project(10, 'Work')])
        self.assertEqual(self.run_main(['--lang', 'en'], server), 'demo data already present\n')
        self.assertEqual(server.sent('PUT'), [])

    def test_the_other_language_needs_reset(self):
        server = FakeServer(projects=[project(10, 'Arbeit')])
        with self.assertRaisesRegex(SystemExit, 'the de demo data is on this server; add --reset'):
            self.run_main(['--lang', 'en'], server)
        self.assertEqual(server.sent('PUT'), [])

    def test_the_base_url_loses_its_trailing_slash(self):
        server = FakeServer(projects=[project(10, 'Arbeit')])
        self.run_main(['http://localhost:34599/'], server)
        self.assertEqual(seed_demo_data.BASE, 'http://localhost:34599')


class CallTest(unittest.TestCase):
    def error(self, code):
        return urllib.error.HTTPError('http://x', code, 'error', {}, None)

    def test_not_modified_is_success(self):
        with mock.patch('urllib.request.urlopen', side_effect=self.error(304)):
            self.assertIsNone(seed_demo_data.call('PATCH', '/user/settings/general', 'token', {'name': 'Tara'}))

    def test_a_locked_database_is_tried_again(self):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = b'{"id": 3}'
        with mock.patch('urllib.request.urlopen', side_effect=[self.error(500), response]), \
                mock.patch.object(seed_demo_data.time, 'sleep') as sleep:
            self.assertEqual(seed_demo_data.call('PUT', '/projects/1/tasks', 'token', {'title': 'x'}), {'id': 3})
        sleep.assert_called_once_with(1)

    def test_other_errors_stop(self):
        with mock.patch('urllib.request.urlopen', side_effect=self.error(403)), \
                self.assertRaisesRegex(SystemExit, 'PUT /projects: HTTP 403'):
            seed_demo_data.call('PUT', '/projects', 'token', {})


if __name__ == '__main__':
    unittest.main()
