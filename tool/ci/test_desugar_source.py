import os
import subprocess
import tarfile
import tempfile
import unittest

from desugar_source import (BUILD_GRADLE, MANIFEST, SourceError, archive_name, check_manifest, fetch,
                            parse_manifest, read)

GRADLE = 'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'


def manifest_text(**overrides):
    values = dict(version='2.1.4', repository='https://github.com/google/desugar_jdk_libs',
                  commit='5' * 40, tree='e' * 40, note='a note')
    values.update(overrides)
    return ''.join(f'{key}={value}\n' for key, value in values.items() if value is not None)


class ManifestTest(unittest.TestCase):
    def test_the_committed_manifest_matches_the_build(self):
        manifest = parse_manifest(read(MANIFEST))
        self.assertEqual(check_manifest(manifest, read(BUILD_GRADLE)), manifest['version'])

    def test_parse(self):
        manifest = parse_manifest(manifest_text())
        self.assertEqual(manifest['version'], '2.1.4')
        self.assertEqual(manifest['note'], 'a note')
        self.assertEqual(archive_name(manifest), 'desugar_jdk_libs-2.1.4-src.tar.gz')

    def test_a_mismatched_version_fails(self):
        with self.assertRaises(SourceError):
            check_manifest(parse_manifest(manifest_text(version='2.1.3')), GRADLE)
        with self.assertRaises(SourceError):
            check_manifest(parse_manifest(manifest_text()), GRADLE.replace('2.1.4', '2.1.5'))
        with self.assertRaises(SourceError):
            check_manifest(parse_manifest(manifest_text()), 'dependencies {}\n')

    def test_bad_manifests(self):
        for text in [manifest_text(commit=None), manifest_text(tree='e' * 39), manifest_text(commit='5' * 40 + 'x'),
                     manifest_text(repository='http://example.org/x'), manifest_text() + 'version=2.1.5\n',
                     manifest_text() + 'no separator\n']:
            with self.subTest(text=text), self.assertRaises(SourceError):
                parse_manifest(text)


class FetchTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = temporary.name
        self.upstream = os.path.join(self.directory, 'upstream')
        os.makedirs(self.upstream)
        self.git('init', '-q')
        self.git('config', 'uploadpack.allowAnySHA1InWant', 'true')
        with open(os.path.join(self.upstream, 'VERSION_JDK11.txt'), 'w', encoding='utf-8') as f:
            f.write('2.1.4\n')
        with open(os.path.join(self.upstream, 'README'), 'w', encoding='utf-8') as f:
            f.write('desugar\n')
        self.git('add', '.')
        self.git('commit', '-q', '-m', 'Set the version')
        self.commit = self.git('rev-parse', 'HEAD')
        self.tree = self.git('rev-parse', 'HEAD^{tree}')
        self.git('commit', '-q', '--allow-empty', '-m', 'Later')
        self.url = 'file://' + self.upstream

    def git(self, *arguments):
        environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', GIT_AUTHOR_NAME='A',
                           GIT_AUTHOR_EMAIL='a@example.org', GIT_COMMITTER_NAME='A', GIT_COMMITTER_EMAIL='a@example.org')
        return subprocess.run(['git', *arguments], cwd=self.upstream, env=environment, check=True,
                              capture_output=True, text=True).stdout.strip()

    def manifest(self, **overrides):
        return parse_manifest(manifest_text(**dict(dict(commit=self.commit, tree=self.tree), **overrides)))

    def test_fetches_the_commit_into_an_archive(self):
        out = os.path.join(self.directory, 'out')
        path = fetch(self.manifest(), out, repository=self.url)
        self.assertEqual(path, os.path.join(out, 'desugar_jdk_libs-2.1.4-src.tar.gz'))
        with tarfile.open(path) as archive:
            names = archive.getnames()
        self.assertIn('desugar_jdk_libs-2.1.4/VERSION_JDK11.txt', names)
        self.assertIn('desugar_jdk_libs-2.1.4/README', names)

    def test_refuses_another_tree_or_version(self):
        out = os.path.join(self.directory, 'out')
        with self.assertRaisesRegex(SourceError, 'has tree'):
            fetch(self.manifest(tree='0' * 40), out, repository=self.url)
        with self.assertRaisesRegex(SourceError, 'does not end in 2.1.5'):
            fetch(self.manifest(version='2.1.5'), out, repository=self.url)
        with self.assertRaises(SourceError):
            fetch(self.manifest(commit='0' * 40), out, repository=self.url)
        self.assertFalse(os.path.exists(os.path.join(out, 'desugar_jdk_libs-2.1.5-src.tar.gz')))


if __name__ == '__main__':
    unittest.main()
