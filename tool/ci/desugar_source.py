#!/usr/bin/env python3
"""The source code of the desugar_jdk_libs build in the app (GPL-2.0 with the
Classpath exception), which every release carries beside the APK (D73).

  python3 -I tool/ci/desugar_source.py --check-manifest
  python3 -I tool/ci/desugar_source.py --fetch OUT_DIR

The manifest tool/android_notices/desugar_jdk_libs.source names the upstream
repository, commit and tree of the version that build.gradle.kts desugars
with; --check-manifest fails when that version differs. --fetch fetches the
commit alone, checks its tree and its VERSION_JDK11.txt, and writes
OUT_DIR/desugar_jdk_libs-VERSION-src.tar.gz, whose path it prints. The
archive's checksum can change with the git version, so the commit and tree
are what is checked, not the archive.
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, 'tool/android_notices/desugar_jdk_libs.source')
BUILD_GRADLE = os.path.join(ROOT, 'app/android/app/build.gradle.kts')
DESUGARING = re.compile(r'^\s*coreLibraryDesugaring\("com\.android\.tools:desugar_jdk_libs:([^"]+)"\)', re.MULTILINE)
OBJECT_ID = re.compile(r'[0-9a-f]{40}')
KEYS = ('version', 'repository', 'commit', 'tree')


class SourceError(Exception):
    pass


def parse_manifest(text):
    manifest = {}
    for number, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.startswith('#'):
            continue
        key, separator, value = line.partition('=')
        if not separator or key in manifest:
            raise SourceError(f'manifest line {number} is not a new key=value: {line!r}')
        manifest[key] = value
    missing = [key for key in KEYS if not manifest.get(key)]
    if missing:
        raise SourceError(f'the manifest lacks {", ".join(missing)}')
    for key in ('commit', 'tree'):
        if not OBJECT_ID.fullmatch(manifest[key]):
            raise SourceError(f'the manifest\'s {key} is not a full object id: {manifest[key]!r}')
    if not manifest['repository'].startswith('https://'):
        raise SourceError(f'the manifest\'s repository is not an https URL: {manifest["repository"]!r}')
    return manifest


def desugaring_version(build_gradle):
    versions = DESUGARING.findall(build_gradle)
    if len(versions) != 1:
        raise SourceError(f'expected one coreLibraryDesugaring of desugar_jdk_libs in build.gradle.kts, '
                          f'found {len(versions)}')
    return versions[0]


def check_manifest(manifest, build_gradle):
    version = desugaring_version(build_gradle)
    if manifest['version'] != version:
        raise SourceError(f'the manifest is for desugar_jdk_libs {manifest["version"]}, build.gradle.kts '
                          f'desugars with {version}: record the upstream commit of {version} in '
                          f'{os.path.relpath(MANIFEST, ROOT)}')
    return version


def archive_name(manifest):
    return f'desugar_jdk_libs-{manifest["version"]}-src.tar.gz'


def fetch(manifest, out_dir, repository=None):
    """Writes the archive of the manifest's commit into out_dir; returns its path."""
    def git(*arguments, cwd):
        result = subprocess.run(['git', *arguments], cwd=cwd, capture_output=True, text=True,
                                env=dict(os.environ, GIT_TERMINAL_PROMPT='0'))
        if result.returncode != 0:
            raise SourceError(f'git {" ".join(arguments)} failed: {result.stderr.strip()}')
        return result.stdout

    version, commit, tree = manifest['version'], manifest['commit'], manifest['tree']
    with tempfile.TemporaryDirectory() as clone:
        git('init', '-q', cwd=clone)
        git('fetch', '-q', '--depth', '1', '--no-tags', repository or manifest['repository'], commit, cwd=clone)
        fetched = git('rev-parse', 'FETCH_HEAD^{commit}', cwd=clone).strip()
        if fetched != commit:
            raise SourceError(f'fetched commit {fetched}, the manifest names {commit}')
        fetched_tree = git('rev-parse', 'FETCH_HEAD^{tree}', cwd=clone).strip()
        if fetched_tree != tree:
            raise SourceError(f'commit {commit} has tree {fetched_tree}, the manifest names {tree}')
        lines = [line.strip() for line in git('show', 'FETCH_HEAD:VERSION_JDK11.txt', cwd=clone).splitlines()]
        lines = [line for line in lines if line]
        if not lines or lines[-1] != version:
            raise SourceError(f'VERSION_JDK11.txt at {commit} does not end in {version}: {lines[-1:]}')
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(os.path.abspath(out_dir), archive_name(manifest))
        git('archive', '--format=tar.gz', f'--prefix=desugar_jdk_libs-{version}/', '-o', path, 'FETCH_HEAD',
            cwd=clone)
    return path


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def main(arguments):
    try:
        manifest = parse_manifest(read(MANIFEST))
        if arguments == ['--check-manifest']:
            version = check_manifest(manifest, read(BUILD_GRADLE))
            print(f'OK: {os.path.relpath(MANIFEST, ROOT)} names the source of desugar_jdk_libs {version}.')
            return 0
        if len(arguments) == 2 and arguments[0] == '--fetch':
            check_manifest(manifest, read(BUILD_GRADLE))
            print(fetch(manifest, arguments[1]))
            return 0
    except (SourceError, OSError) as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
