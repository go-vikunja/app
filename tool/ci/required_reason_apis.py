#!/usr/bin/env python3
"""Fails when a binary of an iOS bundle uses a required-reason API that no
privacy manifest for it declares (docs/releasing.md, privacy manifests).

  python3 -I tool/ci/required_reason_apis.py BUNDLE...

BUNDLE is an .app or .appex; an .appex inside it is checked as a bundle of its
own. As Apple's page asks, the bundle that holds a binary reports its APIs:
a framework's binary is checked against the manifests in that framework,
any other Mach-O file against the bundle's own and those of its resource
bundles (the statically linked plugins'). Symbols come from `xcrun nm -u`,
the Objective-C selectors on Apple's list from the bytes. Prints the
categories each binary uses; exits 1 on an undeclared one.
"""
import os
import plistlib
import re
import subprocess
import sys

MANIFEST = 'PrivacyInfo.xcprivacy'
FILE_TIMESTAMP = 'NSPrivacyAccessedAPICategoryFileTimestamp'
BOOT_TIME = 'NSPrivacyAccessedAPICategorySystemBootTime'
DISK_SPACE = 'NSPrivacyAccessedAPICategoryDiskSpace'
KEYBOARDS = 'NSPrivacyAccessedAPICategoryActiveKeyboards'
USER_DEFAULTS = 'NSPrivacyAccessedAPICategoryUserDefaults'

# Apple's list as of 2026-10-29; getattrlist and its variants are in two
# categories.
SYMBOLS = {
    FILE_TIMESTAMP: {'stat', 'stat64', 'fstat', 'fstat64', 'fstatat', 'fstatat64', 'lstat', 'lstat64',
                     'getattrlist', 'getattrlistbulk', 'fgetattrlist', 'getattrlistat', 'NSFileCreationDate',
                     'NSFileModificationDate', 'NSURLContentModificationDateKey', 'NSURLCreationDateKey'},
    BOOT_TIME: {'mach_absolute_time'},
    DISK_SPACE: {'statfs', 'statfs64', 'statvfs', 'fstatfs', 'fstatfs64', 'fstatvfs', 'getattrlist',
                 'fgetattrlist', 'getattrlistat', 'NSURLVolumeAvailableCapacityKey',
                 'NSURLVolumeAvailableCapacityForImportantUsageKey',
                 'NSURLVolumeAvailableCapacityForOpportunisticUsageKey', 'NSURLVolumeTotalCapacityKey',
                 'NSFileSystemFreeSize', 'NSFileSystemSize'},
    USER_DEFAULTS: {'OBJC_CLASS_$_NSUserDefaults'},
}
SELECTORS = {
    BOOT_TIME: ('systemUptime',),
    KEYBOARDS: ('activeInputModes',),
}
MACH_O_MAGIC = {
    b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xfe\xed\xfa\xce',
    b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf',
}


class ScanError(Exception):
    pass


def short(category):
    return category.removeprefix('NSPrivacyAccessedAPICategory')


def undefined_symbols(path):
    result = subprocess.run(['xcrun', 'nm', '-u', path], capture_output=True, text=True)
    if result.returncode != 0:
        raise ScanError(f'nm failed on {path}: {result.stderr.strip()}')
    return result.stdout.splitlines()


def uses(symbols, data):
    """{category: sorted APIs} of nm -u output lines and a binary's bytes."""
    names = set()
    for line in symbols:
        name = line.strip().removeprefix('_').removesuffix('$INODE64')
        if name:
            names.add(name)
    found = {}
    for category, apis in SYMBOLS.items():
        hits = names & apis
        if hits:
            found.setdefault(category, set()).update(hits)
    for category, selectors in SELECTORS.items():
        for selector in selectors:
            if re.search(rb'(?<![\w:])' + selector.encode() + rb'(?![\w:])', data):
                found.setdefault(category, set()).add(selector)
    return {category: sorted(apis) for category, apis in found.items()}


def declared(manifest):
    """The categories a privacy manifest gives at least one reason for."""
    try:
        with open(manifest, 'rb') as f:
            content = plistlib.load(f)
        entries = content.get('NSPrivacyAccessedAPITypes', [])
        return {entry['NSPrivacyAccessedAPIType'] for entry in entries if entry.get('NSPrivacyAccessedAPITypeReasons')}
    except (OSError, plistlib.InvalidFileException, AttributeError, KeyError, TypeError) as error:
        raise ScanError(f'{manifest} is not a readable privacy manifest: {error!r}') from error


def is_mach_o(path):
    with open(path, 'rb') as f:
        return f.read(4) in MACH_O_MAGIC


def framework_of(relative):
    """The framework directory (relative to its bundle) a file is in, or None."""
    parts = relative.split(os.sep)
    for index, part in enumerate(parts[:-1]):
        if part.endswith('.framework'):
            return os.sep.join(parts[:index + 1])
    return None


def walk(bundle):
    """(relative binaries, relative manifests, nested .appex paths) of a bundle."""
    binaries, manifests, extensions = [], [], []
    for directory, subdirectories, files in os.walk(bundle):
        for name in list(subdirectories):
            path = os.path.join(directory, name)
            if name.endswith('.appex'):
                extensions.append(path)
                subdirectories.remove(name)
            elif os.path.islink(path):
                subdirectories.remove(name)
        for name in files:
            path = os.path.join(directory, name)
            if os.path.islink(path):
                continue
            relative = os.path.relpath(path, bundle)
            if name == MANIFEST:
                manifests.append(relative)
            elif is_mach_o(path):
                binaries.append(relative)
    return sorted(binaries), sorted(manifests), sorted(extensions)


def scan(bundle, symbols_of=undefined_symbols):
    """[(binary, {category: APIs}, {undeclared category: APIs})] of a bundle
    and the .appex bundles in it."""
    binaries, manifests, extensions = walk(bundle)
    categories = {manifest: declared(os.path.join(bundle, manifest)) for manifest in manifests}
    report = []
    for binary in binaries:
        path = os.path.join(bundle, binary)
        with open(path, 'rb') as f:
            used = uses(symbols_of(path), f.read())
        framework = framework_of(binary)
        if framework:
            relevant = [m for m in manifests if m.startswith(framework + os.sep)]
        else:
            relevant = [m for m in manifests if framework_of(m) is None]
        covered = set().union(*(categories[m] for m in relevant))
        missing = {category: apis for category, apis in used.items() if category not in covered}
        report.append((path, used, missing))
    for extension in extensions:
        report.extend(scan(extension, symbols_of))
    return report


def main(arguments):
    if not arguments:
        print(__doc__, file=sys.stderr)
        return 2
    failed = False
    try:
        for bundle in arguments:
            if not os.path.isdir(bundle):
                raise ScanError(f'{bundle} is not a bundle')
            parent = os.path.dirname(os.path.normpath(bundle))
            for path, used, missing in scan(bundle):
                name = os.path.relpath(path, parent)
                print(f'{name}: {", ".join(short(c) for c in sorted(used)) or "none"}', flush=True)
                for category, apis in sorted(missing.items()):
                    failed = True
                    print(f'error: {name} uses {short(category)} ({", ".join(apis)}), which no privacy manifest '
                          'for it declares', file=sys.stderr)
    except ScanError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
