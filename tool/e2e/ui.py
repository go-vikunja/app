#!/usr/bin/env python3
"""Reads the app's screen from a uiautomator dump, for tool/e2e's scripts.

  python3 -I tool/e2e/ui.py find DUMP [--lang en|de] TEXT...
  python3 -I tool/e2e/ui.py fields [--enabled] DUMP
  python3 -I tool/e2e/ui.py has-app-text DUMP
  python3 -I tool/e2e/ui.py string LANG KEY
  python3 -I tool/e2e/ui.py keys KEY...
  python3 -I tool/e2e/ui.py demo-titles
  python3 -I tool/e2e/ui.py --self-test

find exits 0 when a node of the app shows one of the TEXTs: a message key of
app/lib/l10n/arb in English and German (or only --lang), or "=" and a literal
text. A message counts by its longest part without placeholders, dashes,
apostrophes and ellipses, which the screen may render differently.
fields prints the value of each text field (or each one that takes input)
and exits 1 when there is none; has-app-text exits 0 when any node of the
app has a text (Flutter builds its accessibility tree only once asked, so
an early dump can have none); string prints one message; keys fails unless
every KEY has a usable text in both languages; demo-titles prints the
titles of the open tasks of tool/seed_demo_data.py in both languages.
"""
import contextlib
import importlib.util
import io
import json
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ElementTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARB = os.path.join(ROOT, 'app', 'lib', 'l10n', 'arb', 'app_{}.arb')
LANGUAGES = ('en', 'de')
PACKAGE = 'io.vikunja.app'
BREAKS = re.compile('\\{[^}]*\\}|[—–\'’…“”„]')
MIN_FRAGMENT = 6
_arb_cache = {}


class UsageError(Exception):
    pass


def normal(text):
    return ' '.join(text.split())


def message(lang, key):
    if lang not in _arb_cache:
        with open(ARB.format(lang), encoding='utf-8') as arb:
            _arb_cache[lang] = json.load(arb)
    value = _arb_cache[lang].get(key)
    if not isinstance(value, str) or key.startswith('@'):
        raise UsageError(f'no message {key} in app_{lang}.arb')
    return value


def fragment(text):
    return max((normal(part).strip(' .,:;') for part in BREAKS.split(text)), key=len)


def wanted_texts(arguments, languages):
    wanted = []
    for argument in arguments:
        if argument.startswith('='):
            wanted.append(normal(argument[1:]))
        else:
            wanted.extend(fragment(message(lang, argument)) for lang in languages)
    return [text for text in wanted if text]


def app_nodes(path):
    try:
        nodes = list(ElementTree.parse(path).iter('node'))
    except (OSError, ElementTree.ParseError):
        return []
    return [node for node in nodes if node.get('package') == PACKAGE]


def app_texts(path):
    texts = []
    for node in app_nodes(path):
        for attribute in ('text', 'content-desc'):
            value = normal(node.get(attribute) or '')
            if value:
                texts.append(value)
    return texts


def find(path, arguments):
    languages = LANGUAGES
    if arguments[:1] == ['--lang']:
        if len(arguments) < 2 or arguments[1] not in LANGUAGES:
            raise UsageError('--lang takes en or de')
        languages, arguments = (arguments[1],), arguments[2:]
    if not arguments:
        raise UsageError('find needs a text')
    wanted = wanted_texts(arguments, languages)
    texts = app_texts(path)
    return any(text in shown for text in wanted for shown in texts)


def fields(path, enabled_only=False):
    return [normal(node.get('text') or '') for node in app_nodes(path)
            if node.get('class') == 'android.widget.EditText'
            and (not enabled_only or node.get('enabled') == 'true')]


def check_keys(keys):
    for key in keys:
        for lang in LANGUAGES:
            if len(fragment(message(lang, key))) < MIN_FRAGMENT:
                raise UsageError(f'{key} in app_{lang}.arb is too short to find on the screen')


def demo_titles():
    spec = importlib.util.spec_from_file_location('seed_demo_data', os.path.join(ROOT, 'tool', 'seed_demo_data.py'))
    seed = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(seed)
    return [texts[key] for texts in seed.TEXTS.values()
            for _, key, _, _, fields_ in seed.TASKS if not fields_.get('done')]


def self_test():
    assert fragment('Keeping you signed in to {host}…') == 'Keeping you signed in to'
    assert fragment('Deine Anmeldung bei {host} wird übernommen …') == 'Deine Anmeldung bei'
    assert fragment("It replaces the previous app on this device, and you're still signed in.") == \
        'It replaces the previous app on this device, and you'
    dump = ('<?xml version="1.0" encoding="UTF-8"?><hierarchy rotation="0">'
            '<node class="android.widget.FrameLayout" package="com.android.systemui" text="This is the new Vikunja app"/>'
            '<node class="android.view.View" package="io.vikunja.app" text="" '
            'content-desc="Das ist die neue Vikunja-App&#10;Sie ersetzt die bisherige App auf diesem Gerät. '
            'Dein Server ist schon eingetragen – melde dich noch einmal an, um weiterzumachen."/>'
            '<node class="android.widget.EditText" package="io.vikunja.app" enabled="false" '
            'text="http://localhost:34527"/>'
            '<node class="android.widget.EditText" package="io.vikunja.app" enabled="true" text=""/>'
            '</hierarchy>')
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, 'dump.xml')
        with open(path, 'w', encoding='utf-8') as file:
            file.write(dump)
        assert find(path, ['previousAppNoteTitle'])
        assert find(path, ['--lang', 'de', 'previousAppNoteSignInAgain'])
        assert not find(path, ['--lang', 'en', 'previousAppNoteTitle'])
        assert not find(path, ['previousAppNoteSignedIn'])
        assert find(path, ['=localhost:34527'])
        assert fields(path) == ['http://localhost:34527', '']
        assert fields(path, enabled_only=True) == ['']
        with contextlib.redirect_stdout(io.StringIO()):
            assert main(['fields', '--enabled', path]) == 0
            assert main(['fields', os.path.join(folder, 'missing.xml')]) == 1
        assert app_texts(os.path.join(folder, 'missing.xml')) == []
    titles = demo_titles()
    assert 'Pay the rent' in titles and 'Miete überweisen' in titles and 'Send the kickoff notes' not in titles
    print('ui.py self-test passed')
    return 0


def main(arguments):
    if arguments == ['--self-test']:
        return self_test()
    command, rest = (arguments[0], arguments[1:]) if arguments else ('', [])
    if command == 'find' and rest:
        return 0 if find(rest[0], rest[1:]) else 1
    if command == 'fields' and rest and len(rest) == 1 + (rest[0] == '--enabled'):
        values = fields(rest[-1], rest[0] == '--enabled')
        for value in values:
            print(value)
        return 0 if values else 1
    if command == 'has-app-text' and len(rest) == 1:
        return 0 if app_texts(rest[0]) else 1
    if command == 'string' and len(rest) == 2 and rest[0] in LANGUAGES:
        print(message(rest[0], rest[1]))
        return 0
    if command == 'keys' and rest:
        check_keys(rest)
        return 0
    if command == 'demo-titles' and not rest:
        print('\n'.join(demo_titles()))
        return 0
    raise UsageError('see the usage at the top of tool/e2e/ui.py')


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except UsageError as error:
        print(f'error: {error}', file=sys.stderr)
        sys.exit(2)
