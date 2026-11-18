#!/usr/bin/env python3
"""Fails when Flutter's stable release or Google Maven's cronet-bundled is
newer than the pins, the Flutter of tool/ci/pins.sh and the Cronet of
app/android/app/build.gradle.kts (the weekly workflow "Upstream versions").

  python3 -I tool/ci/upstream_versions.py

Exits 1 when either is newer, naming what to raise, and 2 when a pin or an
upstream list cannot be read.
"""
import json
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ElementTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PINS = os.path.join(ROOT, 'tool/ci/pins.sh')
GRADLE = os.path.join(ROOT, 'app/android/app/build.gradle.kts')
FLUTTER_RELEASES = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json'
CRONET_METADATA = 'https://dl.google.com/android/maven2/org/chromium/net/cronet-bundled/maven-metadata.xml'
FLUTTER_PIN = re.compile(r'^FLUTTER_VERSION=([0-9][0-9.]*)$', re.MULTILINE)
CRONET_PIN = re.compile(r'"org\.chromium\.net:cronet-bundled:([0-9][0-9.]*)"')
RELEASE = re.compile(r'[0-9]+(?:\.[0-9]+)*')
MAX_BYTES = 16 * 1024 * 1024


class UpstreamError(Exception):
    pass


def version(text):
    """A release version as a tuple of numbers; None for a prerelease."""
    return tuple(int(part) for part in text.split('.')) if RELEASE.fullmatch(text) else None


def newer(upstream, pinned):
    """Whether the upstream release is newer than the pin; 1.2 equals 1.2.0."""
    width = max(len(upstream), len(pinned))
    return upstream + (0,) * (width - len(upstream)) > pinned + (0,) * (width - len(pinned))


def pinned(path, pattern, what):
    try:
        with open(path, encoding='utf-8') as f:
            match = pattern.search(f.read())
    except OSError as e:
        raise UpstreamError(f'{what}: {e}') from e
    if not match:
        raise UpstreamError(f'{what}: no pin in {os.path.relpath(path, ROOT)}')
    return match.group(1)


def flutter_stable(data):
    """The version of the release that releases_linux.json names as stable."""
    try:
        release = json.loads(data)
        current = release['current_release']['stable']
        for entry in release['releases']:
            if entry.get('hash') == current and entry.get('channel') == 'stable':
                found = entry['version']
                break
        else:
            raise UpstreamError(f"Flutter's release list has no stable release {current}")
    except (ValueError, KeyError, TypeError) as e:
        raise UpstreamError(f"Flutter's release list cannot be read: {e!r}") from e
    if not isinstance(found, str) or version(found) is None:
        raise UpstreamError(f"Flutter's stable release has the version {found!r}")
    return found


def newest_release(data):
    """The highest version in a maven-metadata.xml that is not a prerelease."""
    try:
        root = ElementTree.fromstring(data)
    except ElementTree.ParseError as e:
        raise UpstreamError(f"Google Maven's cronet-bundled metadata cannot be read: {e}") from e
    releases = [text for text in (element.text or '' for element in root.iter('version')) if version(text.strip())]
    if not releases:
        raise UpstreamError("Google Maven's cronet-bundled metadata lists no release")
    return max((text.strip() for text in releases), key=version)


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'vikunja-app-ci'})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read(MAX_BYTES + 1)
    except OSError as e:
        raise UpstreamError(f'{url}: {e}') from e
    if len(data) > MAX_BYTES:
        raise UpstreamError(f'{url}: more than {MAX_BYTES} bytes')
    return data


def check():
    """(lines to print, whether something is newer)."""
    checks = (
        ('Flutter', pinned(PINS, FLUTTER_PIN, 'Flutter'), lambda: flutter_stable(fetch(FLUTTER_RELEASES)),
         'tool/ci/pins.sh', 'Raise FLUTTER_VERSION and both checksums (docs/releasing.md#raising-flutter)'),
        ('cronet-bundled', pinned(GRADLE, CRONET_PIN, 'Cronet'), lambda: newest_release(fetch(CRONET_METADATA)),
         'app/android/app/build.gradle.kts',
         'Raise it, and release a patch when its Chrome release fixes security issues (docs/releasing.md#raising-cronet)'),
    )
    lines = []
    outdated = False
    for name, pin, upstream_of, where, action in checks:
        upstream = upstream_of()
        if newer(version(upstream), version(pin)):
            outdated = True
            lines.append(f'error: {name} {upstream} is out, {where} pins {pin}. {action}.')
        elif newer(version(pin), version(upstream)):
            lines.append(f'{name}: {where} pins {pin}, newer than the {upstream} upstream lists.')
        else:
            lines.append(f'{name}: {pin} is the newest.')
    return lines, outdated


def main():
    try:
        lines, outdated = check()
    except UpstreamError as e:
        print(f'error: {e}', file=sys.stderr)
        return 2
    for line in lines:
        print(line, file=sys.stderr if line.startswith('error: ') else sys.stdout)
    return 1 if outdated else 0


if __name__ == '__main__':
    sys.exit(main())
