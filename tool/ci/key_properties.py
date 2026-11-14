#!/usr/bin/env python3
"""Reads the signing values of a key.properties text (D86).

  python3 -I tool/ci/key_properties.py ENV_NAME

The text comes from the environment variable ENV_NAME, never from argv or a
file, and is parsed with the rules of java.util.Properties.load, as the old
app's Gradle read the same secret. Prints storePassword, keyAlias and
keyPassword, each followed by a NUL; storeFile and other keys are ignored.
Errors name the variable and the keys, never a value.
"""
import os
import sys

REQUIRED = ('storePassword', 'keyAlias', 'keyPassword')
WHITESPACE = ' \t\f'
ESCAPES = {'t': '\t', 'n': '\n', 'r': '\r', 'f': '\f'}


class PropertiesError(Exception):
    pass


def _trailing_backslashes(line):
    return len(line) - len(line.rstrip('\\'))


def logical_lines(text):
    natural = text.replace('\r\n', '\n').replace('\r', '\n').split('\n')
    index = 0
    while index < len(natural):
        line = natural[index].lstrip(WHITESPACE)
        index += 1
        if not line or line[0] in '#!':
            continue
        parts = []
        while _trailing_backslashes(line) % 2 == 1:
            parts.append(line[:-1])
            if index == len(natural):
                line = ''
                break
            line = natural[index].lstrip(WHITESPACE)
            index += 1
        parts.append(line)
        yield ''.join(parts)


def unescape(text):
    out = []
    index = 0
    while index < len(text):
        char = text[index]
        index += 1
        if char != '\\' or index == len(text):
            if char != '\\':
                out.append(char)
            continue
        char = text[index]
        index += 1
        if char == 'u':
            digits = text[index:index + 4]
            if len(digits) != 4 or any(c not in '0123456789abcdefABCDEF' for c in digits):
                raise PropertiesError('malformed \\uxxxx escape')
            out.append(chr(int(digits, 16)))
            index += 4
        else:
            out.append(ESCAPES.get(char, char))
    return ''.join(out)


def split_line(line):
    index = 0
    while index < len(line):
        char = line[index]
        if char == '\\':
            index += 2
            continue
        if char in '=:' or char in WHITESPACE:
            break
        index += 1
    key = line[:index]
    rest = line[index:].lstrip(WHITESPACE)
    if rest[:1] in ('=', ':'):
        rest = rest[1:].lstrip(WHITESPACE)
    return unescape(key), unescape(rest)


def parse(text):
    properties = {}
    for line in logical_lines(text):
        key, value = split_line(line)
        properties[key] = value
    return properties


def main(arguments, environ):
    if len(arguments) != 1:
        print('usage: python3 -I tool/ci/key_properties.py ENV_NAME', file=sys.stderr)
        return 2
    name = arguments[0]
    text = environ.get(name, '')
    if not text:
        print(f'error: {name} is empty', file=sys.stderr)
        return 1
    try:
        properties = parse(text)
    except PropertiesError as error:
        print(f'error: {name}: {error}', file=sys.stderr)
        return 1
    missing = [key for key in REQUIRED if not properties.get(key)]
    if missing:
        print(f'error: {name} has no {", ".join(missing)}', file=sys.stderr)
        return 1
    with_nul = [key for key in REQUIRED if '\0' in properties[key]]
    if with_nul:
        print(f'error: {name}: {", ".join(with_nul)} contains a NUL character', file=sys.stderr)
        return 1
    out = sys.stdout.buffer
    for key in REQUIRED:
        out.write(properties[key].encode('utf-8', 'surrogateescape') + b'\0')
    out.flush()
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:], os.environ))
