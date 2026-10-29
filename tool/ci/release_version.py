#!/usr/bin/env python3
"""Prints the build name and number of a release tag (D73).

  python3 -I tool/ci/release_version.py TAG [--pubspec app/pubspec.yaml]

TAG is vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-beta.N; it prints

  BUILD_NAME=1.2.3-beta.4
  BUILD_NUMBER=1020304
  CHANNEL=beta
  IOS_BUILD_NAME=1.2.3
  IOS_BUILD_NUMBER=1020304

The build number is major * 1,000,000 + minor * 10,000 + patch * 100 + n,
with n the beta number (1-98) or 99 for the final release, so that every beta
orders below its release and Play's limit of 2,100,000,000 holds. iOS takes
only MAJOR.MINOR.PATCH as CFBundleShortVersionString, so the betas of a
release share its version there and differ by CFBundleVersion, the same build
number. Fails on any other tag and when the pubspec's version name (before
the +) is not the build name: the release commit bumps the pubspec.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PUBSPEC = os.path.join(ROOT, 'app/pubspec.yaml')
TAG = re.compile(r'v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-beta\.([1-9][0-9]*))?')
PUBSPEC_VERSION = re.compile(r'^version:[ \t]*["\']?([^"\'\s#+]+)(?:\+[^"\'\s#]*)?["\']?[ \t]*(?:#.*)?$', re.MULTILINE)
MAX_MAJOR, MAX_MINOR, MAX_PATCH, MAX_BETA = 2099, 99, 99, 98
FINAL = 99


class VersionError(Exception):
    pass


def release_version(tag):
    """(build name, build number, channel) of a release tag."""
    match = TAG.fullmatch(tag)
    if not match:
        raise VersionError(f'{tag!r} is not a release tag (vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-beta.N)')
    major, minor, patch = (int(part) for part in match.group(1, 2, 3))
    beta = int(match.group(4)) if match.group(4) else None
    if major > MAX_MAJOR or minor > MAX_MINOR or patch > MAX_PATCH:
        raise VersionError(f'{tag}: major at most {MAX_MAJOR}, minor and patch at most {MAX_MINOR}')
    if beta is not None and beta > MAX_BETA:
        raise VersionError(f'{tag}: beta numbers run from 1 to {MAX_BETA}')
    number = major * 1_000_000 + minor * 10_000 + patch * 100 + (FINAL if beta is None else beta)
    return tag[1:], number, 'final' if beta is None else 'beta'


def ios_version(tag):
    """(CFBundleShortVersionString, CFBundleVersion) of a release tag."""
    build_name, build_number, _ = release_version(tag)
    return build_name.split('-', 1)[0], build_number


def pubspec_version_name(pubspec):
    match = PUBSPEC_VERSION.search(pubspec)
    if not match:
        raise VersionError('the pubspec has no version line')
    return match.group(1)


def check_pubspec(build_name, pubspec):
    name = pubspec_version_name(pubspec)
    if name != build_name:
        raise VersionError(f'app/pubspec.yaml has version {name}, the tag {build_name}: '
                           'bump the pubspec in the release commit')


def main(arguments):
    pubspec = PUBSPEC
    if len(arguments) == 3 and arguments[1] == '--pubspec':
        pubspec = arguments[2]
        arguments = arguments[:1]
    if len(arguments) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        build_name, build_number, channel = release_version(arguments[0])
        ios_build_name, ios_build_number = ios_version(arguments[0])
        with open(pubspec, encoding='utf-8') as f:
            check_pubspec(build_name, f.read())
    except (VersionError, OSError) as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    print(f'BUILD_NAME={build_name}')
    print(f'BUILD_NUMBER={build_number}')
    print(f'CHANNEL={channel}')
    print(f'IOS_BUILD_NAME={ios_build_name}')
    print(f'IOS_BUILD_NUMBER={ios_build_number}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
