"""Checks app/android/gradle/verification-metadata.xml, Gradle's dependency
verification of the Android build: SHA-256 for every entry, an entry for every
locked library, and no trust beyond the three that docs/releasing.md names."""
import os
import re
import unittest
import xml.etree.ElementTree as ElementTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
METADATA = os.path.join(ROOT, 'app/android/gradle/verification-metadata.xml')
LOCKFILE = os.path.join(ROOT, 'app/android/app/gradle.lockfile')
NS = {'v': 'https://schema.gradle.org/dependency-verification'}
TRUSTED = {
    ('com.android.tools.build', 'aapt2', 'aapt2-.*-(linux|windows)[.]jar', 'true'),
    (None, None, '.*-javadoc[.]jar', 'true'),
    (None, None, '.*-sources[.]jar', 'true'),
}


class GradleVerificationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = ElementTree.parse(METADATA).getroot()

    def test_checksums_and_metadata_are_verified(self):
        configuration = self.root.find('v:configuration', NS)
        self.assertEqual(configuration.findtext('v:verify-metadata', namespaces=NS), 'true')
        artifacts = self.root.findall('v:components/v:component/v:artifact', NS)
        self.assertGreater(len(artifacts), 100)
        for artifact in artifacts:
            with self.subTest(artifact.get('name')):
                checks = [child.tag.split('}')[1] for child in artifact]
                self.assertEqual(checks, ['sha256'])
                self.assertRegex(artifact[0].get('value'), r'^[0-9a-f]{64}$')

    def test_every_locked_library_is_listed(self):
        listed = {(component.get('group'), component.get('name'), component.get('version'))
                  for component in self.root.findall('v:components/v:component', NS)}
        with open(LOCKFILE, encoding='utf-8') as f:
            locked = [tuple(line.split('=')[0].split(':')) for line in f
                      if re.match(r'^[^#=\s]+:[^:=\s]+:[^:=\s]+=', line)]
        self.assertGreater(len(locked), 10)
        for library in locked:
            with self.subTest(':'.join(library)):
                self.assertIn(library, listed)

    def test_only_the_documented_trust(self):
        trusted = {(trust.get('group'), trust.get('name'), trust.get('file'), trust.get('regex'))
                   for trust in self.root.findall('v:configuration/v:trusted-artifacts/v:trust', NS)}
        self.assertEqual(trusted, TRUSTED)
        self.assertIsNone(self.root.find('v:configuration/v:trusted-keys', NS))


if __name__ == '__main__':
    unittest.main()
