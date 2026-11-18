"""Runs tool/ci/release_sign.sh on its real-key path, which otherwise runs
only at go-vikunja/app's first real tag: keytool makes the keys, aapt2 the
APKs, and the committed certificates come from a copy of tool/ci/ beside a
pubspec of the tag's version. Needs a JDK and the Android SDK's build-tools
and a platform's android.jar; CI's checks job has both."""
import base64
import glob
import hashlib
import os
import re
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COPIED = ('release_sign.sh', 'lib.sh', 'pins.sh', 'release_lib.sh', 'release_version.py', 'key_properties.py')
ABIS = ('arm64-v8a', 'armeabi-v7a', 'x86_64')
TAG = 'v1.0.1'
NAME = TAG[1:]
NUMBER = '1000199'
DESUGAR = 'desugar_jdk_libs-2.1.4-src.tar.gz'
MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="io.vikunja.app">
  <application android:label="test" android:hasCode="false"/>
</manifest>
'''


def android_sdk():
    for name in ('ANDROID_HOME', 'ANDROID_SDK_ROOT'):
        if os.environ.get(name):
            return os.environ[name]
    try:
        with open(os.path.join(ROOT, 'app/android/local.properties'), encoding='utf-8') as f:
            for line in f:
                if line.startswith('sdk.dir='):
                    return line.strip().split('=', 1)[1]
    except OSError:
        pass
    return None


def version_key(path):
    return [int(part) for part in re.findall(r'\d+', os.path.basename(os.path.dirname(path)))]


def requirements():
    sdk = android_sdk()
    found = {
        'keytool': shutil.which('keytool'),
        'jarsigner': shutil.which('jarsigner'),
        'aapt2': max(glob.glob(os.path.join(sdk, 'build-tools/*/aapt2')), key=version_key, default=None)
        if sdk else None,
        'android.jar': max(glob.glob(os.path.join(sdk, 'platforms/android-*/android.jar')), key=version_key,
                           default=None) if sdk else None,
    }
    missing = [name for name, path in found.items() if not path]
    if missing:
        if os.environ.get('CI') == 'true':
            raise AssertionError(f'{", ".join(missing)} needed to test release_sign.sh')
        raise unittest.SkipTest(f'{", ".join(missing)} not found')
    return sdk, found


def sha256(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


class ReleaseSignTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sdk, cls.tools = requirements()

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.repo = os.path.join(self.tmp, 'repo')
        self.temp = os.path.join(self.tmp, 'temp')
        os.makedirs(os.path.join(self.repo, 'tool/ci'))
        os.makedirs(os.path.join(self.repo, 'app'))
        os.mkdir(self.temp)
        for name in COPIED:
            shutil.copy2(os.path.join(ROOT, 'tool/ci', name), os.path.join(self.repo, 'tool/ci', name))
        with open(os.path.join(self.repo, 'app/pubspec.yaml'), 'w', encoding='utf-8') as f:
            f.write(f'name: vikunja_app\nversion: {NAME}+1\n')
        self.unsigned = os.path.join(self.repo, 'build/release/unsigned')
        self.signed = os.path.join(self.repo, 'build/release/signed')
        os.makedirs(self.unsigned)
        self.make_unsigned()

    def apk(self, path, abis):
        work = tempfile.mkdtemp(dir=self.tmp)
        manifest = os.path.join(work, 'AndroidManifest.xml')
        with open(manifest, 'w', encoding='utf-8') as f:
            f.write(MANIFEST)
        subprocess.run([self.tools['aapt2'], 'link', '-o', path, '-I', self.tools['android.jar'], '--manifest',
                        manifest, '--version-code', NUMBER, '--version-name', NAME, '--min-sdk-version', '24'],
                       check=True, capture_output=True)
        with zipfile.ZipFile(path, 'a', compression=zipfile.ZIP_STORED) as apk:
            for abi in abis:
                apk.writestr(f'lib/{abi}/libapp.so', b'\x7fELF' + abi.encode() * 64)

    def make_unsigned(self):
        self.apk(os.path.join(self.unsigned, 'app-release.apk'), ABIS)
        for abi in ABIS:
            self.apk(os.path.join(self.unsigned, f'app-{abi}-release.apk'), (abi,))
        with zipfile.ZipFile(os.path.join(self.unsigned, 'app-release.aab'), 'w') as bundle:
            bundle.writestr('base/manifest/AndroidManifest.xml', b'bundle')
        with open(os.path.join(self.unsigned, DESUGAR), 'wb') as f:
            f.write(b'desugar_jdk_libs source')
        values = {
            'TAG': TAG, 'BUILD_NAME': NAME, 'BUILD_NUMBER': NUMBER, 'CHANNEL': 'final',
            'SOURCE_URL': f'https://github.com/go-vikunja/app/tree/{TAG}', 'DESUGAR_ARCHIVE': DESUGAR,
            'DESUGAR_COMMIT': '50d9c1fb3e85fa4c00161525a45484f712c1f003',
            'UNSIGNED_AAB_SHA256': sha256(os.path.join(self.unsigned, 'app-release.aab')),
            'UNSIGNED_APK_SHA256': sha256(os.path.join(self.unsigned, 'app-release.apk')),
            **{f'UNSIGNED_APK_{abi.upper().replace("-", "_")}_SHA256':
               sha256(os.path.join(self.unsigned, f'app-{abi}-release.apk')) for abi in ABIS},
            'DESUGAR_ARCHIVE_SHA256': sha256(os.path.join(self.unsigned, DESUGAR)),
            'DRY_RUN': '0', 'NOT_RELEASABLE': '',
        }
        with open(os.path.join(self.unsigned, 'release.env'), 'w', encoding='utf-8') as f:
            f.writelines(f'{key}={value}\n' for key, value in values.items())

    def keystore(self, name, store_type, alias, store_password, key_password, algorithm='RSA'):
        path = os.path.join(self.tmp, name)
        size = ['-keysize', '2048'] if algorithm == 'RSA' else ['-groupname', 'secp256r1']
        subprocess.run([self.tools['keytool'], '-genkeypair', '-noprompt', '-storetype', store_type, '-keystore', path,
                        '-alias', alias, '-keyalg', algorithm, *size, '-validity', '2', '-dname',
                        f'CN=Vikunja app test {name}', '-storepass:env', 'STORE', '-keypass:env', 'KEY'],
                       check=True, capture_output=True, env={**os.environ, 'STORE': store_password,
                                                             'KEY': key_password})
        listing = subprocess.run([self.tools['keytool'], '-list', '-v', '-keystore', path, '-storetype', store_type,
                                  '-alias', alias, '-storepass:env', 'STORE'],
                                 check=True, capture_output=True, text=True,
                                 env={**os.environ, 'STORE': store_password}).stdout
        fingerprint = re.search(r'SHA256:\s*([0-9A-F:]+)', listing).group(1).replace(':', '').lower()
        with open(path, 'rb') as f:
            encoded = base64.b64encode(f.read()).decode()
        properties = f'storeFile=ignored.jks\nstorePassword={store_password}\nkeyAlias={alias}\nkeyPassword={key_password}\n'
        return encoded, properties, fingerprint

    def commit_certificates(self, upload='', apk=''):
        with open(os.path.join(self.repo, 'tool/ci/release_certificates.txt'), 'w', encoding='utf-8') as f:
            f.write(f'# test\nupload={upload}\napk={apk}\n')

    def sign(self, **secrets):
        env = {name: value for name, value in os.environ.items()
               if name not in ('KEYSTORE_BASE64', 'KEY_PROPERTIES', 'APK_KEYSTORE_BASE64', 'APK_KEY_PROPERTIES',
                               'GITHUB_ACTIONS', 'RUNNER_TEMP', 'VIKUNJA_APP_RELEASE_DIR')}
        env.update({'TMPDIR': self.temp, 'ANDROID_HOME': self.sdk, **secrets})
        result = subprocess.run(['bash', os.path.join(self.repo, 'tool/ci/release_sign.sh')], env=env,
                                capture_output=True, text=True, timeout=300)
        self.assertEqual(os.listdir(self.temp), [], 'the work directory is left behind')
        output = result.stdout + result.stderr
        for value in secrets.values():
            for line in value.splitlines():
                if 'Password=' in line:
                    self.assertNotIn(line.split('=', 1)[1], output)
        return result

    def signed_env(self):
        with open(os.path.join(self.signed, 'release.env'), encoding='utf-8') as f:
            return dict(line.rstrip('\n').split('=', 1) for line in f)

    def signer(self, apk):
        apksigner = os.path.join(os.path.dirname(self.tools['aapt2']), 'apksigner')
        report = subprocess.run([apksigner, 'verify', '--print-certs', apk], check=True, capture_output=True,
                                text=True).stdout
        return set(re.findall(r'certificate SHA-256 digest: ([0-9a-f]{64})', report))

    def test_the_upload_key_signs_everything(self):
        keystore, properties, fingerprint = self.keystore('upload.jks', 'JKS', 'upload', 'store-secret-4f1a',
                                                          'key-secret-9c2e')
        self.commit_certificates(upload=fingerprint)
        result = self.sign(KEYSTORE_BASE64=keystore, KEY_PROPERTIES=properties)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Verified: the universal and the 3 per-ABI APKs', result.stdout)
        env = self.signed_env()
        self.assertEqual((env['SIGNING'], env['APK_SET'], env['NOT_RELEASABLE'], env['DRY_RUN']),
                         ('release', 'upload', '', '0'))
        self.assertEqual(env['UPLOAD_CERT_SHA256'], fingerprint)
        self.assertEqual(env['APK_CERT_SHA256'], fingerprint)
        files = [f'vikunja-app-{NAME}.apk'] + [f'vikunja-app-{NAME}-{abi}.apk' for abi in ABIS]
        for name in files:
            with self.subTest(name):
                self.assertEqual(self.signer(os.path.join(self.signed, name)), {fingerprint})
        for abi in ABIS:
            self.assertEqual(env[f'APK_{abi.upper().replace("-", "_")}_SHA256'],
                             sha256(os.path.join(self.signed, f'vikunja-app-{NAME}-{abi}.apk')))
        with open(os.path.join(self.signed, 'SHA256SUMS'), encoding='utf-8') as f:
            sums = dict(reversed(line.split()) for line in f)
        self.assertEqual(sorted(sums), sorted(files + [DESUGAR]))
        for name, value in sums.items():
            self.assertEqual(sha256(os.path.join(self.signed, name)), value)

    def test_a_separate_apk_key(self):
        upload, upload_properties, upload_fingerprint = self.keystore('upload.p12', 'PKCS12', 'upload', 'p12-a8d3',
                                                                      'p12-a8d3')
        apk, apk_properties, apk_fingerprint = self.keystore('apk.p12', 'PKCS12', 'apk', 'p12-77b0', 'p12-77b0')
        self.commit_certificates(upload=upload_fingerprint, apk=apk_fingerprint)
        result = self.sign(KEYSTORE_BASE64=upload, KEY_PROPERTIES=upload_properties, APK_KEYSTORE_BASE64=apk,
                           APK_KEY_PROPERTIES=apk_properties)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        env = self.signed_env()
        self.assertEqual((env['APK_SET'], env['UPLOAD_CERT_SHA256'], env['APK_CERT_SHA256']),
                         ('apk', upload_fingerprint, apk_fingerprint))
        for abi in ABIS:
            self.assertEqual(self.signer(os.path.join(self.signed, f'vikunja-app-{NAME}-{abi}.apk')), {apk_fingerprint})

    def test_another_certificate_is_refused(self):
        keystore, properties, fingerprint = self.keystore('upload.jks', 'JKS', 'upload', 'store-6e0b', 'key-2d4f')
        for committed, message in (('', 'commit the upload certificate'),
                                   ('0' * 64, f"KEYSTORE_BASE64's certificate is {fingerprint}, ")):
            with self.subTest(committed=committed):
                self.commit_certificates(upload=committed)
                result = self.sign(KEYSTORE_BASE64=keystore, KEY_PROPERTIES=properties)
                self.assertEqual(result.returncode, 1)
                self.assertIn(message, result.stderr)
                self.assertFalse(os.path.exists(self.signed))

    def test_an_ec_apk_key_is_refused(self):
        upload, upload_properties, upload_fingerprint = self.keystore('upload.p12', 'PKCS12', 'upload', 'p12-1c9e',
                                                                      'p12-1c9e')
        apk, apk_properties, apk_fingerprint = self.keystore('apk.p12', 'PKCS12', 'apk', 'p12-5f3a', 'p12-5f3a',
                                                             algorithm='EC')
        self.commit_certificates(upload=upload_fingerprint, apk=apk_fingerprint)
        result = self.sign(KEYSTORE_BASE64=upload, KEY_PROPERTIES=upload_properties, APK_KEYSTORE_BASE64=apk,
                           APK_KEY_PROPERTIES=apk_properties)
        self.assertEqual(result.returncode, 1)
        self.assertIn('gave two different files', result.stderr)


if __name__ == '__main__':
    unittest.main()
