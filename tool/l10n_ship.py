#!/usr/bin/env python3
"""Ships every language whose ARB file has at least 50 % of the English texts
approved (decision log: Languages): it adds the language to the lists that
`app/test/l10n/shipped_locales_test.dart` and `store_listing_languages_test.dart`
keep equal. The workflow "Crowdin" runs it on the translations it commits, so
the pull request carries the languages a maintainer then reviews.

Usage: python3 -I tool/l10n_ship.py [--root DIR] [--min PERCENT] [--dry-run] [--changed-files FILE]

Prints what it ships and, for a language at the share that it does not ship,
why. Without a change it prints nothing and writes nothing.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import l10n_progress  # noqa: E402

DEFAULT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN_PERCENT = 50.0

# Right-to-left languages wait for a layout pass, Esperanto has no Material
# texts (decision log: Languages).
HELD_BACK = {
    'ar': 'right-to-left layout is not checked',
    'fa': 'right-to-left layout is not checked',
    'he': 'right-to-left layout is not checked',
    'eo': 'Material has no texts for it',
}

# The languages Flutter's Material texts cover as a class of their own
# (MaterialLocalization<Code>), with the name the store descriptions use in
# English and in German.
NAMES = {
    'bg': ('Bulgarian', 'Bulgarisch'),
    'ca': ('Catalan', 'Katalanisch'),
    'cs': ('Czech', 'Tschechisch'),
    'da': ('Danish', 'Dänisch'),
    'el': ('Greek', 'Griechisch'),
    'es': ('Spanish', 'Spanisch'),
    'fi': ('Finnish', 'Finnisch'),
    'fr': ('French', 'Französisch'),
    'hr': ('Croatian', 'Kroatisch'),
    'hu': ('Hungarian', 'Ungarisch'),
    'it': ('Italian', 'Italienisch'),
    'ja': ('Japanese', 'Japanisch'),
    'ko': ('Korean', 'Koreanisch'),
    'lt': ('Lithuanian', 'Litauisch'),
    'nb': ('Norwegian Bokmål', 'Norwegisch (Bokmål)'),
    'nl': ('Dutch', 'Niederländisch'),
    'pl': ('Polish', 'Polnisch'),
    'pt': ('Portuguese', 'Portugiesisch'),
    'ro': ('Romanian', 'Rumänisch'),
    'ru': ('Russian', 'Russisch'),
    'sk': ('Slovak', 'Slowakisch'),
    'sl': ('Slovenian', 'Slowenisch'),
    'sr': ('Serbian', 'Serbisch'),
    'sv': ('Swedish', 'Schwedisch'),
    'th': ('Thai', 'Thailändisch'),
    'tr': ('Turkish', 'Türkisch'),
    'uk': ('Ukrainian', 'Ukrainisch'),
    'vi': ('Vietnamese', 'Vietnamesisch'),
    'zh': ('Chinese', 'Chinesisch'),
    'en': ('English', 'Englisch'),
    'de': ('German', 'Deutsch'),
}

SHIPPED_DART = 'app/lib/app/l10n/shipped_locales.dart'
ANDROID_CONFIG = 'app/android/app/src/main/res/xml/locales_config.xml'
IOS_PLISTS = ('app/ios/Runner/Info.plist', 'app/ios/VikunjaWidgets/Info.plist')
PREVIOUS_APP = 'app/android/app/src/main/kotlin/io/vikunja/app/PreviousApp.kt'
PICKER = 'app/lib/app/l10n/picker_localizations.dart'
L10N = 'app/lib/app/l10n/l10n.dart'
STORE_TEST = 'app/test/l10n/store_listing_languages_test.dart'
DESCRIPTIONS = {
    'en-US': ('Languages', 'and', 0, ('fastlane/metadata/en-US/description.txt',
                                      'fastlane/metadata/android/en-US/full_description.txt')),
    'de-DE': ('Sprachen', 'und', 1, ('fastlane/metadata/de-DE/description.txt',
                                     'fastlane/metadata/android/de-DE/full_description.txt')),
}
PLAIN_LANGUAGE = re.compile(r'[a-z]{2,3}')


class ShipError(Exception):
    pass


def read(root, path):
    try:
        with open(os.path.join(root, path), encoding='utf-8') as f:
            return f.read()
    except OSError as e:
        raise ShipError(str(e)) from e


def edit_once(text, pattern, edit, what, flags=0):
    """The text with the first match of the pattern replaced by edit(match)."""
    new, count = re.subn(pattern, edit, text, count=1, flags=flags)
    if count != 1:
        raise ShipError(f'{what}: the expected place was not found')
    return new


def replace_once(text, pattern, replacement, what, flags=0):
    return edit_once(text, pattern, lambda _: replacement, what, flags)


def dart_list(codes):
    one_line = 'const List<Locale> shippedLocales = [' + ', '.join(f"Locale('{c}')" for c in codes) + '];'
    if len(one_line) <= 80:
        return one_line
    return 'const List<Locale> shippedLocales = [\n' + ''.join(f"  Locale('{c}'),\n" for c in codes) + '];'


def dart_names(names):
    one_line = '    names: {' + ', '.join(f"'{c}': '{n}'" for c, n in names.items()) + '},'
    if len(one_line) <= 80:
        return one_line
    return '    names: {\n' + ''.join(f"      '{c}': '{n}',\n" for c, n in names.items()) + '    },'


def class_name(code):
    return f'_{code.capitalize()}Localizations'


def picker_class(code):
    header = f'final class {class_name(code)} extends MaterialLocalization{code.capitalize()} with _AppOverrides {{'
    if len(header) > 80:
        header = header.replace(' with', '\n    with')
    return f'''
{header}
  new(
    _Formats formats, {{
    required this.regional,
    required this.firstDayOfWeek,
    required this.use24Hour,
  }}) : super(
         fullYearFormat: formats.fullYear,
         compactDateFormat: formats.compactDate,
         shortDateFormat: formats.shortDate,
         mediumDateFormat: formats.mediumDate,
         longDateFormat: formats.longDate,
         yearMonthFormat: formats.yearMonth,
         shortMonthDayFormat: formats.shortMonthDay,
         decimalFormat: formats.decimal,
         twoDigitZeroPaddedFormat: formats.twoDigitZeroPadded,
       );

  @override
  final MaterialLocalizations regional;

  @override
  final int? firstDayOfWeek;

  @override
  final bool? use24Hour;
}}
'''


def candidates(root, minimum):
    """(to ship, held back as (locale, share, reason)), each by locale."""
    arb_dir = os.path.join(root, 'app/lib/l10n/arb')
    try:
        shipped = l10n_progress.shipped_locales(read(root, SHIPPED_DART), 'shipped_locales.dart')
        rows = l10n_progress.progress(arb_dir, l10n_progress.arb_locales(arb_dir))
    except l10n_progress.ProgressError as e:
        raise ShipError(str(e)) from e
    ship, held = [], []
    for locale, translated, total, _ in rows:
        if locale in shipped or l10n_progress.below(translated, total, minimum) or locale == l10n_progress.TEMPLATE:
            continue
        share = translated * 100 / total if total else 100
        if locale in HELD_BACK:
            held.append((locale, share, HELD_BACK[locale]))
        elif not PLAIN_LANGUAGE.fullmatch(locale):
            held.append((locale, share, 'a regional or script variant is added by hand (CONTRIBUTING.md)'))
        elif locale not in NAMES:
            held.append((locale, share, 'no name for the store descriptions in tool/l10n_ship.py'))
        else:
            ship.append((locale, share))
    return shipped, ship, held


def apply(root, shipped, added):
    """The new text of each file that changes, by path."""
    codes = list(shipped) + added
    out = {}

    text = read(root, SHIPPED_DART)
    out[SHIPPED_DART] = replace_once(text, r'const List<Locale> shippedLocales = \[.*?\];', dart_list(codes),
                                     SHIPPED_DART, re.DOTALL)

    text = read(root, ANDROID_CONFIG)
    tags = ''.join(f'    <locale android:name="{c}" />\n' for c in added)
    out[ANDROID_CONFIG] = replace_once(text, r'</locale-config>', tags + '</locale-config>', ANDROID_CONFIG)

    for path in IOS_PLISTS:
        if not os.path.isfile(os.path.join(root, path)):
            continue
        text = read(root, path)
        if '<key>CFBundleLocalizations</key>' not in text:
            continue
        strings = ''.join(f'\t\t<string>{c}</string>\n' for c in added)
        out[path] = edit_once(text, r'(<key>CFBundleLocalizations</key>\s*<array>.*?\n)(\s*</array>)',
                              lambda m: m.group(1) + strings + m.group(2), path, re.DOTALL)

    text = read(root, PREVIOUS_APP)
    out[PREVIOUS_APP] = replace_once(text, r'val LANGUAGES = setOf\([^)]*\)',
                                     'val LANGUAGES = setOf(' + ', '.join(f'"{c}"' for c in codes) + ')', PREVIOUS_APP)

    text = read(root, L10N)
    generated = 'import \'package:vikunja_mobile/l10n/generated/app_localizations_'
    imports = re.search(rf'(?:^{re.escape(generated)}[a-z]+\.dart\';\n)+', text, re.MULTILINE)
    if not imports:
        raise ShipError(f'{L10N}: the imports of the generated classes were not found')
    lines = imports.group(0).splitlines() + [f"{generated}{c}.dart';" for c in added]
    text = text[:imports.start()] + ''.join(f'{line}\n' for line in sorted(lines)) + text[imports.end():]
    cases = ''.join(f'      AppLocalizations{c.capitalize()}() => AppLocalizations{c.capitalize()}(locale.toString()),\n'
                    for c in added)
    out[L10N] = replace_once(text, r'      final other => other,', cases + '      final other => other,', L10N)

    text = read(root, PICKER)
    entries = ''.join(f"    '{c}': {class_name(c)}.new,\n" for c in added)
    text = edit_once(text, r"(static const Map<String, _LocalizationsFactory> _languages = \{\n.*?\n)(  \};)",
                     lambda m: m.group(1) + entries + m.group(2), PICKER, re.DOTALL)
    out[PICKER] = text.rstrip('\n') + '\n' + ''.join(picker_class(c) for c in added)

    for locale, (label, conjunction, index, paths) in DESCRIPTIONS.items():
        names = sorted(NAMES[c][index] for c in codes)
        sentence = names[0] if len(names) == 1 else f"{', '.join(names[:-1])} {conjunction} {names[-1]}"
        for path in paths:
            out[path] = replace_once(read(root, path), rf'^• {label}: .*\.$', f'• {label}: {sentence}.', path,
                                     re.MULTILINE)

    text = read(root, STORE_TEST)
    for locale, (label, conjunction, index, _) in DESCRIPTIONS.items():
        names = {c: NAMES[c][index] for c in codes}
        pattern = rf"(  '{locale}': \(\n    label: '{label}',\n    and: '{conjunction}',\n)    names: \{{.*?\}},"
        text = edit_once(text, pattern, lambda m: m.group(1) + dart_names(names), STORE_TEST, re.DOTALL)
    out[STORE_TEST] = text

    return {path: new for path, new in out.items() if new != read(root, path)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--root', default=DEFAULT_ROOT)
    parser.add_argument('--min', type=l10n_progress.percent, default=MIN_PERCENT, metavar='PERCENT')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--changed-files', metavar='FILE', help='write the paths it changed, one per line')
    args = parser.parse_args(argv)
    try:
        shipped, ship, held = candidates(args.root, args.min)
        for locale, share, reason in held:
            print(f'Not shipped: {locale}, {share:.1f} %: {reason}')
        if not ship:
            return 0
        added = [locale for locale, _ in ship]
        changes = apply(args.root, shipped, added)
        for locale, share in ship:
            print(f'Ships: {locale} ({NAMES[locale][0]}), {share:.1f} %')
        if not args.dry_run:
            for path, text in changes.items():
                with open(os.path.join(args.root, path), 'w', encoding='utf-8') as f:
                    f.write(text)
        if args.changed_files and not args.dry_run:
            with open(args.changed_files, 'w', encoding='utf-8') as f:
                f.write(''.join(f'{path}\n' for path in sorted(changes)))
        print('Changed: ' + ', '.join(sorted(changes)))
    except ShipError as e:
        print(f'error: {e}', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
