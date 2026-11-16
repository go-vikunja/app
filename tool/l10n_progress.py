#!/usr/bin/env python3
"""Prints the share of the template's messages that each ARB file translates
(D88). Crowdin exports only approved translations and leaves untranslated
messages out, so a message in a file counts as approved.

Usage: python3 -I tool/l10n_progress.py [--arb-dir DIR] [--shipped-list [FILE]]
           [--min PERCENT] [LOCALE ...]
  LOCALE          only these locales, as ARB files name them (de, pt_BR)
  --shipped-list  only the locales of the shipped list, by default
                  app/lib/app/l10n/shipped_locales.dart
  --min PERCENT   exit 1 when a listed locale has less

Without LOCALE or --shipped-list it lists every ARB file. A locale without an
ARB file has 0 %. Exits 2 when an ARB file or the shipped list cannot be read.
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARB_DIR = os.path.join(ROOT, 'app/lib/l10n/arb')
SHIPPED_LIST = os.path.join(ROOT, 'app/lib/app/l10n/shipped_locales.dart')
TEMPLATE = 'en'
ARB_FILE = re.compile(r'app_([A-Za-z]+(?:_[A-Za-z0-9]+)*)\.arb')
LOCALE_TAG = re.compile(r'[a-z]{2,3}(?:_[A-Z][a-z]{3})?(?:_(?:[A-Z]{2}|[0-9]{3}))?')

SHIPPED_ENTRIES = re.compile(r'\bshippedLocales\s*=\s*(?:<Locale>\s*)?\[(.*?)\]\s*;', re.DOTALL)
# Lenient about mixed quotes, which Dart itself refuses.
STRING = r"""\s*['"]([^'"\\]*)['"]\s*"""
LOCALE_CALL = re.compile(rf'\bLocale\({STRING}(?:,{STRING})?,?\s*\)')
SUBTAGS_CALL = re.compile(r'\bLocale\.fromSubtags\(([^()]*)\)')
SUBTAG = re.compile(rf'(languageCode|scriptCode|countryCode)\s*:{STRING}')
IGNORED = re.compile(r'//[^\n]*|\bconst\b')


class ProgressError(Exception):
    pass


def shipped_locales(text, name='the shipped list'):
    """The ARB names of the locales in `shippedLocales = [...]` of a Dart file."""
    entries = SHIPPED_ENTRIES.search(text)
    if not entries:
        raise ProgressError(f'{name}: no shippedLocales = [...] list')
    body = IGNORED.sub('', entries.group(1))
    found = []

    def locale(match):
        found.append((match.start(), '_'.join(part for part in match.groups() if part)))
        return ' ' * len(match.group(0))

    def subtags(match):
        parts = dict(SUBTAG.findall(match.group(1)))
        if 'languageCode' not in parts or SUBTAG.sub('', match.group(1)).strip(' \n\t,'):
            raise ProgressError(f'{name}: cannot read {match.group(0)!r}')
        found.append((match.start(), '_'.join(parts[key] for key in ('languageCode', 'scriptCode', 'countryCode')
                                              if parts.get(key))))
        return ' ' * len(match.group(0))

    rest = [part.strip() for part in LOCALE_CALL.sub(locale, SUBTAGS_CALL.sub(subtags, body)).split(',')]
    if any(rest):
        raise ProgressError(f"{name}: cannot read {', '.join(part for part in rest if part)} in shippedLocales")
    locales = [tag for _, tag in sorted(found)]
    if not locales:
        raise ProgressError(f'{name}: shippedLocales is empty')
    for tag in locales:
        if not LOCALE_TAG.fullmatch(tag):
            raise ProgressError(f'{name}: {tag!r} is not a locale')
    return locales


def messages(path):
    """The messages of an ARB file: every key but the @ metadata."""
    try:
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        raise ProgressError(f'{os.path.basename(path)}: {e}') from e
    if not isinstance(data, dict):
        raise ProgressError(f'{os.path.basename(path)}: not a JSON object')
    return {key: value for key, value in data.items() if not key.startswith('@')}


def _text(value):
    return isinstance(value, str) and bool(value.strip())


def arb_locales(arb_dir):
    return sorted(match.group(1) for name in os.listdir(arb_dir) if (match := ARB_FILE.fullmatch(name)))


def progress(arb_dir, locales):
    """(locale, translated, total, has a file) per locale, in their order."""
    template = messages(os.path.join(arb_dir, f'app_{TEMPLATE}.arb'))
    source = {key for key, value in template.items() if _text(value)}
    total = len(source)
    rows = []
    for locale in locales:
        path = os.path.join(arb_dir, f'app_{locale}.arb')
        if not os.path.isfile(path):
            rows.append((locale, 0, total, False))
            continue
        translation = messages(path)
        translated = sum(1 for key, value in translation.items() if key in source and _text(value))
        rows.append((locale, translated, total, True))
    return rows


def below(translated, total, minimum):
    return translated * 100 < minimum * total


def report(rows, minimum=None):
    width = max(len(locale) for locale, *_ in rows)
    digits = max(len(str(total)) for _, _, total, _ in rows)
    lines = []
    for locale, translated, total, has_file in rows:
        # Rounded down, so that 2257 of 2258 never reads 100.0 %.
        tenths = translated * 1000 // total if total else 1000
        notes = [] if has_file else [f'no app_{locale}.arb']
        if minimum is not None and below(translated, total, minimum):
            notes.append(f'below {minimum:g} %')
        line = f'{locale:<{width}}  {translated:>{digits}} of {total}  {tenths // 10:>3}.{tenths % 10} %'
        lines.append(f"{line}  {', '.join(notes)}" if notes else line)
    return '\n'.join(lines)


def percent(value):
    number = float(value)
    if not 0 <= number <= 100:
        raise argparse.ArgumentTypeError(f'{value} is not between 0 and 100')
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description="Prints the share of the template's messages each ARB file translates.")
    parser.add_argument('--arb-dir', default=ARB_DIR)
    parser.add_argument('--shipped-list', nargs='?', const=SHIPPED_LIST, metavar='FILE')
    parser.add_argument('--min', type=percent, metavar='PERCENT')
    parser.add_argument('locales', nargs='*', metavar='LOCALE')
    args = parser.parse_args(argv)
    if args.locales and args.shipped_list:
        parser.error('pass locales or --shipped-list, not both')
    try:
        if args.shipped_list:
            try:
                with open(args.shipped_list, encoding='utf-8') as f:
                    text = f.read()
            except OSError as e:
                raise ProgressError(str(e)) from e
            locales = shipped_locales(text, os.path.basename(args.shipped_list))
        elif args.locales:
            locales = [locale.replace('-', '_') for locale in args.locales]
            for locale in locales:
                if not LOCALE_TAG.fullmatch(locale):
                    parser.error(f'{locale!r} is not a locale such as de, pt_BR or zh_Hant')
        else:
            locales = arb_locales(args.arb_dir)
        rows = progress(args.arb_dir, locales)
    except ProgressError as e:
        print(f'error: {e}', file=sys.stderr)
        return 2
    print(report(rows, args.min))
    if args.min is not None and any(below(translated, total, args.min) for _, translated, total, _ in rows):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
