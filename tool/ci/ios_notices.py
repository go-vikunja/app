#!/usr/bin/env python3
"""Fails when the licence page of an iOS build would miss a notice
(docs/releasing.md).

  python3 -I tool/ci/ios_notices.py APP

APP is the built Runner.app. On iOS the licence page shows Flutter's NOTICES
(App.framework/flutter_assets/NOTICES.Z: the NOTICES or LICENSE file of every
package of the pub workspace, dev dependencies included) and the legal assets
of app/lib/core/legal/app_licenses.dart but the Android one, which is bundled
all the same. Flutter skips a package without such a file silently, and the
page leaves out an asset it cannot read. Checks that:

- every licence in each package's file is in NOTICES.Z, as Flutter splits the
  file; a package without one must be this repository's, under its LICENSE,
  or the Flutter SDK's, under the SDK's LICENSE;
- NOTICES.Z lists the repository's LICENSE under ownLicensePackage, the name
  the app's own notice joins;
- the only frameworks are Flutter's, App.framework and the native assets of
  NativeAssetsManifest.json, all of them built from pub packages;
- every legal asset is bundled and equal to its source.

It does not see Swift packages fetched by URL, which would be linked into the
app statically; no plugin uses one (2026-10-29).
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SEPARATOR = '\n' + '-' * 80 + '\n'
FLUTTER_ASSETS = os.path.join('Frameworks', 'App.framework', 'flutter_assets')
FLUTTER_FRAMEWORKS = {os.path.join('Frameworks', 'Flutter.framework'), os.path.join('Frameworks', 'App.framework')}
APP_LICENSES = os.path.join('app', 'lib', 'core', 'legal', 'app_licenses.dart')
LEGAL_ASSET = re.compile(r"^\s*static const \w+ = '([^']+)';", re.MULTILINE)
OWN_PACKAGE = re.compile(r"^const ownLicensePackage = '([^']+)';", re.MULTILINE)


class NoticeError(Exception):
    pass


def normalized(text):
    return ' '.join(text.split())


def licence_sections(text, package):
    """[(names, text)] of a NOTICES or LICENSE file, split as Flutter's
    LicenseCollector splits it."""
    raw = text.split(SEPARATOR)
    sections = []
    for part in raw:
        names, separator, licence = part.partition('\n\n')
        if len(raw) > 1 and separator:
            sections.append((names.split('\n'), licence))
        else:
            sections.append(([package], part))
    return sections


def notices(app):
    """{normalized licence text: names} of the app's NOTICES.Z."""
    path = os.path.join(app, FLUTTER_ASSETS, 'NOTICES.Z')
    try:
        with open(path, 'rb') as f:
            text = zlib.decompress(f.read(), zlib.MAX_WBITS | 32).decode('utf-8')
    except (OSError, zlib.error, UnicodeDecodeError) as error:
        raise NoticeError(f'{path} is missing or unreadable: {error!r}') from error
    entries = {}
    for block in text.split(SEPARATOR):
        names, _, licence = block.partition('\n\n')
        entries.setdefault(normalized(licence), set()).update(names.split('\n'))
    return entries


def path_of(uri, base):
    parsed = urllib.parse.urlparse(uri)
    if parsed.scheme == 'file':
        return os.path.normpath(urllib.request.url2pathname(parsed.path))
    if parsed.scheme:
        raise NoticeError(f'{uri} is not a file URI')
    return os.path.normpath(os.path.join(base, urllib.request.url2pathname(uri)))


def package_config(root):
    """({package: root directory}, Flutter SDK directory or None)."""
    path = os.path.join(root, '.dart_tool', 'package_config.json')
    try:
        with open(path, encoding='utf-8') as f:
            config = json.load(f)
        base = os.path.dirname(path)
        packages = {package['name']: path_of(package['rootUri'], base) for package in config['packages']}
        flutter_root = config.get('flutterRoot')
        return packages, path_of(flutter_root, base) if flutter_root else None
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise NoticeError(f'{path} is missing or unreadable (flutter pub get): {error!r}') from error


def read_text(path):
    # Unconverted line ends, as Flutter reads the file.
    with open(path, encoding='utf-8', newline='') as f:
        return f.read()


def licence_file(directory):
    for name in ('NOTICES', 'LICENSE'):
        path = os.path.join(directory, name)
        if os.path.isfile(path):
            return path
    return None


def inside(path, directory):
    return directory is not None and os.path.commonpath([path, directory]) == directory


def check_packages(root, packages, flutter_root, entries):
    errors = []
    for package, directory in sorted(packages.items()):
        path = licence_file(directory)
        if path is None:
            if inside(directory, root):
                path = os.path.join(root, 'LICENSE')
            elif inside(directory, flutter_root):
                path = os.path.join(flutter_root, 'LICENSE')
            else:
                errors.append(f'{package} ({directory}) has no LICENSE or NOTICES file, so Flutter leaves it off '
                              'the licence page: add its licence to the page')
                continue
        try:
            sections = licence_sections(read_text(path), package)
        except (OSError, UnicodeDecodeError) as error:
            errors.append(f'{path} is unreadable: {error!r}')
            continue
        for names, licence in sections:
            if normalized(licence) not in entries:
                errors.append(f'NOTICES.Z lacks the licence of {", ".join(names)} from {path}')
    return errors


def check_own_licence(root, own_package, entries):
    path = os.path.join(root, 'LICENSE')
    try:
        names = entries.get(normalized(read_text(path)), set())
    except (OSError, UnicodeDecodeError) as error:
        return [f'{path} is unreadable: {error!r}']
    if own_package not in names:
        return [f'NOTICES.Z does not list the repository\'s LICENSE under {own_package} (ownLicensePackage in '
                f'{APP_LICENSES}) but under {", ".join(sorted(names)) or "no name"}']
    return []


def native_frameworks(app):
    """The framework paths (relative to the app) of NativeAssetsManifest.json,
    and the packages they come from."""
    path = os.path.join(app, FLUTTER_ASSETS, 'NativeAssetsManifest.json')
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding='utf-8') as f:
            manifest = json.load(f)
        frameworks = {}
        for assets in manifest['native-assets'].values():
            for asset, (kind, *location) in assets.items():
                if kind == 'absolute' and '.framework/' in location[0]:
                    framework = os.path.join('Frameworks', location[0].split('/')[0])
                    frameworks[framework] = asset.removeprefix('package:').split('/')[0]
        return frameworks
    except (OSError, ValueError, KeyError, TypeError, AttributeError, IndexError) as error:
        raise NoticeError(f'{path} is unreadable: {error!r}') from error


def check_frameworks(app, packages):
    allowed = native_frameworks(app)
    errors = []
    for package in sorted(set(allowed.values()) - set(packages)):
        errors.append(f'the native asset package {package} is not in the pub workspace')
    for directory, subdirectories, _ in os.walk(app):
        subdirectories.sort()
        for name in subdirectories:
            if not name.endswith('.framework'):
                continue
            relative = os.path.relpath(os.path.join(directory, name), app)
            if relative not in FLUTTER_FRAMEWORKS and relative not in allowed:
                errors.append(f'{relative} comes from no pub package, so no notice on the licence page covers it')
        subdirectories[:] = [name for name in subdirectories if not name.endswith('.framework')]
    return errors, sorted(os.path.basename(framework) for framework in allowed)


def legal_assets(root):
    """(asset keys of LegalAssets, ownLicensePackage) from app_licenses.dart."""
    path = os.path.join(root, APP_LICENSES)
    try:
        source = read_text(path)
    except (OSError, UnicodeDecodeError) as error:
        raise NoticeError(f'{path} is unreadable: {error!r}') from error
    block = re.search(r'abstract final class LegalAssets \{(.*?)\n\}', source, re.DOTALL)
    own = OWN_PACKAGE.search(source)
    if not block or not own:
        raise NoticeError(f'{path} has no LegalAssets class or no ownLicensePackage')
    assets = LEGAL_ASSET.findall(block.group(1))
    if not assets:
        raise NoticeError(f'{path} names no legal asset')
    return assets, own.group(1)


def asset_source(root, packages, key):
    parts = key.split('/', 2)
    if len(parts) == 3 and parts[0] == 'packages' and parts[1] in packages:
        return os.path.join(packages[parts[1]], parts[2])
    return os.path.join(root, 'app', key)


def check_assets(app, root, packages, assets):
    errors = []
    for key in assets:
        bundled = os.path.join(app, FLUTTER_ASSETS, key)
        source = asset_source(root, packages, key)
        try:
            with open(bundled, 'rb') as f:
                built = f.read()
        except OSError:
            errors.append(f'the legal asset {key} is not bundled, so the licence page leaves it out')
            continue
        try:
            with open(source, 'rb') as f:
                same = f.read() == built
        except OSError:
            errors.append(f'the source of the legal asset {key} ({source}) is missing')
            continue
        if not same:
            errors.append(f'the bundled {key} differs from {source}')
    return errors


def check(app, root=ROOT):
    """(errors, summary) of an app bundle."""
    entries = notices(app)
    packages, flutter_root = package_config(root)
    assets, own_package = legal_assets(root)
    errors = check_packages(root, packages, flutter_root, entries)
    errors += check_own_licence(root, own_package, entries)
    framework_errors, frameworks = check_frameworks(app, packages)
    errors += framework_errors
    errors += check_assets(app, root, packages, assets)
    summary = (f'Licence page: NOTICES.Z has the licences of all {len(packages)} packages, the repository\'s under '
               f'{own_package}; native asset frameworks {", ".join(frameworks) or "none"}; legal assets '
               f'{", ".join(assets)} bundled as in the source.')
    return errors, summary


def main(arguments):
    if len(arguments) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    app = arguments[0]
    try:
        if not os.path.isdir(app):
            raise NoticeError(f'{app} is not a bundle')
        errors, summary = check(app)
    except NoticeError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    for error in errors:
        print(f'error: {error}', file=sys.stderr)
    if errors:
        return 1
    print(summary)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
