#!/usr/bin/env python3
"""Checks the store listings in fastlane/ against the stores' limits and the
project's rules (docs/store-listing.md).

Usage: python3 -I tool/check_store_metadata.py [--strict] [--root DIR]
  --strict  also fail on missing screenshots, i.e. check that the listing can
            be submitted
"""
import argparse
import os
import re
import struct
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = {'en-GB': 'en', 'de-DE': 'de'}
COPYRIGHT_YEAR = 2026

ANDROID_FIELDS = {'title.txt': 30, 'short_description.txt': 80, 'full_description.txt': 4000}
IOS_FIELDS = {
    'name.txt': 30, 'subtitle.txt': 30, 'description.txt': 4000, 'keywords.txt': 100,
    'promotional_text.txt': 170, 'release_notes.txt': 4000,
    'support_url.txt': 255, 'privacy_url.txt': 255, 'marketing_url.txt': 255,
}
IOS_SHARED = {'copyright.txt', 'primary_category.txt'}
REVIEW_FIELDS = {'notes.txt', 'demo_user.txt', 'demo_password.txt', 'email_address.txt'}
BYTE_LIMITS = {'keywords.txt', 'notes.txt'}
REVIEW_NOTES_BYTES = 4000
CHANGELOG_LIMIT = 500
MULTILINE = {'full_description.txt', 'description.txt', 'promotional_text.txt', 'release_notes.txt', 'notes.txt'}
OPTIONAL = {'release_notes.txt'}
# The app's pages on the owner's website until step 38f, per listing
# language, the contact and the App Store copyright (D76).
WEBSITE_HOST = 'coderoftime.dev'
URLS = {
    'support_url.txt': {'en': 'https://coderoftime.dev/rurana/support/',
                        'de': 'https://coderoftime.dev/de/rurana/support/'},
    'privacy_url.txt': {'en': 'https://coderoftime.dev/rurana/privacy/',
                        'de': 'https://coderoftime.dev/rurana/privacy/#de'},
    'marketing_url.txt': {'en': 'https://coderoftime.dev/rurana/', 'de': 'https://coderoftime.dev/de/rurana/'},
}
FIXED = {'email_address.txt': 'coderoftime@gmail.com', 'copyright.txt': f'{COPYRIGHT_YEAR} Benedikt Lesch'}
# App Store Connect's category ids, as fastlane deliver takes them.
CATEGORIES = {
    'BOOKS', 'BUSINESS', 'DEVELOPER_TOOLS', 'EDUCATION', 'ENTERTAINMENT', 'FINANCE', 'FOOD_AND_DRINK', 'GAMES',
    'GRAPHICS_AND_DESIGN', 'HEALTH_AND_FITNESS', 'LIFESTYLE', 'MAGAZINES_AND_NEWSPAPERS', 'MEDICAL', 'MUSIC',
    'NAVIGATION', 'NEWS', 'PHOTO_AND_VIDEO', 'PRODUCTIVITY', 'REFERENCE', 'SHOPPING', 'SOCIAL_NETWORKING',
    'SPORTS', 'TRAVEL', 'UTILITIES', 'WEATHER',
}

APP_NAME = 'Vikunja'
UNOFFICIAL = re.compile(r'(?i)\bunofficial\b|not affiliated with|inoffiziell|gehört nicht zum Vikunja-Projekt')
# The name fields and the keywords must not name other apps or companies
# (D76; App Store Connect, keywords).
NAME_FIELDS = {'title.txt', 'name.txt', 'subtitle.txt', 'keywords.txt'}
FOREIGN_NAMES = re.compile(r'(?i)todoist|ticktick|trello|asana|notion|nextcloud|google|microsoft|apple')
SHORT_FIELDS = {'title.txt', 'short_description.txt', 'name.txt', 'subtitle.txt', 'keywords.txt',
                'promotional_text.txt'}
CLAIM_WORDS = ('best', '#1', 'number one', 'top', 'free', 'new', 'sale', 'download now', 'install now',
               'beste', 'kostenlos', 'gratis', 'neu', 'jetzt laden')
CLAIMS = re.compile(r'(?i)(?<![\w-])(' + '|'.join(map(re.escape, CLAIM_WORDS)) + r')(?![\w-])')
OTHER_PLATFORM = {
    'android': re.compile(r'(?i)\b(iphone|ipad|ios|app store|testflight|apple)\b'),
    'ios': re.compile(r'(?i)\b(android|google play|play store)\b'),
}
EMOJI = re.compile('[\U0001F000-\U0001FAFF\u2600-\u27BF\uFE0F\u200D]')

# Play (Play Console Help 9866151): no alpha; phones 320-3840 px, tablets
# 1080-7680 px, the long side at most twice the short side, 8 per type.
PLAY_SCREENSHOTS = {
    'phoneScreenshots': (320, 3840), 'sevenInchScreenshots': (1080, 7680), 'tenInchScreenshots': (1080, 7680),
}
PLAY_IMAGES = {'icon.png': ((512, 512), True), 'featureGraphic.png': ((1024, 500), False)}
# App Store Connect screenshot specifications, portrait sizes; landscape is
# the same pair swapped. No alpha, 10 per size and language.
APPLE_SIZES = {
    (1320, 2868): 'iPhone 6.9"', (1290, 2796): 'iPhone 6.9"', (1260, 2736): 'iPhone 6.9"',
    (1284, 2778): 'iPhone 6.5"', (1242, 2688): 'iPhone 6.5"',
    (1206, 2622): 'iPhone 6.3"', (1179, 2556): 'iPhone 6.3"',
    (2064, 2752): 'iPad 13"', (2048, 2732): 'iPad 13"',
}
# docs/store-listing.md: Play needs two phone screenshots to publish; for
# Apple a 6.9" (or 6.5") set, a 6.3" set and, as the app runs on iPad, a
# 13" iPad set.
APPLE_REQUIRED = (('iPhone 6.9"', 'iPhone 6.5"'), ('iPhone 6.3"',), ('iPad 13"',))
PLAY_MIN_PHONE = 2


class MetadataError(Exception):
    pass


def read_value(path):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    return text[:-1] if text.endswith('\n') else text


def png_or_jpeg_size(path):
    """(width, height, has_alpha) from the file's header."""
    with open(path, 'rb') as f:
        data = f.read()
    if data.startswith(b'\x89PNG\r\n\x1a\n') and len(data) >= 26:
        width, height, _, colour_type = struct.unpack('>IIBB', data[16:26])
        alpha = colour_type in (4, 6)
        offset = 8
        while offset + 8 <= len(data):
            length, kind = struct.unpack('>I4s', data[offset:offset + 8])
            if kind == b'tRNS':
                alpha = True
            if kind in (b'IDAT', b'IEND'):
                break
            offset += 12 + length
        return width, height, alpha
    if data.startswith(b'\xff\xd8'):
        offset = 2
        while offset + 4 <= len(data):
            if data[offset] != 0xFF:
                break
            marker = data[offset + 1]
            length = struct.unpack('>H', data[offset + 2:offset + 4])[0]
            if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC) and offset + 9 <= len(data):
                height, width = struct.unpack('>HH', data[offset + 5:offset + 9])
                return width, height, False
            offset += 2 + length
    raise MetadataError('not a PNG or JPEG image')


class Checker:
    def __init__(self, root, strict):
        self.root = root
        self.metadata = os.path.join(root, 'fastlane', 'metadata')
        self.strict = strict
        self.errors = []

    def error(self, path, message):
        self.errors.append(f'{os.path.relpath(path, self.root)}: {message}')

    def run(self):
        for locale, lang in LOCALES.items():
            self.check_directory(os.path.join(self.metadata, 'android', locale), ANDROID_FIELDS, 'android', lang,
                                 extra={'changelogs', 'images'})
            self.check_directory(os.path.join(self.metadata, locale), IOS_FIELDS, 'ios', lang)
            self.check_changelogs(os.path.join(self.metadata, 'android', locale, 'changelogs'))
        self.check_directory(self.metadata, {name: 255 for name in IOS_SHARED}, 'ios', None,
                             extra={'android', 'review_information', *LOCALES})
        self.check_directory(os.path.join(self.metadata, 'review_information'),
                             {name: (REVIEW_NOTES_BYTES if name == 'notes.txt' else 255) for name in REVIEW_FIELDS},
                             'ios', None)
        self.check_category()
        self.check_screenshots()
        return self.errors

    def check_directory(self, directory, fields, platform, lang, extra=()):
        if not os.path.isdir(directory):
            self.error(directory, 'missing')
            return
        for entry in sorted(os.listdir(directory)):
            if entry not in fields and entry not in extra and not entry.startswith('.'):
                self.error(os.path.join(directory, entry), 'not a file of this layout')
        for name, limit in fields.items():
            path = os.path.join(directory, name)
            if not os.path.isfile(path):
                self.error(path, 'missing')
                continue
            self.check_value(path, name, read_value(path), limit, platform, lang)

    def check_value(self, path, name, value, limit, platform, lang):
        if not value:
            if name not in OPTIONAL:
                self.error(path, 'empty')
            return
        if value != value.strip():
            self.error(path, 'leading or trailing whitespace')
        if name not in MULTILINE and '\n' in value:
            self.error(path, 'must be one line')
        size = len(value.encode('utf-8')) if name in BYTE_LIMITS else len(value)
        if size > limit:
            unit = 'bytes' if name in BYTE_LIMITS else 'characters'
            self.error(path, f'{size} {unit}, the limit is {limit}')
        if name in NAME_FIELDS and FOREIGN_NAMES.search(value):
            self.error(path, f'names another product or company: {FOREIGN_NAMES.search(value).group(0)}')
        if name in SHORT_FIELDS and CLAIMS.search(value):
            self.error(path, f'a ranking, price or call-to-action word: {CLAIMS.search(value).group(0)}')
        if name in ('title.txt', 'short_description.txt', 'name.txt', 'subtitle.txt') and EMOJI.search(value):
            self.error(path, 'emoji')
        if lang and OTHER_PLATFORM[platform].search(value):
            self.error(path, f'names the other platform: {OTHER_PLATFORM[platform].search(value).group(0)}')
        if UNOFFICIAL.search(value):
            self.error(path, 'calls the app unofficial (D83)')
        if name in ('title.txt', 'name.txt') and value != APP_NAME:
            self.error(path, f'must be "{APP_NAME}"')
        if name == 'keywords.txt':
            self.check_keywords(path, value)
        if name in URLS:
            self.check_url(path, value, URLS[name][lang])
        if name in FIXED and value != FIXED[name]:
            self.error(path, f'must be "{FIXED[name]}"')

    def check_url(self, path, value, expected):
        parts = urllib.parse.urlsplit(value)
        if parts.scheme != 'https' or parts.hostname != WEBSITE_HOST:
            self.error(path, f'must be an https URL on {WEBSITE_HOST}')
        elif value != expected:
            self.error(path, f'must be {expected}')

    def check_keywords(self, path, value):
        keywords = value.split(',')
        if any(keyword != keyword.strip() for keyword in keywords):
            self.error(path, 'spaces around commas waste bytes')
        for keyword in keywords:
            if len(keyword.strip()) <= 2:
                self.error(path, f'keyword too short: "{keyword}"')
            if APP_NAME.lower() in keyword.lower():
                self.error(path, 'the app name is indexed already')
        lowered = [keyword.strip().lower() for keyword in keywords]
        if len(set(lowered)) != len(lowered):
            self.error(path, 'repeated keyword')

    def check_changelogs(self, directory):
        if not os.path.isdir(directory):
            return
        for entry in sorted(os.listdir(directory)):
            path = os.path.join(directory, entry)
            if entry.startswith('.'):
                continue
            if not re.fullmatch(r'(default|[1-9][0-9]*)\.txt', entry):
                self.error(path, 'a changelog is <version code>.txt or default.txt')
                continue
            value = read_value(path)
            if not value:
                self.error(path, 'empty')
            elif len(value) > CHANGELOG_LIMIT:
                self.error(path, f'{len(value)} characters, the limit is {CHANGELOG_LIMIT}')

    def check_category(self):
        path = os.path.join(self.metadata, 'primary_category.txt')
        if os.path.isfile(path) and read_value(path) and read_value(path) not in CATEGORIES:
            self.error(path, f'not an App Store category id: {read_value(path)}')

    def check_screenshots(self):
        for locale in LOCALES:
            images = os.path.join(self.metadata, 'android', locale, 'images')
            phones = self.check_play_images(images)
            if self.strict and phones < PLAY_MIN_PHONE:
                self.error(images, f'{phones} phone screenshots, Play needs at least {PLAY_MIN_PHONE}')
            shots = os.path.join(self.root, 'fastlane', 'screenshots', locale)
            classes = self.check_apple_screenshots(shots)
            if self.strict:
                for alternatives in APPLE_REQUIRED:
                    if not any(classes.get(size) for size in alternatives):
                        self.error(shots, f'no {" or ".join(alternatives)} screenshots')
        screenshots = os.path.join(self.root, 'fastlane', 'screenshots')
        if os.path.isdir(screenshots):
            for entry in sorted(os.listdir(screenshots)):
                if entry not in LOCALES and not entry.startswith('.'):
                    self.error(os.path.join(screenshots, entry), 'not a listing language')

    def image(self, path):
        if not re.search(r'\.(png|jpe?g)$', path):
            self.error(path, 'not a .png or .jpg file')
            return None
        try:
            return png_or_jpeg_size(path)
        except MetadataError as error:
            self.error(path, str(error))
            return None

    def check_play_images(self, images):
        phones = 0
        if not os.path.isdir(images):
            return phones
        for entry in sorted(os.listdir(images)):
            path = os.path.join(images, entry)
            if entry.startswith('.'):
                continue
            if entry in PLAY_IMAGES:
                size, alpha_allowed = PLAY_IMAGES[entry]
                found = self.image(path)
                if found and (found[:2] != size or (found[2] and not alpha_allowed)):
                    self.error(path, f'must be {size[0]}x{size[1]}{"" if alpha_allowed else " without alpha"}')
                continue
            if entry not in PLAY_SCREENSHOTS or not os.path.isdir(path):
                self.error(path, 'not a file of this layout')
                continue
            low, high = PLAY_SCREENSHOTS[entry]
            files = [name for name in sorted(os.listdir(path)) if not name.startswith('.')]
            if len(files) > 8:
                self.error(path, f'{len(files)} screenshots, Play takes 8')
            for name in files:
                found = self.image(os.path.join(path, name))
                if not found:
                    continue
                width, height, alpha = found
                short, long = sorted((width, height))
                if alpha:
                    self.error(os.path.join(path, name), 'has an alpha channel')
                if short < low or long > high or long > 2 * short:
                    self.error(os.path.join(path, name),
                               f'{width}x{height}: sides {low}-{high} px, the long side at most twice the short')
                elif entry == 'phoneScreenshots':
                    phones += 1
        return phones

    def check_apple_screenshots(self, directory):
        classes = {}
        if not os.path.isdir(directory):
            return classes
        for name in sorted(os.listdir(directory)):
            path = os.path.join(directory, name)
            if name.startswith('.'):
                continue
            found = self.image(path)
            if not found:
                continue
            width, height, alpha = found
            size = APPLE_SIZES.get((width, height)) or APPLE_SIZES.get((height, width))
            if alpha:
                self.error(path, 'has an alpha channel')
            if not size:
                self.error(path, f'{width}x{height} is none of the App Store sizes used here')
                continue
            classes[size] = classes.get(size, 0) + 1
        for size, count in classes.items():
            if count > 10:
                self.error(directory, f'{count} {size} screenshots, App Store Connect takes 10')
        return classes


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--strict', action='store_true')
    parser.add_argument('--root', default=ROOT)
    args = parser.parse_args(argv)
    errors = Checker(args.root, args.strict).run()
    for message in errors:
        print(f'error: {message}', file=sys.stderr)
    mode = 'strict' if args.strict else 'normal'
    if errors:
        print(f'store metadata ({mode}): {len(errors)} errors', file=sys.stderr)
        return 1
    print(f'store metadata ({mode}): OK')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
