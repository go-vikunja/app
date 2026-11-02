#!/usr/bin/env python3
"""Writes app/assets/legal/android.md: the licences of the Android libraries
in the release APK, which Flutter's own licence collection does not see. The
app shows them on its licence page on Android.

  python3 -I tool/build_android_notices.py              write the file
  python3 -I tool/build_android_notices.py --check      fail when it is stale
  python3 -I tool/build_android_notices.py --refresh-cronet
  python3 -I tool/build_android_notices.py --require-offer-contact
  python3 -I tool/build_android_notices.py --self-test

The libraries are the releaseRuntimeClasspath of app/android/app/gradle.lockfile
(rewritten by `./gradlew :app:dependencies --write-locks` in app/android) and
the core library desugaring in app/android/app/build.gradle.kts. Each one gets
its licence from ARTIFACTS, else from its Maven group; an unknown group fails,
and so does an AndroidX artifact that bundles another project's code
("external" in its name) unless ARTIFACTS names it, so that every new library
is looked at before it ships. Google Play services libraries are refused: the
app ships none (D67). The texts are in tool/android_notices/.

Embedded Cronet (cronet-bundled, with the classes in cronet) bundles other
projects' code. Its AARs carry its licences in third_party_licenses.txt with
an index, third_party_licenses.json; the entry "Cronet" is Chromium's
licence file for that build. --refresh-cronet copies both files from the
locked version's AARs in the Gradle cache into tool/android_notices/cronet/,
after checking the AARs against the SHA-256 that Google's Maven publishes,
their Chromium build against Chromium's release data (a Chrome stable release
for Android) and the "Cronet" entry against the LICENSE that Chromium
publishes beside the build's jars, where there is one. The other modes read
only that copy, so they need neither Gradle nor the network, and fail when it
does not belong to the locked Cronet version. CRONET_SUPPLEMENT adds what the
native library links statically but the licences do not name.

The written offer for desugar_jdk_libs' source names the upstream commit from
tool/android_notices/desugar_jdk_libs.source and WRITTEN_OFFER_CONTACT;
--require-offer-contact fails while that contact is empty, which the release
job checks (D73).
"""
import datetime
import glob
import hashlib
import io
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCKFILE = os.path.join(ROOT, 'app/android/app/gradle.lockfile')
BUILD_GRADLE = os.path.join(ROOT, 'app/android/app/build.gradle.kts')
TEXTS = os.path.join(ROOT, 'tool/android_notices')
OUTPUT = os.path.join(ROOT, 'app/assets/legal/android.md')
CONFIGURATION = 'releaseRuntimeClasspath'
CRONET_GROUP = 'org.chromium.net'
# The native library and its provider's sentinel; it brings CRONET_JAVA of
# the same build.
CRONET_LIBRARY = 'cronet-bundled'
CRONET_JAVA = 'cronet'
CRONET = os.path.join(TEXTS, 'cronet')
LICENCE_TEXT = 'third_party_licenses.txt'
LICENCE_INDEX = 'third_party_licenses.json'
CRONET_ENTRY = 'Cronet'
CHROMIUM_HEADING = 'The Chromium Project'
# Without it NativeCronetProvider reports itself disabled.
SENTINEL = 'org/chromium/net/impl/NativeCronetProviderSentinel.class'
IMPL_VERSION = 'org/chromium/net/impl/ImplVersion.class'
MAVEN_SHA256 = 'https://dl.google.com/android/maven2/org/chromium/net/{name}/{version}/{name}-{version}.aar.sha256'
RELEASES = ('https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Android&milestone={milestone}'
            '&num=1000')
CRONET_BUILDS = 'https://storage.googleapis.com/chromium-cronet/android/{build}/Release/cronet/'
# libcronet links Chromium's libc++, libc++abi and libunwind (std::__Cr
# symbols, third_party/libc++abi paths, libunwind: messages) and Rust's core
# and alloc statically; its licences name none of them. The LLVM texts are the
# LICENSE.TXT of libcxx, libcxxabi and libunwind; Rust's standard library is
# MIT OR Apache-2.0, taken under Apache-2.0. A component the licences name
# keeps their text.
CRONET_SUPPLEMENT = {
    'libc++': 'libcxx.txt',
    'libc++abi': 'libcxxabi.txt',
    'libunwind': 'libunwind.txt',
    'Rust standard library': 'apache-2.0.txt',
}
GRADLE_FILES = os.path.join(os.environ.get('GRADLE_USER_HOME') or os.path.join(os.path.expanduser('~'), '.gradle'),
                            'caches', 'modules-2', 'files-2.1')

# In the order the file lists them: (licence name, text file).
LICENCES = {
    'apache': ('Apache-2.0', 'apache-2.0.txt'),
    'protobuf': ('BSD-3-Clause', 'protobuf.txt'),
    'chromium': ('BSD-3-Clause', 'chromium.txt'),
    'gpl-classpath': ('GPL-2.0-only WITH Classpath-exception-2.0', 'gpl-2.0-classpath-exception.txt'),
}

GROUPS = {
    'com.getkeepsafe.relinker': 'apache',
    'com.google.android.material': 'apache',
    'com.google.code.findbugs': 'apache',
    'com.google.code.gson': 'apache',
    'com.google.crypto.tink': 'apache',
    'com.google.errorprone': 'apache',
    'com.google.guava': 'apache',
    'com.google.protobuf': 'protobuf',
    'com.squareup.okio': 'apache',
    'org.chromium.net': 'chromium',
    'org.jetbrains': 'apache',
    'org.jetbrains.kotlin': 'apache',
    'org.jetbrains.kotlinx': 'apache',
    'org.jspecify': 'apache',
}

REFUSED_GROUPS = {
    'com.google.android.gms': 'Google Play services libraries are not free software and the app ships none (D67); '
                              'find what brings it (./gradlew :app:dependencyInsight in app/android) and leave it '
                              'out in app/android/app/build.gradle.kts like play-services-cronet',
}

ARTIFACTS = {
    # Shaded copies of protobuf-javalite.
    'androidx.datastore:datastore-preferences-external-protobuf': 'protobuf',
    'androidx.glance:glance-appwidget-external-protobuf': 'protobuf',
    # OpenJDK's java.time and java.util for older Android versions.
    'com.android.tools:desugar_jdk_libs': 'gpl-classpath',
}

# Object code under the GPL-2.0 comes with its source code or a written offer
# for it (section 3). Each note names the upstream commit from its manifest.
SOURCE_NOTES = {
    'com.android.tools:desugar_jdk_libs': """\
desugar_jdk_libs {version} is code from OpenJDK under the GNU General Public
License, version 2, with the Classpath exception, compiled into the app. Its
source code is published at {repository}
at commit {commit} (upstream has no
tag for {version}), and a copy is attached to every release of this app.

Written offer: for at least three years after he last distributes this
version of the app, Benedikt Lesch gives anyone who asks a complete
machine-readable copy of the corresponding source code of desugar_jdk_libs
{version}, on a medium customarily used for software interchange, for a
charge no more than the cost of physically performing that distribution.
{request}""",
}
SOURCE_MANIFESTS = {
    'com.android.tools:desugar_jdk_libs': 'desugar_jdk_libs.source',
}
# How to ask for the source under the written offer; the release job fails
# while it is empty.
WRITTEN_OFFER_CONTACT = 'coderoftime@gmail.com'

DESUGARING = re.compile(r'^\s*coreLibraryDesugaring\("([^":]+):([^":]+):([^":]+)"\)', re.MULTILINE)
# Cronet's licence file: Chromium's licence under CHROMIUM_HEADING, then each
# component's, every name between two lines of 20 hyphens.
COMPONENT_HEADING = re.compile(r'\n-{20}\n(.*)\n-{20}\n')
CHROMIUM_BUILD = r'\d+\.\d+\.\d+\.\d+'
NATIVE_LIBRARY = re.compile(rf'^jni/[^/]+/libcronet\.({CHROMIUM_BUILD})\.so$')
CHROMIUM_VERSION = re.compile(rb'(?<![\d.])(\d+\.\d+\.\d+\.\d+)(?![\d.])')
CHROMIUM_COMMIT = re.compile(rb'([0-9a-f]{40})-refs/')


class NoticeError(Exception):
    pass


def locked_libraries(lockfile):
    libraries = []
    for line in lockfile.splitlines():
        if not line or line.startswith('#') or line.startswith('empty='):
            continue
        coordinates, _, configurations = line.partition('=')
        if CONFIGURATION not in configurations.split(','):
            continue
        group, name, version = coordinates.split(':')
        libraries.append((group, name, version))
    return libraries


def desugaring_libraries(build_gradle):
    return [match.groups() for match in DESUGARING.finditer(build_gradle)]


def licence_of(group, name):
    artifact = f'{group}:{name}'
    if group in REFUSED_GROUPS:
        raise NoticeError(f'{artifact}: {REFUSED_GROUPS[group]}')
    if artifact in ARTIFACTS:
        return ARTIFACTS[artifact]
    if group.startswith('androidx.'):
        if 'external' in name:
            raise NoticeError(f'{artifact} bundles another project: add its licence to ARTIFACTS')
        return 'apache'
    if group in GROUPS:
        return GROUPS[group]
    raise NoticeError(f'{artifact}: unknown group {group}; add it to GROUPS with its licence')


def normalized(text):
    return ' '.join(text.split())


def uncommented(text):
    return '\n'.join(re.sub(r'^// ?', '', line) for line in text.split('\n'))


def fenced(names, text, source):
    if re.search(r'^```', text, re.MULTILINE):
        raise NoticeError(f'{source} has a line starting with ```')
    return f'{names}\n\n```text\n{text}\n```'


def offer_request(contact):
    if contact:
        return f'Ask Benedikt Lesch at {contact}.'
    return "Ask through the contact given where the app's source code is published."


def parse_source_manifest(text, source):
    manifest = dict(line.partition('=')[::2] for line in text.splitlines() if '=' in line)
    missing = [key for key in ('version', 'repository', 'commit') if not manifest.get(key)]
    if missing:
        raise NoticeError(f'{source} lacks {", ".join(missing)}')
    return manifest


def source_note(artifact, version, sources, contact):
    template = SOURCE_NOTES.get(artifact)
    if template is None:
        return None
    source = (sources or {}).get(artifact)
    if source is None:
        raise NoticeError(f'{artifact} has a source note but no manifest in SOURCE_MANIFESTS')
    if source['version'] != version:
        raise NoticeError(f'the source manifest of {artifact} is for {source["version"]}, the build has {version}: '
                          f'record the upstream commit of {version} in tool/android_notices/'
                          f'{SOURCE_MANIFESTS[artifact]}')
    return template.format(version=version, repository=source['repository'], commit=source['commit'],
                           request=offer_request(contact))


def add_component(components, name, text):
    """A name listed twice with the same text counts once; with another text,
    the second gets a number."""
    if not name or '`' in name:
        raise NoticeError(f"Cronet's licences have a component without a name or with a backtick: {name!r}")
    unique, number = name, 2
    while unique in components and normalized(components[unique]) != normalized(text):
        unique, number = f'{name} ({number})', number + 1
    components[unique] = text


def cronet_components(licence):
    """Chromium's own licence and {component: text} from Cronet's licence
    file."""
    head, *sections = COMPONENT_HEADING.split('\n' + licence.replace('\r\n', '\n'))
    if head.strip() or not sections or sections[0].strip() != CHROMIUM_HEADING:
        raise NoticeError(f"Cronet's licence file does not start with Chromium's licence under {CHROMIUM_HEADING!r}")
    if len(sections) < 4:
        raise NoticeError("Cronet's licence file lists no components")
    components = {}
    for name, text in zip(sections[2::2], sections[3::2]):
        add_component(components, name.strip(), text.strip('\n'))
    return sections[1].strip('\n'), components


def licence_entries(text, index):
    """{name: text} from an AAR's licence files: the index gives each entry's
    start and length in bytes, every entry follows a line with its name, and
    together they make up the whole text."""
    try:
        bounds = sorted((entry['start'], entry['length'], name) for name, entry in json.loads(index).items())
    except (ValueError, AttributeError, TypeError, KeyError) as error:
        raise NoticeError(f'{LICENCE_INDEX} is no index of {LICENCE_TEXT}: {error!r}') from error
    entries, position = {}, 0
    for start, length, name in bounds:
        if not (type(start) is type(length) is int and start >= position and length >= 0) \
                or text[position:start] != f'\n\n{name}:\n\n'.encode('utf-8'):
            raise NoticeError(f'{LICENCE_INDEX} does not match {LICENCE_TEXT} at the entry {name!r}')
        try:
            entries[name] = text[start:start + length].decode('utf-8')
        except UnicodeDecodeError as error:
            raise NoticeError(f'the entry {name!r} of {LICENCE_TEXT} is not UTF-8') from error
        position = start + length
    if position != len(text):
        raise NoticeError(f'{LICENCE_TEXT} has text that {LICENCE_INDEX} does not index')
    if CRONET_ENTRY not in entries:
        raise NoticeError(f'{LICENCE_INDEX} has no entry {CRONET_ENTRY!r}')
    return entries


def cronet_coordinates(version):
    return sorted(f'{CRONET_GROUP}:{name}:{version}' for name in (CRONET_JAVA, CRONET_LIBRARY))


def locked_cronet(libraries):
    """The version of the locked Cronet libraries; None when none is
    locked."""
    locked = sorted({f'{group}:{name}:{version}' for group, name, version in libraries if group == CRONET_GROUP})
    if not locked:
        return None
    version = locked[0].rpartition(':')[2]
    if locked != cronet_coordinates(version):
        raise NoticeError(f'the locked {CRONET_GROUP} libraries are not {CRONET_JAVA} and {CRONET_LIBRARY} of one '
                          f'version: {", ".join(locked)}. Exclude the others in app/android/app/build.gradle.kts')
    return version


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def iso_date(text):
    try:
        return bool(re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', text)) and bool(datetime.date.fromisoformat(text))
    except (TypeError, ValueError):
        return False


def malformed_fields(source, version):
    """The provenance fields of source.json that --refresh-cronet could not
    have written for version."""
    build, commit, aars = source.get('build'), source.get('commit'), source.get('aar_sha256')
    valid = {
        'build': isinstance(build, str) and re.fullmatch(CHROMIUM_BUILD, build),
        'commit': isinstance(commit, str) and re.fullmatch('[0-9a-f]{40}', commit),
        'stable_since': iso_date(source.get('stable_since')),
        'aar_sha256': isinstance(aars, dict) and sorted(aars) == cronet_coordinates(version)
        and all(isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value) for value in aars.values()),
        'chromium_licence': 'chromium_licence' in source
        and source['chromium_licence'] in (None, CRONET_BUILDS.format(build=build) + 'LICENSE'),
    }
    return [field for field, ok in valid.items() if not ok]


def cronet_build(libraries, stored):
    """(owner, {name: text}) of the locked Cronet build, whose licence files
    the stored ones must be; None when no Cronet library is locked."""
    version = locked_cronet(libraries)
    if version is None:
        if stored is not None:
            raise NoticeError(f'{os.path.relpath(CRONET, ROOT)} belongs to {stored[0].get("library")}, '
                              'but no Cronet library is locked: remove it')
        return None
    library = f'{CRONET_GROUP}:{CRONET_LIBRARY}:{version}'
    if stored is None or stored[0].get('library') != library \
            or stored[0].get('libraries') != cronet_coordinates(version):
        found = ', '.join(stored[0].get('libraries') or [str(stored[0].get('library'))]) if stored else 'none'
        raise NoticeError(f"the stored Cronet licences do not belong to {', '.join(cronet_coordinates(version))} "
                          f'(stored: {found}). Run --refresh-cronet')
    source, text, index = stored
    malformed = malformed_fields(source, version)
    if malformed:
        raise NoticeError(f'{os.path.relpath(CRONET, ROOT)}/source.json has no valid {", ".join(malformed)}. '
                          'Run --refresh-cronet')
    if sha256(text) != source.get('licence_sha256') or sha256(index) != source.get('index_sha256'):
        raise NoticeError(f'{os.path.relpath(CRONET, ROOT)}/{LICENCE_TEXT} or {LICENCE_INDEX} changed since they '
                          'were copied. Run --refresh-cronet')
    return f'{CRONET_LIBRARY} {version}', licence_entries(text, index)


def bundled_components(owner, entries, texts, supplement):
    """The components the Cronet build bundles, its licence file's, then the
    AARs' other licence entries and the supplement's: list items for the
    section whose licence text a component has (comment markers aside), and a
    block for every other text with the components that share it. Chromium's
    own licence must be the chromium section's."""
    head, components = cronet_components(entries[CRONET_ENTRY])
    for name, text in entries.items():
        if name != CRONET_ENTRY:
            add_component(components, name.strip(), text.strip('\n'))
    for component, text in supplement.items():
        components.setdefault(component, text)
    if normalized(uncommented(head)) != normalized(texts['chromium']):
        raise NoticeError(f"the Chromium licence at the top of Cronet's licence file differs from "
                          f"{LICENCES['chromium'][1]}: compare them and update the text file")
    by_text = {}
    for component, text in sorted(components.items()):
        by_text.setdefault(normalized(text), (text, []))[1].append(component)

    def items(declared, suffix=''):
        return [f'- `{component}`{suffix} in {owner}' for component in declared]

    section_of = {normalized(uncommented(text)): key for key, text in texts.items()}
    section_items, blocks = {key: [] for key in LICENCES}, []
    for text, declared in sorted(by_text.values(), key=lambda entry: (entry[1][0], entry[0])):
        key = section_of.get(normalized(uncommented(text)))
        if key is not None:
            section_items[key] += items(declared, f' ({LICENCES[key][0]})')
        else:
            blocks.append(fenced('\n'.join(items(declared)), text, f'the licence of {", ".join(declared)}'))
    return section_items, blocks


def render(libraries, texts, cronet_licences, supplement=None, sources=None, contact=''):
    grouped = {key: [] for key in LICENCES}
    for group, name, version in sorted(set(libraries)):
        grouped[licence_of(group, name)].append((group, name, version))
    cronet = cronet_build(libraries, cronet_licences)
    section_items, component_blocks = {key: [] for key in LICENCES}, []
    if cronet is not None:
        section_items, component_blocks = bundled_components(*cronet, texts, supplement or {})
    sections = []
    for key, entries in grouped.items():
        licence, file = LICENCES[key]
        names = [f'- {group}:{name} {version} ({licence})' for group, name, version in entries] + section_items[key]
        if not names:
            continue
        sections.append(fenced('\n'.join(names), texts[key].replace('\r\n', '\n').strip('\n'), file))
        for group, name, version in entries:
            note = source_note(f'{group}:{name}', version, sources, contact)
            if note:
                sections.append(fenced(f'- {group}:{name} {version} (source code offer)', note,
                                       f'the source note of {group}:{name}'))
    if component_blocks:
        sections.append(f'The other projects in {cronet[0]} whose licences are not above, as the licence files '
                        'of its AARs list them:')
        sections += component_blocks
    return '\n'.join([
        '# Third-party notices: Android libraries',
        '',
        'The Android app contains these libraries besides the Flutter engine and the',
        'Dart packages. Generated by `tool/build_android_notices.py` from',
        '`app/android/app/gradle.lockfile`, `build.gradle.kts` and',
        '`tool/android_notices/cronet/`; do not edit.',
        '',
        '\n\n'.join(sections),
        '',
    ])


def find_aar(group, name, version, cache=GRADLE_FILES):
    found = sorted(glob.glob(os.path.join(glob.escape(cache), group, name, version, '*', f'{name}-{version}.aar')))
    if not found:
        raise NoticeError(f'{group}:{name}:{version} is not in the Gradle cache ({cache}). Build the release APK '
                          '(cd app && flutter build apk --release), then run --refresh-cronet again')
    return found[0]


def chromium_build_of(names):
    """The Chromium version in the name of the AAR's native libraries."""
    builds = {match.group(1) for match in map(NATIVE_LIBRARY.match, names) if match}
    if len(builds) != 1:
        raise NoticeError(f'expected native libraries of one Cronet build in the AAR, found: {sorted(builds)}')
    return builds.pop()


def download(url):
    """The body at url; None when there is nothing (HTTP 404)."""
    try:
        with urllib.request.urlopen(url, timeout=120) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise NoticeError(f'could not download {url}: {error}') from error
    except OSError as error:
        raise NoticeError(f'could not download {url}: {error}') from error


def fetched(fetch, url):
    body = fetch(url)
    if body is None:
        raise NoticeError(f'{url} does not exist')
    return body


def archive_members(data, source, *names):
    """The archive's member list and {name: bytes} of the members named."""
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            return archive.namelist(), {name: archive.read(name) for name in names}
    except (KeyError, zipfile.BadZipFile) as error:
        raise NoticeError(f'{source}: {error}') from error


def published_aar(name, version, fetch, cache):
    """The AAR from the Gradle cache, checked against Google's Maven."""
    path = find_aar(CRONET_GROUP, name, version, cache)
    with open(path, 'rb') as f:
        data = f.read()
    url = MAVEN_SHA256.format(name=name, version=version)
    if fetched(fetch, url).decode('ascii', 'replace').split()[:1] != [sha256(data)]:
        raise NoticeError(f'{path} is not the AAR whose SHA-256 Google publishes at {url}')
    return data


def stable_since(build, commit, fetch):
    """The day Chromium build at commit became a Chrome stable release for
    Android."""
    url = RELEASES.format(milestone=build.split('.')[0])
    try:
        times = [release['time'] for release in json.loads(fetched(fetch, url))
                 if (release.get('channel'), release.get('platform'), release.get('version'),
                     (release.get('hashes') or {}).get('chromium')) == ('Stable', 'Android', build, commit)]
    except (ValueError, AttributeError, TypeError, KeyError) as error:
        raise NoticeError(f'{url} is no list of releases: {error!r}') from error
    if not times:
        raise NoticeError(f'Chromium {build} (commit {commit}) is not a Chrome stable release for Android ({url}): '
                          f'take a {CRONET_LIBRARY} built from one')
    return datetime.datetime.fromtimestamp(min(times) / 1000, datetime.timezone.utc).date().isoformat()


def refresh_cronet(fetch=download, cache=GRADLE_FILES, directory=CRONET, libraries=None):
    version = locked_cronet(released_libraries() if libraries is None else libraries)
    if version is None:
        raise NoticeError(f'no {CRONET_GROUP}:{CRONET_LIBRARY} is locked')
    aars = {name: published_aar(name, version, fetch, cache) for name in (CRONET_JAVA, CRONET_LIBRARY)}
    names, bundled = archive_members(aars[CRONET_LIBRARY], CRONET_LIBRARY, 'classes.jar', LICENCE_TEXT, LICENCE_INDEX)
    _, java = archive_members(aars[CRONET_JAVA], CRONET_JAVA, 'classes.jar', LICENCE_TEXT, LICENCE_INDEX)
    build = chromium_build_of(names)
    if SENTINEL not in archive_members(bundled['classes.jar'], f'{CRONET_LIBRARY} classes.jar')[0]:
        raise NoticeError(f'{CRONET_LIBRARY} {version} has no {SENTINEL}, so its provider would stay disabled')
    implementation = archive_members(java['classes.jar'], f'{CRONET_JAVA} classes.jar', IMPL_VERSION)[1][IMPL_VERSION]
    commits = set(CHROMIUM_COMMIT.findall(implementation))
    if set(CHROMIUM_VERSION.findall(implementation)) != {build.encode()} or len(commits) != 1:
        raise NoticeError(f'the classes of {CRONET_JAVA} {version} are not of Chromium {build}, the native library '
                          f'of {CRONET_LIBRARY} {version}')
    commit = commits.pop().decode()
    text, index = bundled[LICENCE_TEXT], bundled[LICENCE_INDEX]
    if (java[LICENCE_TEXT], java[LICENCE_INDEX]) != (text, index):
        raise NoticeError(f'the licence files of {CRONET_JAVA} and {CRONET_LIBRARY} {version} differ')
    licence = licence_entries(text, index)[CRONET_ENTRY]
    cronet_components(licence)
    since = stable_since(build, commit, fetch)
    chromium_licence = CRONET_BUILDS.format(build=build) + 'LICENSE'
    published = fetch(chromium_licence)
    if published is None:
        chromium_licence = None
    elif published.decode('utf-8', 'replace').replace('\r\n', '\n') != licence.replace('\r\n', '\n'):
        raise NoticeError(f'the entry {CRONET_ENTRY!r} of the licence files differs from {chromium_licence}: '
                          'compare them before taking this build')
    source = {
        'library': f'{CRONET_GROUP}:{CRONET_LIBRARY}:{version}',
        'libraries': cronet_coordinates(version),
        'aar_sha256': {f'{CRONET_GROUP}:{name}:{version}': sha256(data) for name, data in sorted(aars.items())},
        'build': build,
        'commit': commit,
        'stable_since': since,
        'chromium_licence': chromium_licence,
        'licence_sha256': sha256(text),
        'index_sha256': sha256(index),
    }
    os.makedirs(directory, exist_ok=True)
    for name, data in ((LICENCE_TEXT, text), (LICENCE_INDEX, index)):
        with open(os.path.join(directory, name), 'wb') as f:
            f.write(data)
    with open(os.path.join(directory, 'source.json'), 'w', encoding='utf-8') as f:
        f.write(json.dumps(source, indent=2, sort_keys=True) + '\n')


def read_cronet(directory=CRONET):
    source = os.path.join(directory, 'source.json')
    if not os.path.exists(source):
        return None

    def data(name):
        try:
            with open(os.path.join(directory, name), 'rb') as f:
                return f.read()
        except OSError as error:
            raise NoticeError(f'{error}. Run --refresh-cronet') from error

    return json.loads(read(source)), data(LICENCE_TEXT), data(LICENCE_INDEX)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def released_libraries():
    libraries = locked_libraries(read(LOCKFILE)) + desugaring_libraries(read(BUILD_GRADLE))
    if not libraries:
        raise NoticeError(f'no {CONFIGURATION} entries in {LOCKFILE}')
    return libraries


def read_sources():
    return {artifact: parse_source_manifest(read(os.path.join(TEXTS, file)), file)
            for artifact, file in SOURCE_MANIFESTS.items()}


def build():
    texts = {key: read(os.path.join(TEXTS, file)) for key, (_, file) in LICENCES.items()}
    supplement = {component: read(os.path.join(TEXTS, file)) for component, file in CRONET_SUPPLEMENT.items()}
    return render(released_libraries(), texts, read_cronet(), supplement, read_sources(), WRITTEN_OFFER_CONTACT)


def fake_aar(entries):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w') as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    return buffer.getvalue()


def licence_files(entries):
    """An AAR's licence text and index for {name: text}."""
    text, index = b'', {}
    for name, entry in entries.items():
        text += f'\n\n{name}:\n\n'.encode('utf-8')
        index[name] = {'start': len(text), 'length': len(entry.encode('utf-8'))}
        text += entry.encode('utf-8')
    return text, json.dumps(index).encode('utf-8')


def refused(action, description):
    try:
        action()
    except NoticeError:
        return
    raise AssertionError(f'{description} was not refused')


def self_test():
    lockfile = '\n'.join([
        '# This is a Gradle generated file for dependency locking.',
        'androidx.core:core:1.18.0=debugRuntimeClasspath,releaseRuntimeClasspath',
        'androidx.glance:glance-appwidget-external-protobuf:1.2.0=releaseRuntimeClasspath',
        'org.chromium.net:cronet-bundled:500.1.0=releaseRuntimeClasspath',
        'org.chromium.net:cronet:500.1.0=releaseRuntimeClasspath',
        'junit:junit:4.13.2=debugUnitTestRuntimeClasspath',
        'org.jetbrains.kotlin:kotlin-stdlib:2.4.0=profileRuntimeClasspath,releaseRuntimeClasspath',
        'empty=debugAndroidTestRuntimeClasspath',
    ])
    libraries = locked_libraries(lockfile)
    assert ('junit', 'junit', '4.13.2') not in libraries, libraries
    assert len(libraries) == 5, libraries
    desugaring = desugaring_libraries('dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}')
    assert desugaring == [('com.android.tools', 'desugar_jdk_libs', '2.1.4')], desugaring

    texts = {key: f'{key} text\n' for key in LICENCES}
    texts['chromium'] = 'Copyright 2015 The Chromium Authors\n\nRedistribution © allowed.\n'
    mit = 'MIT License\n\nCopyright (c) 2011 Google, Inc. ü'

    def section(name, text):
        return f'\n--------------------\n{name}\n--------------------\n{text}\n'

    chromium = '// Copyright 2015 The Chromium Authors\n//\n//   Redistribution © allowed.'
    licence = (section('The Chromium Project', chromium).lstrip('\n')
               + section('CityHash', f'// {mit}') + section('CityHash', f'// {mit}')
               + section('Abseil', '  apache\n   text  ') + section('Protocol Buffers', 'protobuf text')
               + section('zlib', 'zlib text — 1995') + section('zlib', 'another zlib text')
               + section('memchr', mit) + section('termcolor', mit)
               + section('Metrics Protos', '// Copyright 2015 The Chromium Authors\n//\n// Redistribution © allowed.'))
    head, components = cronet_components(licence)
    assert head == chromium, head
    assert sorted(components) == ['Abseil', 'CityHash', 'Metrics Protos', 'Protocol Buffers', 'memchr', 'termcolor',
                                  'zlib', 'zlib (2)'], components
    assert components['CityHash'] == f'// {mit}' and components['zlib (2)'] == 'another zlib text', components
    assert cronet_components(licence.replace('\n', '\r\n')) == (head, components)
    refused(lambda: cronet_components(licence.split('--------------------\n', 2)[2]),
            "a licence file without Chromium's heading (the format before Chromium 155)")
    refused(lambda: cronet_components(licence.replace('The Chromium Project', 'Chromium')),
            'a licence file under another first heading')
    refused(lambda: cronet_components(section('The Chromium Project', chromium)),
            'a licence file without components')
    refused(lambda: cronet_components(licence + section('a `name`', 'text')), 'a backtick in a component name')
    refused(lambda: cronet_components(licence + section(' ', 'text')), 'a component without a name')

    owner = 'cronet-bundled 500.1.0'
    coordinates = ['org.chromium.net:cronet-bundled:500.1.0', 'org.chromium.net:cronet:500.1.0']
    assert cronet_coordinates('500.1.0') == coordinates
    build, chromium_commit = '155.0.8059.16', 'eb81d1e9a7da2b5edae9a034166cbf1640ab8c55'

    def stored(entries, library='org.chromium.net:cronet-bundled:500.1.0', coordinates=coordinates):
        text, index = licence_files(entries)
        return ({'library': library, 'libraries': coordinates, 'licence_sha256': sha256(text),
                 'index_sha256': sha256(index), 'build': build, 'commit': chromium_commit,
                 'stable_since': '2026-09-23', 'aar_sha256': dict.fromkeys(coordinates, 'a' * 64),
                 'chromium_licence': None}, text, index)

    cronet = stored({'Cronet': licence})
    commit = '50d9c1fb3e85fa4c00161525a45484f712c1f003'
    sources = {'com.android.tools:desugar_jdk_libs': parse_source_manifest(
        f'version=2.1.4\nrepository=https://github.com/google/desugar_jdk_libs\ncommit={commit}\nnote=a=b\n',
        'manifest')}
    output = render(libraries + desugaring, texts, cronet, sources=sources)
    assert '- androidx.core:core 1.18.0 (Apache-2.0)\n' \
           '- org.jetbrains.kotlin:kotlin-stdlib 2.4.0 (Apache-2.0)\n' \
           f'- `Abseil` (Apache-2.0) in {owner}\n\n```text\napache text\n```' in output, output
    assert '- androidx.glance:glance-appwidget-external-protobuf 1.2.0 (BSD-3-Clause)\n' \
           f'- `Protocol Buffers` (BSD-3-Clause) in {owner}\n\n```text\nprotobuf text\n```' in output, output
    assert '- org.chromium.net:cronet 500.1.0 (BSD-3-Clause)\n' \
           '- org.chromium.net:cronet-bundled 500.1.0 (BSD-3-Clause)\n' \
           f'- `Metrics Protos` (BSD-3-Clause) in {owner}\n\n```text\n' \
           'Copyright 2015 The Chromium Authors' in output, output
    assert '- com.android.tools:desugar_jdk_libs 2.1.4 ' \
           '(GPL-2.0-only WITH Classpath-exception-2.0)' in output, output
    assert f'- `CityHash` in {owner}\n\n```text\n// {mit}\n```' in output, output
    assert f'- `memchr` in {owner}\n- `termcolor` in {owner}\n\n```text\n{mit}\n```' in output, output
    assert output.count(mit) == 2, output
    assert f'- `zlib` in {owner}\n\n```text\nzlib text — 1995\n```' in output, output
    assert f'- `zlib (2)` in {owner}\n\n```text\nanother zlib text\n```' in output, output
    assert 'Chromium Authors\n//' not in output and 'The Chromium Project' not in output, output
    order = [output.index(f'{key} text') for key in ('apache', 'protobuf', 'gpl-classpath')]
    assert order == sorted(order) and output.index('Redistribution') < order[2], order
    assert output.index('```text\ngpl-classpath') < output.index(f'The other projects in {owner} whose licences are '
                                                                   'not above, as the licence files of its AARs list '
                                                                   'them:') < output.index('CityHash`')
    assert render(list(reversed(libraries)) + libraries, texts, cronet) == render(libraries, texts, cronet)

    # The AARs' other licence entries join Cronet's components.
    entries = {'AndroidX annotation library': '\n   apache\ntext\n\n', 'Cronet': licence, 'JSR 305': 'JSR 305 text\n',
               'Kotlin': mit, 'Protocol Buffers for Java': 'protobuf text\n', 'zlib': 'zlib text — 1995',
               'CityHash ': 'another CityHash text'}
    combined = render(libraries + desugaring, texts, stored(entries), sources=sources)
    assert f'- `Abseil` (Apache-2.0) in {owner}\n- `AndroidX annotation library` (Apache-2.0) in {owner}\n\n' \
           '```text\napache text\n```' in combined, combined
    assert f'- `Protocol Buffers` (BSD-3-Clause) in {owner}\n' \
           f'- `Protocol Buffers for Java` (BSD-3-Clause) in {owner}\n\n```text\nprotobuf text\n```' in combined
    assert f'- `JSR 305` in {owner}\n\n```text\nJSR 305 text\n```' in combined, combined
    assert f'- `Kotlin` in {owner}\n- `memchr` in {owner}\n- `termcolor` in {owner}\n\n```text\n{mit}\n```' \
           in combined, combined
    assert combined.count('zlib text — 1995') == 1, combined
    assert f'- `CityHash (2)` in {owner}\n\n```text\nanother CityHash text\n```' in combined, combined
    assert ' `Cronet` ' not in combined, combined
    refused(lambda: render(libraries, texts, stored(dict(entries, **{'a `name`': 'text'}))),
            'a backtick in the name of a licence entry')

    # The licence files' index.
    text, index = licence_files(entries)
    assert licence_entries(text, index) == entries and list(licence_entries(text, index)) == list(entries)
    bounds = json.loads(index)

    def tampered(name, **change):
        return json.dumps(dict(bounds, **{name: dict(bounds[name], **change)})).encode()

    for description, other_text, other_index in [
        ('an entry overlapping the one before', text, tampered('JSR 305', start=bounds['JSR 305']['start'] - 1)),
        ('an entry beyond the text', text, tampered('CityHash ', length=bounds['CityHash ']['length'] + 1)),
        ('a negative length', text, tampered('Kotlin', length=-1)),
        ('a length that is no number', text, tampered('Kotlin', length='5')),
        ('text the index leaves out', text + b'tail', index),
        ('an entry under another name', text.replace(b'\n\nKotlin:\n\n', b'\n\nKotlix:\n\n'), index),
        ('an index without the entry Cronet', *licence_files({'Chromium': licence})),
        ('an index that is no JSON', text, b'{'),
        ('an index that is a list', text, b'[]'),
        ('an entry that is not UTF-8', text.replace('ü'.encode(), b'\xfc\xfc'), index),
    ]:
        refused(lambda: licence_entries(other_text, other_index), description)

    # What the native library links but its licences do not name.
    supplement = {'libc++': 'llvm text', 'libc++abi': 'llvm text', 'Rust standard library': texts['apache'],
                  'zlib': 'zlib text of the supplement'}
    supplemented = render(libraries + desugaring, texts, cronet, supplement, sources)
    assert f'- `libc++` in {owner}\n- `libc++abi` in {owner}\n\n```text\nllvm text\n```' in supplemented, supplemented
    assert f'- `Abseil` (Apache-2.0) in {owner}\n' \
           f'- `Rust standard library` (Apache-2.0) in {owner}\n\n```text\napache text\n```' \
           in supplemented, supplemented
    assert 'zlib text of the supplement' not in supplemented and 'zlib text — 1995' in supplemented, supplemented
    assert supplemented.replace(f'- `Rust standard library` (Apache-2.0) in {owner}\n', '') \
        .replace(f'- `libc++` in {owner}\n- `libc++abi` in {owner}\n\n```text\nllvm text\n```\n\n', '') == output

    # The source offer follows the GPL licence.
    gpl = output.index('gpl-classpath text')
    offer = output.index('- com.android.tools:desugar_jdk_libs 2.1.4 (source code offer)\n\n```text\n'
                         'desugar_jdk_libs 2.1.4 is code from OpenJDK')
    assert gpl < offer < output.index('The other projects'), output
    assert f'published at https://github.com/google/desugar_jdk_libs\nat commit {commit} (upstream has no\n' \
           'tag for 2.1.4), and a copy is attached to every release of this app.' in output, output
    assert 'Written offer: for at least three years' in output, output
    assert "distribution.\nAsk through the contact given where the app's source code is published.\n```" in output
    with_contact = render(libraries + desugaring, texts, cronet, sources=sources, contact='rurana@example.org')
    assert 'distribution.\nAsk Benedikt Lesch at rurana@example.org.\n```' in with_contact, with_contact
    assert with_contact.replace('Ask Benedikt Lesch at rurana@example.org.',
                                "Ask through the contact given where the app's source code is published.") == output
    assert sources['com.android.tools:desugar_jdk_libs']['note'] == 'a=b'
    other_version = {key: dict(value, version='2.1.3') for key, value in sources.items()}
    refused(lambda: render(libraries + desugaring, texts, cronet, sources=other_version),
            'a source manifest of another version')
    refused(lambda: render(libraries + desugaring, texts, cronet), 'a source note without a manifest')
    refused(lambda: parse_source_manifest('version=2.1.4\nrepository=https://example.org\n', 'manifest'),
            'a source manifest without a commit')

    without_cronet = [library for library in libraries if library[0] != CRONET_GROUP]
    plain = render(without_cronet, texts, None, supplement, sources)
    assert 'org.chromium.net' not in plain and ' in cronet-bundled' not in plain, plain
    for group, name in [('com.example', 'library'), ('androidx.work', 'work-external-gson'),
                        ('com.android.tools', 'r8'), ('com.google.android.gms', 'play-services-cronet'),
                        ('com.google.android.gms', 'play-services-base')]:
        refused(lambda: licence_of(group, name), f'{group}:{name}')
    refused(lambda: render(libraries, dict(texts, apache='```\n'), cronet), 'a fence inside a text')
    refused(lambda: render(libraries, texts, None), 'a locked Cronet without stored licences')
    refused(lambda: render(without_cronet, texts, cronet), 'stored licences without a locked Cronet')
    refused(lambda: render(libraries, texts, stored({'Cronet': licence}, 'org.chromium.net:cronet-bundled:500.0.2')),
            'licences stored for another version')
    refused(lambda: render(libraries, texts, stored({'Cronet': licence}, coordinates=coordinates[:1])),
            'licences stored for other libraries')
    refused(lambda: render(libraries, texts, (cronet[0], cronet[1] + b' ', cronet[2])),
            'a licence text edited after the copy')
    refused(lambda: render(libraries, texts, (cronet[0], cronet[1], cronet[2] + b' ')),
            'an index edited after the copy')
    for description, change in [
        ('a build that is no Chromium version', {'build': '155.0.8059'}),
        ('a commit that is no full hash', {'commit': chromium_commit[:12]}),
        ('a stable day that is no date', {'stable_since': '2026-02-30'}),
        ('AAR hashes of another version', {'aar_sha256': {library.replace('500.1.0', '500.0.2'): 'a' * 64
                                                          for library in coordinates}}),
        ('an AAR hash that is no SHA-256', {'aar_sha256': dict.fromkeys(coordinates, 'A' * 64)}),
        ("the bucket's LICENSE of another build",
         {'chromium_licence': CRONET_BUILDS.format(build='155.0.8059.20') + 'LICENSE'}),
    ]:
        refused(lambda: render(libraries, texts, (dict(cronet[0], **change), cronet[1], cronet[2])), description)
    for field in ('build', 'commit', 'stable_since', 'aar_sha256', 'chromium_licence'):
        refused(lambda: render(libraries, texts, ({key: value for key, value in cronet[0].items() if key != field},
                                                  cronet[1], cronet[2])), f'a source.json without {field}')
    assert render(libraries, texts, (dict(cronet[0], chromium_licence=CRONET_BUILDS.format(build=build) + 'LICENSE'),
                                     cronet[1], cronet[2])) == render(libraries, texts, cronet)
    for description, locked in [
        ('cronet-bundled without cronet', [library for library in libraries if library[1] != CRONET_JAVA]),
        ('a transitional Cronet artifact', libraries + [(CRONET_GROUP, 'cronet-embedded', '500.1.0')]),
        ('Cronet libraries of two versions', libraries + [(CRONET_GROUP, 'cronet', '500.0.2')]),
    ]:
        refused(lambda: locked_cronet(locked), description)
        refused(lambda: render(locked, texts, cronet), description)
    other_head = licence.replace('Redistribution', 'Distribution')
    refused(lambda: render(libraries, texts, stored({'Cronet': other_head})), 'another Chromium licence')
    fence = licence + section('fenced', '```\ntext')
    refused(lambda: render(libraries, texts, stored({'Cronet': fence})), "a fence inside a component's text")

    # --refresh-cronet against a Gradle cache, Google's Maven and Chromium's
    # release data made here.
    assert chromium_build_of([f'jni/x86/libcronet.{build}.so', 'classes.jar']) == build
    refused(lambda: chromium_build_of([f'jni/x86/libcronet.{build}.so', 'jni/x86_64/libcronet.155.0.8059.20.so']),
            'native libraries of two builds')
    refused(lambda: chromium_build_of(['classes.jar']), 'an AAR without a native library')

    def implementation(build=build, commit=chromium_commit):
        return fake_aar({IMPL_VERSION: f'\x01\x00\x0d{build}\x01\x00\x0e{build}@\x01\x00\x34{commit}'
                                       '-refs/branch-heads/8059@{#465}\x0c'.encode()})

    def bundled_aar(classes=fake_aar({SENTINEL: b'', 'cronet-bundled.properties': b''}), build=build):
        return fake_aar({'classes.jar': classes, f'jni/arm64-v8a/libcronet.{build}.so': b'',
                         f'jni/x86_64/libcronet.{build}.so': b'', LICENCE_TEXT: text, LICENCE_INDEX: index})

    def java_aar(classes=implementation(), licence_text=text):
        return fake_aar({'classes.jar': classes, LICENCE_TEXT: licence_text, LICENCE_INDEX: index})

    good = {'cronet': java_aar(), 'cronet-bundled': bundled_aar()}
    releases = RELEASES.format(milestone='155')
    release = {'channel': 'Stable', 'platform': 'Android', 'version': build, 'time': 1790184739011,
               'hashes': {'chromium': chromium_commit}}
    chromium_licence = CRONET_BUILDS.format(build=build) + 'LICENSE'

    def refresh(aars, changes=None, locked=libraries):
        with tempfile.TemporaryDirectory() as temporary:
            cache = os.path.join(temporary, 'cache')
            for name, data in aars.items():
                folder = os.path.join(cache, CRONET_GROUP, name, '500.1.0', hashlib.sha1(data).hexdigest())
                os.makedirs(folder)
                with open(os.path.join(folder, f'{name}-500.1.0.aar'), 'wb') as f:
                    f.write(data)
            published = {MAVEN_SHA256.format(name=name, version='500.1.0'): f'{sha256(data)}\n'.encode()
                         for name, data in aars.items()}
            published[releases] = json.dumps([dict(release, version='155.0.8059.20', time=1790800000000), release,
                                              dict(release, channel='Beta', time=1789000000000)]).encode()
            published[chromium_licence] = licence.replace('\n', '\r\n').encode()
            published.update(changes or {})
            directory = os.path.join(temporary, 'cronet')
            refresh_cronet(fetch=published.get, cache=cache, directory=directory, libraries=locked)
            return read_cronet(directory)

    source, stored_text, stored_index = refresh(good)
    assert (stored_text, stored_index) == (text, index)
    assert source == {
        'library': 'org.chromium.net:cronet-bundled:500.1.0', 'libraries': coordinates,
        'aar_sha256': {f'org.chromium.net:{name}:500.1.0': sha256(data) for name, data in good.items()},
        'build': build, 'commit': chromium_commit, 'stable_since': '2026-09-23', 'chromium_licence': chromium_licence,
        'licence_sha256': sha256(text), 'index_sha256': sha256(index)}, source
    assert render(libraries + desugaring, texts, (source, stored_text, stored_index), sources=sources) == combined
    assert refresh(good, {chromium_licence: None})[0]['chromium_licence'] is None
    maven = MAVEN_SHA256.format(name='cronet', version='500.1.0')
    for description, aars, changes, locked in [
        ("a Cronet entry that differs from Chromium's LICENSE", good, {chromium_licence: b'another licence'}, libraries),
        ("an AAR that differs from Google's Maven", good, {maven: b'0' * 64}, libraries),
        ("an AAR that Google's Maven does not have", good, {maven: None}, libraries),
        ('a build that was no stable release', good, {releases: json.dumps([dict(release, version='155.0.8059.20')])
                                                      .encode()}, libraries),
        ('a stable release of another commit', good,
         {releases: json.dumps([dict(release, hashes={'chromium': '0' * 40})]).encode()}, libraries),
        ('a beta release', good, {releases: json.dumps([dict(release, channel='Beta')]).encode()}, libraries),
        ('release data that is no list of releases', good, {releases: b'{"version": "155.0.8059.16"}'}, libraries),
        ('classes of another build than the native library',
         dict(good, cronet=java_aar(implementation(build='155.0.8059.20'))), {}, libraries),
        ('classes without a commit', dict(good, cronet=java_aar(fake_aar({IMPL_VERSION: build.encode()}))), {},
         libraries),
        ('classes without ImplVersion', dict(good, cronet=java_aar(fake_aar({'a.class': b''}))), {}, libraries),
        ('cronet-bundled without the provider sentinel',
         dict(good, **{'cronet-bundled': bundled_aar(classes=fake_aar({'cronet-bundled.properties': b''}))}), {},
         libraries),
        ('licence files that differ between the AARs', dict(good, cronet=java_aar(licence_text=text + b' ')), {},
         libraries),
        ('an AAR without licence files', dict(good, cronet=fake_aar({'classes.jar': implementation()})), {},
         libraries),
        ('an AAR missing from the cache', {'cronet-bundled': good['cronet-bundled']}, {}, libraries),
        ('a transitional Cronet artifact in the lockfile', good, {},
         libraries + [(CRONET_GROUP, 'cronet-api', '500.1.0')]),
        ('a lockfile without Cronet', good, {}, without_cronet),
    ]:
        refused(lambda: refresh(aars, changes, locked), description)
    print('Self-test passed.')


def main():
    args = sys.argv[1:]
    if args == ['--self-test']:
        self_test()
        return
    if args == ['--require-offer-contact']:
        if not WRITTEN_OFFER_CONTACT:
            print('error: WRITTEN_OFFER_CONTACT in tool/build_android_notices.py is empty. The written offer for '
                  "desugar_jdk_libs' source needs a contact before a release (D73): set it, then run this "
                  'script to write app/assets/legal/android.md again', file=sys.stderr)
            sys.exit(1)
        print('OK: the written offer names a contact.')
        return
    if args not in ([], ['--check'], ['--refresh-cronet']):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    try:
        if args == ['--refresh-cronet']:
            refresh_cronet()
        notices = build()
    except NoticeError as error:
        print(f'error: {error}', file=sys.stderr)
        sys.exit(1)
    if args == ['--check']:
        if not os.path.exists(OUTPUT) or read(OUTPUT) != notices:
            print(f'{os.path.relpath(OUTPUT, ROOT)} is stale. Run: python3 -I tool/build_android_notices.py',
                  file=sys.stderr)
            sys.exit(1)
        print(f'OK: {os.path.relpath(OUTPUT, ROOT)} is current.')
        return
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(notices)
    print(f'Wrote {os.path.relpath(OUTPUT, ROOT)}.')


if __name__ == '__main__':
    main()
