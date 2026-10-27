#!/usr/bin/env python3
"""Writes app/assets/legal/android.md: the licences of the Android libraries
in the release APK, which Flutter's own licence collection does not see. The
app shows them on its licence page on Android.

  python3 -I tool/build_android_notices.py              write the file
  python3 -I tool/build_android_notices.py --check      fail when it is stale
  python3 -I tool/build_android_notices.py --refresh-cronet
  python3 -I tool/build_android_notices.py --self-test

The libraries are the releaseRuntimeClasspath of app/android/app/gradle.lockfile
(rewritten by `./gradlew :app:dependencies --write-locks` in app/android) and
the core library desugaring in app/android/app/build.gradle.kts. Each one gets
its licence from ARTIFACTS, else from its Maven group; an unknown group fails,
and so does an AndroidX artifact that bundles another project's code
("external" in its name) unless ARTIFACTS names it, so that every new library
is looked at before it ships. Google Play services libraries are refused: the
app ships none (D67). The texts are in tool/android_notices/.

Embedded Cronet's native library bundles other projects' code. The AARs carry
no licence file; Chromium publishes one per Cronet build beside the build's
jars, which the POMs point to. --refresh-cronet downloads it for the locked
cronet-embedded version into tool/android_notices/cronet/, after checking
that the jar published there is byte for byte the classes of the
cronet-embedded AAR in the Gradle cache, and writes the file. The other modes
read only that copy, so they need neither Gradle nor the network, and fail
when it does not belong to the locked Cronet version. CRONET_SUPPLEMENT adds
what the native library links statically but that file does not name.
"""
import glob
import hashlib
import io
import json
import os
import re
import sys
import tempfile
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCKFILE = os.path.join(ROOT, 'app/android/app/gradle.lockfile')
BUILD_GRADLE = os.path.join(ROOT, 'app/android/app/build.gradle.kts')
TEXTS = os.path.join(ROOT, 'tool/android_notices')
OUTPUT = os.path.join(ROOT, 'app/assets/legal/android.md')
CONFIGURATION = 'releaseRuntimeClasspath'
CRONET_GROUP = 'org.chromium.net'
CRONET_LIBRARY = 'cronet-embedded'
CRONET = os.path.join(TEXTS, 'cronet')
CRONET_BUILDS = 'https://storage.googleapis.com/chromium-cronet/android/{build}/Release/cronet/'
# cronet-embedded's classes.jar under the name the build folder gives it.
CRONET_CLASSES = 'cronet_impl_native_java.jar'
# libcronet links Chromium's libc++ and libc++abi (std::__Cr symbols,
# third_party/libc++abi paths) and Rust's core and alloc statically; its
# LICENSE names none of them. The LLVM texts are libcxx/LICENSE.TXT and
# libcxxabi/LICENSE.TXT; Rust's standard library is MIT OR Apache-2.0, taken
# under Apache-2.0. A component the LICENSE names itself keeps its text.
CRONET_SUPPLEMENT = {
    'libc++': 'libcxx.txt',
    'libc++abi': 'libcxxabi.txt',
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
# for it (section 3).
SOURCE_NOTES = {
    'com.android.tools:desugar_jdk_libs': """\
desugar_jdk_libs {version} is code from OpenJDK under the GNU General Public
License, version 2, with the Classpath exception, compiled into the app. Its
source code is published at https://github.com/google/desugar_jdk_libs
(release {version}).

Written offer: for at least three years after he last distributes this
version of the app, Benedikt Lesch gives anyone who asks a complete
machine-readable copy of the corresponding source code of desugar_jdk_libs
{version}, on a medium customarily used for software interchange, for a
charge no more than the cost of physically performing that distribution.
Ask through the contact given where the app's source code is published.""",
}

DESUGARING = re.compile(r'^\s*coreLibraryDesugaring\("([^":]+):([^":]+):([^":]+)"\)', re.MULTILINE)
# Cronet's LICENSE: Chromium's licence, then each component's under its name
# between two lines of 20 hyphens.
COMPONENT_HEADING = re.compile(r'\n-{20}\n(.*)\n-{20}\n')
NATIVE_LIBRARY = re.compile(r'^jni/[^/]+/libcronet\.(\d+\.\d+\.\d+\.\d+)\.so$')


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


def cronet_components(licence):
    """Chromium's own licence and {component: text} from a Cronet LICENSE. A
    name listed twice with the same text counts once; with another text, the
    second gets a number."""
    head, *sections = COMPONENT_HEADING.split(licence.replace('\r\n', '\n'))
    if not sections:
        raise NoticeError("Cronet's LICENSE lists no components")
    components = {}
    for name, text in zip(sections[0::2], sections[1::2]):
        name, text = name.strip(), text.strip('\n')
        if not name or '`' in name:
            raise NoticeError(f"Cronet's LICENSE has a component without a name or with a backtick: {name!r}")
        unique, number = name, 2
        while unique in components and normalized(components[unique]) != normalized(text):
            unique, number = f'{name} ({number})', number + 1
        components[unique] = text
    return head.strip('\n'), components


def cronet_build(libraries, stored):
    """(owner, LICENSE) of the locked Cronet build, whose LICENSE the stored
    one must be; None when no Cronet library is locked."""
    versions = {(name, version) for group, name, version in libraries if group == CRONET_GROUP}
    if not versions:
        if stored is not None:
            raise NoticeError(f'{os.path.relpath(CRONET, ROOT)} belongs to {stored[0]["library"]}, '
                              'but no Cronet library is locked: remove it')
        return None
    embedded = sorted(version for name, version in versions if name == CRONET_LIBRARY)
    if len(embedded) != 1 or {version for _, version in versions} != set(embedded):
        raise NoticeError(f'the locked {CRONET_GROUP} libraries are not one {CRONET_LIBRARY} build: '
                          f'{", ".join(f"{name} {version}" for name, version in sorted(versions))}')
    library = f'{CRONET_GROUP}:{CRONET_LIBRARY}:{embedded[0]}'
    if stored is None or stored[0]['library'] != library:
        found = stored[0]['library'] if stored else 'none'
        raise NoticeError(f"the stored Cronet LICENSE does not belong to {library} (stored: {found}). "
                          'Run --refresh-cronet')
    source, licence = stored
    if hashlib.sha256(licence.encode('utf-8')).hexdigest() != source['licence_sha256']:
        raise NoticeError(f"{os.path.relpath(CRONET, ROOT)}/LICENSE changed since it was downloaded. "
                          'Run --refresh-cronet')
    return f'{CRONET_LIBRARY} {embedded[0]}', licence


def bundled_components(owner, licence, texts, supplement):
    """The components the Cronet build bundles, its LICENSE's and then the
    supplement's: list items for the section whose licence text a component
    has (comment markers aside), and a block for every other text with the
    components that share it. Chromium's own licence must be the chromium
    section's."""
    head, components = cronet_components(licence)
    for component, text in supplement.items():
        components.setdefault(component, text)
    if normalized(uncommented(head)) != normalized(texts['chromium']):
        raise NoticeError(f"the Chromium licence at the top of Cronet's LICENSE differs from "
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


def render(libraries, texts, cronet_licence, supplement=None):
    grouped = {key: [] for key in LICENCES}
    for group, name, version in sorted(set(libraries)):
        grouped[licence_of(group, name)].append((group, name, version))
    cronet = cronet_build(libraries, cronet_licence)
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
            note = SOURCE_NOTES.get(f'{group}:{name}')
            if note:
                sections.append(fenced(f'- {group}:{name} {version} (source code offer)', note.format(version=version),
                                       f'the source note of {group}:{name}'))
    if component_blocks:
        sections.append(f'The other projects in {cronet[0]} whose licences are not above, as the LICENSE file '
                        'of its build lists them:')
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
    try:
        with urllib.request.urlopen(url, timeout=120) as response:
            return response.read()
    except OSError as error:
        raise NoticeError(f'could not download {url}: {error}') from error


def refresh_cronet(fetch=download, cache=GRADLE_FILES, directory=CRONET):
    embedded = [(group, name, version) for group, name, version in released_libraries()
                if (group, name) == (CRONET_GROUP, CRONET_LIBRARY)]
    if len(embedded) != 1:
        raise NoticeError(f'expected one locked {CRONET_GROUP}:{CRONET_LIBRARY}, found {len(embedded)}')
    group, name, version = embedded[0]
    with zipfile.ZipFile(find_aar(group, name, version, cache)) as archive:
        classes = archive.read('classes.jar')
        build = chromium_build_of(archive.namelist())
    folder = CRONET_BUILDS.format(build=build)
    published = fetch(folder + CRONET_CLASSES)
    if published != classes:
        raise NoticeError(f'{folder}{CRONET_CLASSES} is not the classes of {group}:{name}:{version}; '
                          'its LICENSE may belong to another build')
    licence = fetch(folder + 'LICENSE').decode('utf-8').replace('\r\n', '\n')
    cronet_components(licence)
    source = {
        'library': f'{group}:{name}:{version}',
        'build': build,
        'licence': folder + 'LICENSE',
        'licence_sha256': hashlib.sha256(licence.encode('utf-8')).hexdigest(),
        'classes': folder + CRONET_CLASSES,
        'classes_sha256': hashlib.sha256(classes).hexdigest(),
    }
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, 'LICENSE'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(licence)
    with open(os.path.join(directory, 'source.json'), 'w', encoding='utf-8') as f:
        f.write(json.dumps(source, indent=2, sort_keys=True) + '\n')


def read_cronet(directory=CRONET):
    source = os.path.join(directory, 'source.json')
    if not os.path.exists(source):
        return None
    return json.loads(read(source)), read(os.path.join(directory, 'LICENSE'))


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def released_libraries():
    libraries = locked_libraries(read(LOCKFILE)) + desugaring_libraries(read(BUILD_GRADLE))
    if not libraries:
        raise NoticeError(f'no {CONFIGURATION} entries in {LOCKFILE}')
    return libraries


def build():
    texts = {key: read(os.path.join(TEXTS, file)) for key, (_, file) in LICENCES.items()}
    supplement = {component: read(os.path.join(TEXTS, file)) for component, file in CRONET_SUPPLEMENT.items()}
    return render(released_libraries(), texts, read_cronet(), supplement)


def fake_aar(entries):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w') as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    return buffer.getvalue()


def refused(action, description):
    try:
        action()
    except NoticeError:
        return
    raise AssertionError(f'{description} was not refused')


def self_test():
    global LOCKFILE, BUILD_GRADLE
    lockfile = '\n'.join([
        '# This is a Gradle generated file for dependency locking.',
        'androidx.core:core:1.18.0=debugRuntimeClasspath,releaseRuntimeClasspath',
        'androidx.glance:glance-appwidget-external-protobuf:1.2.0=releaseRuntimeClasspath',
        'org.chromium.net:cronet-api:143.7445.0=releaseRuntimeClasspath',
        'org.chromium.net:cronet-embedded:143.7445.0=releaseRuntimeClasspath',
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

    licence = ('// Copyright 2015 The Chromium Authors\n//\n//   Redistribution © allowed.\n'
               + section('CityHash', f'// {mit}') + section('CityHash', f'// {mit}')
               + section('Abseil', '  apache\n   text  ') + section('Protocol Buffers', 'protobuf text')
               + section('zlib', 'zlib text — 1995') + section('zlib', 'another zlib text')
               + section('memchr', mit) + section('termcolor', mit)
               + section('Metrics Protos', '// Copyright 2015 The Chromium Authors\n//\n// Redistribution \u00a9 allowed.'))
    head, components = cronet_components(licence)
    assert head.startswith('// Copyright 2015'), head
    assert sorted(components) == ['Abseil', 'CityHash', 'Metrics Protos', 'Protocol Buffers', 'memchr', 'termcolor',
                                  'zlib', 'zlib (2)'], components
    assert components['CityHash'] == f'// {mit}' and components['zlib (2)'] == 'another zlib text', components
    assert cronet_components(licence.replace('\n', '\r\n')) == (head, components)

    def stored(text, library='org.chromium.net:cronet-embedded:143.7445.0'):
        return {'library': library, 'licence_sha256': hashlib.sha256(text.encode('utf-8')).hexdigest()}, text

    cronet = stored(licence)
    output = render(libraries + desugaring, texts, cronet)
    assert '- androidx.core:core 1.18.0 (Apache-2.0)\n' \
           '- org.jetbrains.kotlin:kotlin-stdlib 2.4.0 (Apache-2.0)\n' \
           '- `Abseil` (Apache-2.0) in cronet-embedded 143.7445.0\n\n```text\napache text\n```' in output, output
    assert '- androidx.glance:glance-appwidget-external-protobuf 1.2.0 (BSD-3-Clause)\n' \
           '- `Protocol Buffers` (BSD-3-Clause) in cronet-embedded 143.7445.0\n\n```text\nprotobuf text\n```' \
           in output, output
    assert '- org.chromium.net:cronet-api 143.7445.0 (BSD-3-Clause)\n' \
           '- org.chromium.net:cronet-embedded 143.7445.0 (BSD-3-Clause)\n' \
           '- `Metrics Protos` (BSD-3-Clause) in cronet-embedded 143.7445.0\n\n```text\n' \
           'Copyright 2015 The Chromium Authors' in output, output
    assert '- com.android.tools:desugar_jdk_libs 2.1.4 ' \
           '(GPL-2.0-only WITH Classpath-exception-2.0)' in output, output
    assert f'- `CityHash` in cronet-embedded 143.7445.0\n\n```text\n// {mit}\n```' in output, output
    assert f'- `memchr` in cronet-embedded 143.7445.0\n- `termcolor` in cronet-embedded 143.7445.0\n\n' \
           f'```text\n{mit}\n```' in output, output
    assert output.count(mit) == 2, output
    assert '- `zlib` in cronet-embedded 143.7445.0\n\n```text\nzlib text — 1995\n```' in output, output
    assert '- `zlib (2)` in cronet-embedded 143.7445.0\n\n```text\nanother zlib text\n```' in output, output
    assert 'Chromium Authors\n//' not in output, output
    order = [output.index(f'{key} text') for key in ('apache', 'protobuf', 'gpl-classpath')]
    assert order == sorted(order) and output.index('Redistribution') < order[2], order
    assert output.index('```text\ngpl-classpath') < output.index('The other projects in cronet-embedded 143.7445.0 '
                                                                   'whose licences') < output.index('CityHash`')
    assert render(list(reversed(libraries)) + libraries, texts, cronet) == render(libraries, texts, cronet)

    # What the native library links but its LICENSE does not name.
    supplement = {'libc++': 'llvm text', 'libc++abi': 'llvm text', 'Rust standard library': texts['apache'],
                  'zlib': 'zlib text of the supplement'}
    supplemented = render(libraries + desugaring, texts, cronet, supplement)
    assert '- `libc++` in cronet-embedded 143.7445.0\n- `libc++abi` in cronet-embedded 143.7445.0\n\n' \
           '```text\nllvm text\n```' in supplemented, supplemented
    assert '- `Abseil` (Apache-2.0) in cronet-embedded 143.7445.0\n' \
           '- `Rust standard library` (Apache-2.0) in cronet-embedded 143.7445.0\n\n```text\napache text\n```' \
           in supplemented, supplemented
    assert 'zlib text of the supplement' not in supplemented and 'zlib text — 1995' in supplemented, supplemented
    assert supplemented.replace('- `Rust standard library` (Apache-2.0) in cronet-embedded 143.7445.0\n', '') \
        .replace('- `libc++` in cronet-embedded 143.7445.0\n- `libc++abi` in cronet-embedded 143.7445.0\n\n'
                 '```text\nllvm text\n```\n\n', '') == output, supplemented

    # The source offer follows the GPL licence.
    gpl = output.index('gpl-classpath text')
    offer = output.index('- com.android.tools:desugar_jdk_libs 2.1.4 (source code offer)\n\n```text\n'
                         'desugar_jdk_libs 2.1.4 is code from OpenJDK')
    assert gpl < offer < output.index('The other projects'), output
    assert 'https://github.com/google/desugar_jdk_libs\n(release 2.1.4)' in output, output
    assert 'Written offer: for at least three years' in output, output

    without_cronet = [library for library in libraries if library[0] != CRONET_GROUP]
    plain = render(without_cronet, texts, None, supplement)
    assert 'org.chromium.net' not in plain and ' in cronet-embedded' not in plain, plain
    for group, name in [('com.example', 'library'), ('androidx.work', 'work-external-gson'),
                        ('com.android.tools', 'r8'), ('com.google.android.gms', 'play-services-cronet'),
                        ('com.google.android.gms', 'play-services-base')]:
        refused(lambda: licence_of(group, name), f'{group}:{name}')
    refused(lambda: render(libraries, dict(texts, apache='```\n'), cronet), 'a fence inside a text')
    refused(lambda: render(libraries, texts, None), 'a locked Cronet without a stored LICENSE')
    refused(lambda: render(without_cronet, texts, cronet), 'a stored LICENSE without a locked Cronet')
    refused(lambda: render(libraries, texts, stored(licence, 'org.chromium.net:cronet-embedded:141.7340.3')),
            'a LICENSE stored for another version')
    refused(lambda: render(libraries, texts, (cronet[0], licence + 'edited')), 'a LICENSE edited after download')
    api_only = [library for library in libraries if library[1] != CRONET_LIBRARY]
    refused(lambda: render(api_only, texts, cronet), 'Cronet libraries without cronet-embedded')
    mixed = libraries + [('org.chromium.net', 'cronet-shared', '141.7340.3')]
    refused(lambda: render(mixed, texts, cronet), 'Cronet libraries of two builds')
    other_head = licence.replace('Redistribution', 'Distribution')
    refused(lambda: render(libraries, texts, stored(other_head)), 'another Chromium licence in the LICENSE')
    fence = licence + section('fenced', '```\ntext')
    refused(lambda: render(libraries, texts, stored(fence)), "a fence inside a component's text")
    refused(lambda: cronet_components(licence + section('a `name`', 'text')), 'a backtick in a component name')
    refused(lambda: cronet_components('// only the Chromium licence\n'), 'a LICENSE without components')

    # --refresh-cronet against a Gradle cache and a build folder made here.
    classes = b'classes of cronet-embedded'
    aar = fake_aar({'classes.jar': classes, 'jni/arm64-v8a/libcronet.143.0.7445.0.so': b'',
                    'jni/x86_64/libcronet.143.0.7445.0.so': b''})
    assert chromium_build_of(['jni/x86/libcronet.143.0.7445.0.so', 'classes.jar']) == '143.0.7445.0'
    refused(lambda: chromium_build_of(['jni/x86/libcronet.143.0.7445.0.so', 'jni/x86_64/libcronet.143.0.7446.0.so']),
            'native libraries of two builds')
    folder = CRONET_BUILDS.format(build='143.0.7445.0')
    with tempfile.TemporaryDirectory() as temporary:
        cache = os.path.join(temporary, 'cache')
        library = os.path.join(cache, 'org.chromium.net', 'cronet-embedded', '143.7445.0', 'abc')
        os.makedirs(library)
        with open(os.path.join(library, 'cronet-embedded-143.7445.0.aar'), 'wb') as f:
            f.write(aar)
        with open(os.path.join(temporary, 'gradle.lockfile'), 'w', encoding='utf-8') as f:
            f.write(lockfile)
        with open(os.path.join(temporary, 'build.gradle.kts'), 'w', encoding='utf-8') as f:
            f.write('')
        saved = LOCKFILE, BUILD_GRADLE
        LOCKFILE, BUILD_GRADLE = os.path.join(temporary, 'gradle.lockfile'), os.path.join(temporary, 'build.gradle.kts')
        try:
            published = {folder + CRONET_CLASSES: classes, folder + 'LICENSE': licence.replace('\n', '\r\n').encode()}
            directory = os.path.join(temporary, 'cronet')
            refresh_cronet(fetch=published.__getitem__, cache=cache, directory=directory)
            source, stored_licence = read_cronet(directory)
            assert stored_licence == licence, stored_licence
            assert source['library'] == 'org.chromium.net:cronet-embedded:143.7445.0', source
            assert source['licence'] == folder + 'LICENSE' and source['build'] == '143.0.7445.0', source
            assert render(libraries + desugaring, texts, (source, stored_licence)) == output
            other = dict(published, **{folder + CRONET_CLASSES: b'classes of another build'})
            refused(lambda: refresh_cronet(fetch=other.__getitem__, cache=cache, directory=directory),
                    'a build folder whose classes differ from the AAR')
            refused(lambda: refresh_cronet(fetch=published.__getitem__, cache=os.devnull, directory=directory),
                    'an AAR missing from the cache')
        finally:
            LOCKFILE, BUILD_GRADLE = saved
    print('Self-test passed.')


def main():
    args = sys.argv[1:]
    if args == ['--self-test']:
        self_test()
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
